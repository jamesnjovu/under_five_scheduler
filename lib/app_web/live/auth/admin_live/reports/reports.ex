defmodule AppWeb.AdminLive.Reports do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      # Get date range for report
      today = Date.utc_today()
      one_month_ago = Date.add(today, -30)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "Admin Reports")
        |> assign(:date_range, %{start_date: one_month_ago, end_date: today})
        # Default report
        |> assign(:report_type, "appointment_summary")
        |> assign(:reports, generate_reports(one_month_ago, today))
        |> assign(:providers, Scheduling.list_providers())
        # For responsive sidebar toggle
        |> assign(:show_sidebar, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event(
        "update_date_range",
        %{"start_date" => start_date, "end_date" => end_date},
        socket
      ) do
    with {:ok, start_date} <- Date.from_iso8601(start_date),
         {:ok, end_date} <- Date.from_iso8601(end_date) do
      # Ensure end_date is after or equal to start_date
      {start_date, end_date} =
        if Date.compare(start_date, end_date) == :gt do
          {end_date, start_date}
        else
          {start_date, end_date}
        end

      {:noreply,
       socket
       |> assign(:date_range, %{start_date: start_date, end_date: end_date})
       |> assign(:reports, generate_reports(start_date, end_date))}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_report", %{"report_type" => report_type}, socket) do
    {:noreply, assign(socket, :report_type, report_type)}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp generate_reports(start_date, end_date) do
    # Get all appointments in date range
    appointments =
      Scheduling.list_appointments()
      |> Enum.filter(fn a ->
        Date.compare(a.scheduled_date, start_date) in [:eq, :gt] &&
          Date.compare(a.scheduled_date, end_date) in [:eq, :lt]
      end)

    # Calculate various metrics
    appointment_count = length(appointments)

    # Status breakdown
    status_counts = %{
      scheduled: Enum.count(appointments, &(&1.status == "scheduled")),
      confirmed: Enum.count(appointments, &(&1.status == "confirmed")),
      completed: Enum.count(appointments, &(&1.status == "completed")),
      cancelled: Enum.count(appointments, &(&1.status == "cancelled")),
      no_show: Enum.count(appointments, &(&1.status == "no_show")),
      rescheduled: Enum.count(appointments, &(&1.status == "rescheduled"))
    }

    # Calculate rates
    completion_rate =
      if appointment_count > 0, do: status_counts.completed / appointment_count * 100, else: 0

    cancellation_rate =
      if appointment_count > 0, do: status_counts.cancelled / appointment_count * 100, else: 0

    no_show_rate =
      if appointment_count > 0, do: status_counts.no_show / appointment_count * 100, else: 0

    # Daily distribution
    days_of_week = %{
      1 => "Monday",
      2 => "Tuesday",
      3 => "Wednesday",
      4 => "Thursday",
      5 => "Friday",
      6 => "Saturday",
      7 => "Sunday"
    }

    daily_counts =
      appointments
      |> Enum.group_by(fn a -> Date.day_of_week(a.scheduled_date) end)
      |> Enum.map(fn {day, appointments} ->
        {days_of_week[day], length(appointments)}
      end)
      |> Enum.into(%{})

    # Ensure all days are represented
    daily_counts =
      Enum.reduce(days_of_week, daily_counts, fn {day_num, day_name}, acc ->
        Map.put_new(acc, day_name, 0)
      end)

    # Provider performance
    provider_performance =
      appointments
      |> Enum.group_by(fn a -> a.provider_id end)
      |> Enum.map(fn {provider_id, provider_appointments} ->
        provider = Scheduling.get_provider!(provider_id)
        count = length(provider_appointments)
        completed = Enum.count(provider_appointments, &(&1.status == "completed"))
        no_shows = Enum.count(provider_appointments, &(&1.status == "no_show"))
        completion_rate = if count > 0, do: completed / count * 100, else: 0
        no_show_rate = if count > 0, do: no_shows / count * 100, else: 0

        %{
          provider: provider,
          appointment_count: count,
          completed_count: completed,
          no_show_count: no_shows,
          completion_rate: completion_rate,
          no_show_rate: no_show_rate
        }
      end)
      |> Enum.sort_by(fn p -> p.appointment_count end, :desc)

    # Return all reports in a map
    %{
      date_range: %{
        start_date: start_date,
        end_date: end_date,
        days: Date.diff(end_date, start_date)
      },

      # Appointment summary
      appointment_summary: %{
        total_count: appointment_count,
        status_counts: status_counts,
        completion_rate: completion_rate,
        cancellation_rate: cancellation_rate,
        no_show_rate: no_show_rate,
        daily_average:
          if(Date.diff(end_date, start_date) > 0,
            do: appointment_count / Date.diff(end_date, start_date),
            else: appointment_count
          )
      },

      # Daily distribution
      daily_distribution: daily_counts,

      # Provider performance
      provider_performance: provider_performance
    }
  end

  # Helper functions for displaying data
  defp percentage_format(value) do
    :erlang.float_to_binary(value / 1, decimals: 1) <> "%"
  end

  defp date_format(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end
end
