defmodule AppWeb.ProviderLive.Reports do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    # Ensure the user is a provider
    if Accounts.is_provider?(user) do
      provider = Scheduling.get_provider_by_user_id(user.id)

      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "appointments:updates")
      end

      # Get date range for report - default to current month
      today = Date.utc_today()
      start_date = Date.beginning_of_month(today)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:page_title, "Provider Reports")
        |> assign(:date_range, %{start_date: start_date, end_date: today})
        |> assign(:period, "month")
        |> assign(:report_type, "overview")
        |> assign(:show_sidebar, false)
        |> assign(:report_data, generate_report_data(provider.id, start_date, today))

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

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket)
      when period in ["week", "month", "quarter", "year", "custom"] do
    today = Date.utc_today()
    start_date = get_start_date(today, period)

    {:noreply,
     socket
     |> assign(:period, period)
     |> assign(:date_range, %{start_date: start_date, end_date: today})
     |> assign(:report_data, generate_report_data(socket.assigns.provider.id, start_date, today))}
  end

  @impl true
  def handle_event("change_report_type", %{"report_type" => report_type}, socket) do
    {:noreply, assign(socket, :report_type, report_type)}
  end

  @impl true
  def handle_event(
        "custom_date_range",
        %{"start_date" => start_date, "end_date" => end_date},
        socket
      ) do
    with {:ok, start_date} <- Date.from_iso8601(start_date),
         {:ok, end_date} <- Date.from_iso8601(end_date) do
      # Ensure end_date is not before start_date
      {start_date, end_date} =
        if Date.compare(start_date, end_date) == :gt,
          do: {end_date, start_date},
          else: {start_date, end_date}

      {:noreply,
       socket
       |> assign(:period, "custom")
       |> assign(:date_range, %{start_date: start_date, end_date: end_date})
       |> assign(
         :report_data,
         generate_report_data(socket.assigns.provider.id, start_date, end_date)
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  # Handle real-time updates
  @impl true
  def handle_info({:appointment_updated, _}, socket) do
    # Refresh report data when appointments are updated
    report_data =
      generate_report_data(
        socket.assigns.provider.id,
        socket.assigns.date_range.start_date,
        socket.assigns.date_range.end_date
      )

    {:noreply, assign(socket, :report_data, report_data)}
  end

  @impl true
  def handle_info({:stats_updated}, socket) do
    # Refresh report data when stats are updated elsewhere
    report_data =
      generate_report_data(
        socket.assigns.provider.id,
        socket.assigns.date_range.start_date,
        socket.assigns.date_range.end_date
      )

    {:noreply, assign(socket, :report_data, report_data)}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp get_start_date(today, period) do
    case period do
      "week" -> Date.add(today, -7)
      "month" -> Date.beginning_of_month(today)
      "quarter" -> Date.add(today, -90)
      "year" -> Date.add(today, -365)
      "custom" -> today
      # Default to month
      _ -> Date.beginning_of_month(today)
    end
  end

  defp generate_report_data(provider_id, start_date, end_date) do
    # Get all appointments in date range
    appointments =
      Scheduling.list_appointments(provider_id: provider_id)
      |> Enum.filter(fn a ->
        Date.compare(a.scheduled_date, start_date) in [:eq, :gt] &&
          Date.compare(a.scheduled_date, end_date) in [:eq, :lt]
      end)

    # Calculate total appointments
    total_count = length(appointments)

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
    completion_rate = if total_count > 0, do: status_counts.completed / total_count * 100, else: 0

    cancellation_rate =
      if total_count > 0, do: status_counts.cancelled / total_count * 100, else: 0

    no_show_rate = if total_count > 0, do: status_counts.no_show / total_count * 100, else: 0

    # Daily distribution
    daily_data =
      appointments
      |> Enum.group_by(fn a -> a.scheduled_date end)
      |> Enum.map(fn {date, appts} ->
        %{
          date: date,
          total: length(appts),
          completed: Enum.count(appts, &(&1.status == "completed")),
          no_show: Enum.count(appts, &(&1.status == "no_show")),
          cancelled: Enum.count(appts, &(&1.status == "cancelled"))
        }
      end)
      |> Enum.sort_by(fn %{date: date} -> date end)

    # Weekly distribution
    weekly_data =
      group_by_week(appointments, start_date, end_date)

    # Monthly distribution
    monthly_data =
      group_by_month(appointments, start_date, end_date)

    # Child age distribution
    children_ids = appointments |> Enum.map(& &1.child_id) |> Enum.uniq()

    children = Enum.map(children_ids, fn id -> Accounts.get_child!(id) end)

    age_distribution =
      children
      |> Enum.group_by(fn child -> App.Accounts.Child.age(child) end)
      |> Enum.map(fn {age, children} -> {age, length(children)} end)
      |> Enum.sort()
      |> Enum.into(%{})

    # Time of day distribution
    time_distribution =
      appointments
      |> Enum.group_by(fn a ->
        cond do
          a.scheduled_time.hour < 12 -> :morning
          a.scheduled_time.hour < 17 -> :afternoon
          true -> :evening
        end
      end)
      |> Enum.map(fn {time_of_day, appts} -> {time_of_day, length(appts)} end)
      |> Enum.into(%{})

    # Return all report data
    %{
      total_appointments: total_count,
      status_counts: status_counts,
      rates: %{
        completion_rate: completion_rate/1,
        cancellation_rate: cancellation_rate/1,
        no_show_rate: no_show_rate/1
      },
      daily_data: daily_data,
      weekly_data: weekly_data,
      monthly_data: monthly_data,
      age_distribution: age_distribution,
      time_distribution: time_distribution,
      date_range: %{
        start_date: start_date,
        end_date: end_date,
        days: Date.diff(end_date, start_date)
      },
      children_count: length(children_ids),
      avg_appointments_per_day:
        if(Date.diff(end_date, start_date) > 0,
          do: total_count / Date.diff(end_date, start_date),
          else: total_count
        )
    }
  end

  defp group_by_week(appointments, start_date, end_date) do
    # Get all weeks in the range
    week_range = get_week_range(start_date, end_date)

    week_range
    |> Enum.map(fn {week_start, week_end} ->
      week_appointments =
        Enum.filter(appointments, fn appt ->
          Date.compare(appt.scheduled_date, week_start) in [:eq, :gt] &&
            Date.compare(appt.scheduled_date, week_end) in [:lt, :eq]
        end)

      %{
        week_start: week_start,
        week_end: week_end,
        display: "Week #{iso_week_string(week_start)}",
        total: length(week_appointments),
        completed: Enum.count(week_appointments, &(&1.status == "completed")),
        no_show: Enum.count(week_appointments, &(&1.status == "no_show")),
        cancelled: Enum.count(week_appointments, &(&1.status == "cancelled"))
      }
    end)
  end

  defp get_week_range(start_date, end_date) do
    # Adjust start_date to the beginning of the week (Monday)
    adjusted_start = Date.beginning_of_week(start_date)

    # Get the number of weeks
    days_diff = Date.diff(end_date, adjusted_start)
    weeks = div(days_diff, 7) + 1

    # Generate a list of week start/end dates
    Enum.map(0..(weeks - 1), fn week_offset ->
      week_start = Date.add(adjusted_start, week_offset * 7)
      week_end = Date.add(week_start, 6)
      {week_start, week_end}
    end)
  end

  defp group_by_month(appointments, start_date, end_date) do
    # Get all months in the range
    month_range = get_month_range(start_date, end_date)

    month_range
    |> Enum.map(fn {month_start, month_end} ->
      month_appointments =
        Enum.filter(appointments, fn appt ->
          Date.compare(appt.scheduled_date, month_start) in [:eq, :gt] &&
            Date.compare(appt.scheduled_date, month_end) in [:lt, :eq]
        end)

      %{
        month_start: month_start,
        month_end: month_end,
        display: Calendar.strftime(month_start, "%b %Y"),
        total: length(month_appointments),
        completed: Enum.count(month_appointments, &(&1.status == "completed")),
        no_show: Enum.count(month_appointments, &(&1.status == "no_show")),
        cancelled: Enum.count(month_appointments, &(&1.status == "cancelled"))
      }
    end)
  end

  defp get_month_range(start_date, end_date) do
    # Adjust start_date to the beginning of the month
    adjusted_start = Date.beginning_of_month(start_date)

    # Recursively build a list of month start/end dates
    build_month_range(adjusted_start, end_date, [])
  end

  defp build_month_range(current_date, end_date, acc) do
    if Date.compare(current_date, end_date) == :gt do
      # We've gone past the end date, so return the accumulated months
      Enum.reverse(acc)
    else
      month_start = current_date
      month_end = Date.end_of_month(current_date)

      # Move to the next month
      next_month = Date.add(month_end, 1)

      # Add the current month to our accumulator and continue
      build_month_range(next_month, end_date, [{month_start, month_end} | acc])
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  defp format_percentage(value) do
    :erlang.float_to_binary(value, decimals: 1) <> "%"
  end

  defp get_chart_height(value, max_value) do
    if max_value > 0 do
      "#{value / max_value * 100}%"
    else
      "0%"
    end
  end

  def iso_week_string(%Date{} = date) do
    {year, week} = :calendar.iso_week_number({date.year, date.month, date.day})
    "#{year}-W#{String.pad_leading(Integer.to_string(week), 2, "0")}"
  end
end
