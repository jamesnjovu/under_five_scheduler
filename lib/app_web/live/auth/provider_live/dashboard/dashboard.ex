defmodule AppWeb.ProviderLive.Dashboard do
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

      # Get date range for statistics
      today = Date.utc_today()
      one_month_ago = Date.add(today, -30)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:page_title, "Provider Dashboard")
        |> assign(:statistics, get_statistics(provider.id, one_month_ago, today))
        |> assign(:today_appointments, get_today_appointments(provider.id))
        |> assign(:upcoming_appointments, get_upcoming_appointments(provider.id))
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

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_info({:appointment_updated, _appointment}, socket) do
    provider = socket.assigns.provider
    today = Date.utc_today()
    one_month_ago = Date.add(today, -30)

    socket =
      socket
      |> assign(:statistics, get_statistics(provider.id, one_month_ago, today))
      |> assign(:today_appointments, get_today_appointments(provider.id))
      |> assign(:upcoming_appointments, get_upcoming_appointments(provider.id))

    {:noreply, socket}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp get_statistics(provider_id, start_date, end_date) do
    # Get all appointments in date range
    appointments =
      Scheduling.list_appointments(provider_id: provider_id)
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

    # Calculate monthly distribution
    months =
      -5..0
      |> Enum.map(fn n ->
        Date.add(end_date, n * 30) |> Date.beginning_of_month()
      end)
      |> Enum.reverse()

    monthly_counts =
      Enum.map(months, fn month ->
        month_end = Date.end_of_month(month)
        month_name = Calendar.strftime(month, "%b")

        month_appointments =
          Enum.filter(appointments, fn a ->
            Date.compare(a.scheduled_date, month) in [:eq, :gt] &&
              Date.compare(a.scheduled_date, month_end) in [:lt, :eq]
          end)

        %{
          month: month_name,
          count: length(month_appointments),
          completed: Enum.count(month_appointments, &(&1.status == "completed")),
          no_show: Enum.count(month_appointments, &(&1.status == "no_show"))
        }
      end)

    # Daily distribution for current week
    today = Date.utc_today()
    week_start = Date.beginning_of_week(today, :monday)
    week_end = Date.end_of_week(today, :sunday)

    daily_counts =
      Date.range(week_start, week_end)
      |> Enum.map(fn date ->
        day_name = Calendar.strftime(date, "%a")
        day_appointments = Enum.filter(appointments, fn a -> a.scheduled_date == date end)

        %{
          day: day_name,
          date: date,
          count: length(day_appointments)
        }
      end)

    %{
      total_appointments: appointment_count,
      status_counts: status_counts,
      rates: %{
        completion_rate: completion_rate / 1,
        cancellation_rate: cancellation_rate / 1,
        no_show_rate: no_show_rate / 1
      },
      monthly_counts: monthly_counts,
      daily_counts: daily_counts,
      date_range: %{
        start_date: start_date,
        end_date: end_date
      }
    }
  end

  defp get_today_appointments(provider_id) do
    today = Date.utc_today()

    Scheduling.list_appointments(provider_id: provider_id, date: today)
    |> Enum.sort_by(& &1.scheduled_time)
    |> Enum.map(fn appointment ->
      child = Accounts.get_child!(appointment.child_id)

      %{
        id: appointment.id,
        child_name: child.name,
        scheduled_time: appointment.scheduled_time,
        formatted_time: format_time(appointment.scheduled_time),
        status: appointment.status,
        notes: appointment.notes,
        age: App.Accounts.Child.age(child)
      }
    end)
  end

  defp get_upcoming_appointments(provider_id) do
    today = Date.utc_today()

    Scheduling.list_appointments(provider_id: provider_id)
    |> Enum.filter(fn a ->
      Date.compare(a.scheduled_date, today) == :gt &&
        a.status in ["scheduled", "confirmed"]
    end)
    |> Enum.sort_by(fn a -> {a.scheduled_date, a.scheduled_time} end)
    |> Enum.take(5)
    |> Enum.map(fn appointment ->
      child = Accounts.get_child!(appointment.child_id)
      days_until = Date.diff(appointment.scheduled_date, today)

      %{
        id: appointment.id,
        child_name: child.name,
        scheduled_date: appointment.scheduled_date,
        scheduled_time: appointment.scheduled_time,
        formatted_date: format_date(appointment.scheduled_date),
        formatted_time: format_time(appointment.scheduled_time),
        status: appointment.status,
        days_until: days_until
      }
    end)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end
end
