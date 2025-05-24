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
        Phoenix.PubSub.subscribe(App.PubSub, "dashboard:updates")
      end

      # Get date range for statistics
      today = Date.utc_today()
      one_month_ago = Date.add(today, -30)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:page_title, "Provider Dashboard")
        |> assign(:statistics, get_enhanced_statistics(provider.id, one_month_ago, today))
        |> assign(:today_appointments, get_today_appointments(provider.id))
        |> assign(:upcoming_appointments, get_upcoming_appointments(provider.id))
        |> assign(:recent_activity, get_recent_activity(provider.id))
        |> assign(:performance_metrics, get_performance_metrics(provider.id))
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
  def handle_event("refresh_dashboard", _, socket) do
    provider = socket.assigns.provider
    today = Date.utc_today()
    one_month_ago = Date.add(today, -30)

    socket =
      socket
      |> assign(:statistics, get_enhanced_statistics(provider.id, one_month_ago, today))
      |> assign(:today_appointments, get_today_appointments(provider.id))
      |> assign(:upcoming_appointments, get_upcoming_appointments(provider.id))
      |> assign(:recent_activity, get_recent_activity(provider.id))
      |> assign(:performance_metrics, get_performance_metrics(provider.id))
      |> put_flash(:info, "Dashboard refreshed successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:appointment_updated, _appointment}, socket) do
    provider = socket.assigns.provider
    today = Date.utc_today()
    one_month_ago = Date.add(today, -30)

    socket =
      socket
      |> assign(:statistics, get_enhanced_statistics(provider.id, one_month_ago, today))
      |> assign(:today_appointments, get_today_appointments(provider.id))
      |> assign(:upcoming_appointments, get_upcoming_appointments(provider.id))
      |> assign(:recent_activity, get_recent_activity(provider.id))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stats_updated}, socket) do
    provider = socket.assigns.provider
    today = Date.utc_today()
    one_month_ago = Date.add(today, -30)

    socket =
      socket
      |> assign(:statistics, get_enhanced_statistics(provider.id, one_month_ago, today))
      |> assign(:performance_metrics, get_performance_metrics(provider.id))

    {:noreply, socket}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp get_enhanced_statistics(provider_id, start_date, end_date) do
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
      rescheduled: Enum.count(appointments, &(&1.status == "rescheduled")),
      in_progress: Enum.count(appointments, &(&1.status == "in_progress"))
    }

    # Calculate rates
    completion_rate =
      if appointment_count > 0 do
        (status_counts.completed / appointment_count * 100) |> Float.round(1)
      else
        0.0
      end

    cancellation_rate =
      if appointment_count > 0 do
        (status_counts.cancelled / appointment_count * 100) |> Float.round(1)
      else
        0.0
      end

    no_show_rate =
      if appointment_count > 0 do
        (status_counts.no_show / appointment_count * 100) |> Float.round(1)
      else
        0.0
      end

    # Calculate attendance rate (completed + in_progress vs total)
    attendance_rate =
      if appointment_count > 0 do
        attended = status_counts.completed + status_counts.in_progress
        (attended / appointment_count * 100) |> Float.round(1)
      else
        0.0
      end

    # Calculate monthly distribution with more detail
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
          no_show: Enum.count(month_appointments, &(&1.status == "no_show")),
          cancelled: Enum.count(month_appointments, &(&1.status == "cancelled")),
          completion_rate: if length(month_appointments) > 0 do
            (Enum.count(month_appointments, &(&1.status == "completed")) / length(month_appointments) * 100) |> Float.round(1)
          else
            0.0
          end
        }
      end)

    # Enhanced daily distribution for current week
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
          count: length(day_appointments),
          completed: Enum.count(day_appointments, &(&1.status == "completed")),
          scheduled: Enum.count(day_appointments, &(&1.status in ["scheduled", "confirmed"])),
          is_today: date == today,
          is_past: Date.compare(date, today) == :lt
        }
      end)

    # Calculate growth metrics compared to previous period
    previous_period_start = Date.add(start_date, -30)
    previous_appointments =
      Scheduling.list_appointments(provider_id: provider_id)
      |> Enum.filter(fn a ->
        Date.compare(a.scheduled_date, previous_period_start) in [:eq, :gt] &&
          Date.compare(a.scheduled_date, start_date) in [:lt, :eq]
      end)

    previous_count = length(previous_appointments)
    growth_rate = if previous_count > 0 do
      ((appointment_count - previous_count) / previous_count * 100) |> Float.round(1)
    else
      0.0
    end

    %{
      total_appointments: appointment_count,
      status_counts: status_counts,
      rates: %{
        completion_rate: completion_rate,
        cancellation_rate: cancellation_rate,
        no_show_rate: no_show_rate,
        attendance_rate: attendance_rate
      },
      monthly_counts: monthly_counts,
      daily_counts: daily_counts,
      growth_metrics: %{
        current_period: appointment_count,
        previous_period: previous_count,
        growth_rate: growth_rate,
        growth_direction: cond do
          growth_rate > 0 -> :positive
          growth_rate < 0 -> :negative
          true -> :neutral
        end
      },
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
        child_id: child.id,
        scheduled_time: appointment.scheduled_time,
        formatted_time: format_time(appointment.scheduled_time),
        status: appointment.status,
        notes: appointment.notes,
        age: App.Accounts.Child.age(child),
        medical_record_number: child.medical_record_number,
        urgency: determine_appointment_urgency(appointment, child)
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
    |> Enum.take(10)  # Show more upcoming appointments
    |> Enum.map(fn appointment ->
      child = Accounts.get_child!(appointment.child_id)
      days_until = Date.diff(appointment.scheduled_date, today)

      %{
        id: appointment.id,
        child_name: child.name,
        child_id: child.id,
        scheduled_date: appointment.scheduled_date,
        scheduled_time: appointment.scheduled_time,
        formatted_date: format_date(appointment.scheduled_date),
        formatted_time: format_time(appointment.scheduled_time),
        status: appointment.status,
        days_until: days_until,
        week_indicator: cond do
          days_until <= 7 -> "This week"
          days_until <= 14 -> "Next week"
          true -> "Later"
        end
      }
    end)
  end

  defp get_recent_activity(provider_id) do
    # Get recent completed appointments and other activities
    recent_appointments =
      Scheduling.list_appointments(provider_id: provider_id)
      |> Enum.filter(&(&1.status == "completed"))
      |> Enum.sort_by(& &1.updated_at, :desc)
      |> Enum.take(5)
      |> Enum.map(fn appointment ->
        child = Accounts.get_child!(appointment.child_id)

        %{
          type: :appointment_completed,
          appointment_id: appointment.id,
          child_name: child.name,
          date: appointment.scheduled_date,
          time: appointment.scheduled_time,
          timestamp: appointment.updated_at
        }
      end)

    recent_appointments
  end

  defp get_performance_metrics(provider_id) do
    today = Date.utc_today()
    last_30_days = Date.add(today, -30)
    last_60_days = Date.add(today, -60)

    current_period_appointments =
      Scheduling.list_appointments(provider_id: provider_id)
      |> Enum.filter(fn a ->
        Date.compare(a.scheduled_date, last_30_days) in [:eq, :gt] &&
          Date.compare(a.scheduled_date, today) in [:lt, :eq]
      end)

    previous_period_appointments =
      Scheduling.list_appointments(provider_id: provider_id)
      |> Enum.filter(fn a ->
        Date.compare(a.scheduled_date, last_60_days) in [:eq, :gt] &&
          Date.compare(a.scheduled_date, last_30_days) in [:lt, :eq]
      end)

    # Calculate average daily appointments
    current_avg = length(current_period_appointments) / 30
    previous_avg = length(previous_period_appointments) / 30

    # Calculate patient satisfaction (mock data - would integrate with real feedback)
    satisfaction_score = 4.8

    # Calculate efficiency metrics
    avg_appointment_duration = 30 # minutes - would calculate from real data

    %{
      avg_daily_appointments: Float.round(current_avg, 1),
      avg_change: Float.round(current_avg - previous_avg, 1),
      patient_satisfaction: satisfaction_score,
      avg_appointment_duration: avg_appointment_duration,
      total_patients_seen: length(current_period_appointments |> Enum.map(& &1.child_id) |> Enum.uniq()),
      punctuality_score: 95.0  # Mock data - would calculate from appointment start times
    }
  end

  defp determine_appointment_urgency(appointment, child) do
    age_months = App.Accounts.Child.age_in_months(child)

    cond do
      age_months < 6 -> :high  # Infants need frequent monitoring
      age_months < 12 -> :medium
      appointment.notes && String.contains?(String.downcase(appointment.notes), ["urgent", "concern", "fever"]) -> :high
      true -> :normal
    end
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

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d at %I:%M %p")
  end

  # Helper function to determine status color classes
  defp status_color_class(status) do
    case status do
      "scheduled" -> "bg-blue-100 text-blue-800"
      "confirmed" -> "bg-green-100 text-green-800"
      "completed" -> "bg-indigo-100 text-indigo-800"
      "cancelled" -> "bg-red-100 text-red-800"
      "no_show" -> "bg-yellow-100 text-yellow-800"
      "in_progress" -> "bg-purple-100 text-purple-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  # Helper function to get urgency indicator
  defp urgency_indicator(urgency) do
    case urgency do
      :high -> "border-l-4 border-red-500"
      :medium -> "border-l-4 border-yellow-500"
      :normal -> "border-l-4 border-green-500"
    end
  end

  # Helper function to calculate time until appointment
  defp time_until_appointment(scheduled_time) do
    now = Time.utc_now()

    case Time.compare(scheduled_time, now) do
      :gt ->
        diff_seconds = Time.diff(scheduled_time, now)
        cond do
          diff_seconds < 3600 -> "in #{div(diff_seconds, 60)} min"
          diff_seconds < 7200 -> "in 1 hour"
          true -> "later today"
        end
      :eq -> "now"
      :lt -> "overdue"
    end
  end

  # Helper to get current day of week for schedule display
  defp current_day_name do
    Date.utc_today() |> Date.day_of_week() |> day_number_to_name()
  end

  defp day_number_to_name(day_number) do
    case day_number do
      1 -> "Monday"
      2 -> "Tuesday"
      3 -> "Wednesday"
      4 -> "Thursday"
      5 -> "Friday"
      6 -> "Saturday"
      7 -> "Sunday"
    end
  end
end