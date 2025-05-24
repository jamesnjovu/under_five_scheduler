defmodule AppWeb.ProviderLive.Appointments do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.HealthRecords

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

      today = Date.utc_today()

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:page_title, "My Appointments")
        |> assign(:current_date, today)
        |> assign(:view_mode, "day")
        |> assign(:appointments, get_appointments_for_date(provider.id, today))
        |> assign(:filter, "all")
        |> assign(:search, "")
        |> assign(:schedule, get_provider_schedule_for_date(provider.id, today))
        |> assign(:show_sidebar, false)
        |> assign(:daily_stats, get_daily_stats(provider.id, today))
        |> assign(:week_dates, get_week_dates(today))

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
  def handle_event("change_date", %{"date" => date_string}, socket) do
    with {:ok, date} <- Date.from_iso8601(date_string) do
      provider_id = socket.assigns.provider.id

      {:noreply,
        socket
        |> assign(:current_date, date)
        |> assign(:appointments, get_appointments_for_date(provider_id, date))
        |> assign(:schedule, get_provider_schedule_for_date(provider_id, date))
        |> assign(:daily_stats, get_daily_stats(provider_id, date))
        |> assign(:week_dates, get_week_dates(date))}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("quick_date_change", %{"date" => date_string}, socket) do
    with {:ok, date} <- Date.from_iso8601(date_string) do
      provider_id = socket.assigns.provider.id

      {:noreply,
        socket
        |> assign(:current_date, date)
        |> assign(:appointments, get_appointments_for_date(provider_id, date))
        |> assign(:schedule, get_provider_schedule_for_date(provider_id, date))
        |> assign(:daily_stats, get_daily_stats(provider_id, date))
        |> assign(:week_dates, get_week_dates(date))}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("previous_day", _, socket) do
    new_date = Date.add(socket.assigns.current_date, -1)
    provider_id = socket.assigns.provider.id

    {:noreply,
      socket
      |> assign(:current_date, new_date)
      |> assign(:appointments, get_appointments_for_date(provider_id, new_date))
      |> assign(:schedule, get_provider_schedule_for_date(provider_id, new_date))
      |> assign(:daily_stats, get_daily_stats(provider_id, new_date))
      |> assign(:week_dates, get_week_dates(new_date))}
  end

  @impl true
  def handle_event("next_day", _, socket) do
    new_date = Date.add(socket.assigns.current_date, 1)
    provider_id = socket.assigns.provider.id

    {:noreply,
      socket
      |> assign(:current_date, new_date)
      |> assign(:appointments, get_appointments_for_date(provider_id, new_date))
      |> assign(:schedule, get_provider_schedule_for_date(provider_id, new_date))
      |> assign(:daily_stats, get_daily_stats(provider_id, new_date))
      |> assign(:week_dates, get_week_dates(new_date))}
  end

  @impl true
  def handle_event("go_to_today", _, socket) do
    today = Date.utc_today()
    provider_id = socket.assigns.provider.id

    {:noreply,
      socket
      |> assign(:current_date, today)
      |> assign(:appointments, get_appointments_for_date(provider_id, today))
      |> assign(:schedule, get_provider_schedule_for_date(provider_id, today))
      |> assign(:daily_stats, get_daily_stats(provider_id, today))
      |> assign(:week_dates, get_week_dates(today))}
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket)
      when view in ["day", "week", "month"] do
    {:noreply, assign(socket, :view_mode, view)}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("update_status", %{"id" => id, "status" => status}, socket)
      when status in [
    "scheduled",
    "confirmed",
    "cancelled",
    "completed",
    "no_show",
    "rescheduled"
  ] do
    appointment = Scheduling.get_appointment!(id)

    case Scheduling.update_appointment(appointment, %{status: status}) do
      {:ok, _updated_appointment} ->
        {:noreply,
          socket
          |> put_flash(:info, "Appointment status updated to #{status}.")
          |> assign(
               :appointments,
               get_appointments_for_date(socket.assigns.provider.id, socket.assigns.current_date)
             )
          |> assign(:daily_stats, get_daily_stats(socket.assigns.provider.id, socket.assigns.current_date))}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not update appointment status.")
          |> assign(
               :appointments,
               get_appointments_for_date(socket.assigns.provider.id, socket.assigns.current_date)
             )}
    end
  end

  @impl true
  def handle_event("start_health_check", %{"appointment_id" => appointment_id}, socket) do
    appointment = Scheduling.get_appointment!(appointment_id)

    # Verify this appointment belongs to this provider and is today
    if appointment.provider_id == socket.assigns.provider.id and
       appointment.scheduled_date == Date.utc_today() and
       appointment.status in ["scheduled", "confirmed"] do

      case Scheduling.update_appointment(appointment, %{status: "in_progress"}) do
        {:ok, _updated_appointment} ->
          {:noreply,
            socket
            |> put_flash(:info, "Health check started.")
            |> redirect(to: ~p"/provider/appointments/#{appointment_id}/health")}

        {:error, _} ->
          {:noreply,
            socket
            |> put_flash(:error, "Could not start health check.")}
      end
    else
      {:noreply,
        socket
        |> put_flash(:error, "Invalid appointment for health check.")}
    end
  end

  # Handle real-time updates
  @impl true
  def handle_info({:appointment_updated, _}, socket) do
    # Refresh appointments when changes occur elsewhere in the system
    {:noreply,
      assign(
        socket,
        :appointments,
        get_appointments_for_date(socket.assigns.provider.id, socket.assigns.current_date)
      )
      |> assign(:daily_stats, get_daily_stats(socket.assigns.provider.id, socket.assigns.current_date))}
  end

  @impl true
  def handle_info({:appointment_started, appointment}, socket) do
    # Update the specific appointment in the list
    if appointment.provider_id == socket.assigns.provider.id do
      {:noreply,
        assign(
          socket,
          :appointments,
          get_appointments_for_date(socket.assigns.provider.id, socket.assigns.current_date)
        )
        |> assign(:daily_stats, get_daily_stats(socket.assigns.provider.id, socket.assigns.current_date))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:appointment_completed, appointment}, socket) do
    # Update the specific appointment in the list
    if appointment.provider_id == socket.assigns.provider.id do
      {:noreply,
        socket
        |> put_flash(:info, "Appointment for #{appointment.child.name} completed.")
        |> assign(
             :appointments,
             get_appointments_for_date(socket.assigns.provider.id, socket.assigns.current_date)
           )
        |> assign(:daily_stats, get_daily_stats(socket.assigns.provider.id, socket.assigns.current_date))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:stats_updated}, socket) do
    # Dashboard stats updated, could refresh any summary data
    {:noreply, assign(socket, :daily_stats, get_daily_stats(socket.assigns.provider.id, socket.assigns.current_date))}
  end

  # Private helper functions

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp get_appointments_for_date(provider_id, date) do
    Scheduling.provider_appointments_for_date(provider_id, date)
    |> Enum.map(fn appointment ->
      child = Accounts.get_child!(appointment.child_id)
      age = App.Accounts.Child.age(child)

      %{
        id: appointment.id,
        child: child,
        child_id: appointment.child_id,
        scheduled_time: appointment.scheduled_time,
        formatted_time: format_time(appointment.scheduled_time),
        status: appointment.status,
        notes: appointment.notes,
        age: age,
        scheduled_date: appointment.scheduled_date,
        provider_id: appointment.provider_id
      }
    end)
    |> Enum.sort_by(fn a -> a.scheduled_time end)
  end

  # Get provider's schedule for a specific date
  defp get_provider_schedule_for_date(provider_id, date) do
    day_of_week = Date.day_of_week(date)
    Scheduling.get_provider_schedule(provider_id, day_of_week)
  end

  defp get_daily_stats(provider_id, date) do
    appointments = get_appointments_for_date(provider_id, date)

    %{
      total: length(appointments),
      scheduled: Enum.count(appointments, &(&1.status == "scheduled")),
      confirmed: Enum.count(appointments, &(&1.status == "confirmed")),
      completed: Enum.count(appointments, &(&1.status == "completed")),
      cancelled: Enum.count(appointments, &(&1.status == "cancelled")),
      no_show: Enum.count(appointments, &(&1.status == "no_show")),
      in_progress: Enum.count(appointments, &(&1.status == "in_progress"))
    }
  end

  defp get_week_dates(current_date) do
    # Get Monday of the current week
    days_from_monday = Date.day_of_week(current_date) - 1
    monday = Date.add(current_date, -days_from_monday)

    Enum.map(0..6, fn days ->
      date = Date.add(monday, days)
      %{
        date: date,
        day_name: Calendar.strftime(date, "%a"),
        day_number: date.day,
        is_today: date == Date.utc_today(),
        is_current: date == current_date
      }
    end)
  end

  defp filtered_appointments(appointments, filter, search) do
    appointments
    |> filter_by_status(filter)
    |> search_appointments(search)
  end

  defp filter_by_status(appointments, "all"), do: appointments

  defp filter_by_status(appointments, filter) do
    Enum.filter(appointments, &(&1.status == filter))
  end

  defp search_appointments(appointments, ""), do: appointments

  defp search_appointments(appointments, search) do
    search = String.downcase(search)

    Enum.filter(appointments, fn a ->
      String.contains?(String.downcase(a.child.name), search) ||
        String.contains?(String.downcase(a.notes || ""), search) ||
        String.contains?(String.downcase(a.child.medical_record_number || ""), search)
    end)
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_short_date(date) do
    Calendar.strftime(date, "%b %d")
  end

  # Health-related helper functions

  defp get_health_alerts_for_appointment(child_id, appointment_date) do
    # Only show alerts for today's appointments
    if appointment_date == Date.utc_today() do
      HealthRecords.get_health_alerts(child_id)
    else
      []
    end
  end

  defp can_start_health_check?(appointment, current_date) do
    appointment.scheduled_date == current_date and
    appointment.status in ["scheduled", "confirmed"] and
    current_date == Date.utc_today()
  end

  defp can_view_health_records?(appointment) do
    # Can always view health records, but editing is restricted
    true
  end

  defp appointment_status_color(status) do
    case status do
      "scheduled" -> "bg-blue-50 text-blue-700 border-blue-200"
      "confirmed" -> "bg-green-50 text-green-700 border-green-200"
      "completed" -> "bg-indigo-50 text-indigo-700 border-indigo-200"
      "cancelled" -> "bg-red-50 text-red-700 border-red-200"
      "no_show" -> "bg-yellow-50 text-yellow-700 border-yellow-200"
      "in_progress" -> "bg-purple-50 text-purple-700 border-purple-200"
      _ -> "bg-gray-50 text-gray-700 border-gray-200"
    end
  end

  defp appointment_icon(status) do
    case status do
      "scheduled" -> "clock"
      "confirmed" -> "check-circle"
      "completed" -> "check-circle"
      "cancelled" -> "x-circle"
      "no_show" -> "exclamation-triangle"
      "in_progress" -> "play-circle"
      _ -> "question-mark-circle"
    end
  end

  defp is_weekend?(date) do
    Date.day_of_week(date) in [6, 7]  # Saturday or Sunday
  end
end