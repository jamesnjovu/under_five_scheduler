# lib/app_web/live/auth/provider_live/appointments/appointments.ex

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
        |> assign(:schedule, get_provider_schedule_for_date(provider_id, date))}
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
      |> assign(:schedule, get_provider_schedule_for_date(provider_id, new_date))}
  end

  @impl true
  def handle_event("next_day", _, socket) do
    new_date = Date.add(socket.assigns.current_date, 1)
    provider_id = socket.assigns.provider.id

    {:noreply,
      socket
      |> assign(:current_date, new_date)
      |> assign(:appointments, get_appointments_for_date(provider_id, new_date))
      |> assign(:schedule, get_provider_schedule_for_date(provider_id, new_date))}
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
             )}

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
      )}
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
        )}
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
           )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:stats_updated}, socket) do
    # Dashboard stats updated, could refresh any summary data
    {:noreply, socket}
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

  # Additional stats and metrics functions

  defp get_daily_appointment_summary(provider_id, date) do
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

  defp get_health_activity_summary(provider_id, date) do
    # Get health-related activities for the day
    appointments = get_appointments_for_date(provider_id, date)
    child_ids = Enum.map(appointments, & &1.child_id)

    if date == Date.utc_today() do
      # Count health records created today
      growth_records_today =
        Enum.reduce(child_ids, 0, fn child_id, acc ->
          records = HealthRecords.list_growth_records(child_id)
          today_records = Enum.count(records, &(&1.measurement_date == date))
          acc + today_records
        end)

      immunizations_today =
        Enum.reduce(child_ids, 0, fn child_id, acc ->
          records = HealthRecords.list_immunization_records(child_id)
          today_records = Enum.count(records, fn record ->
            record.administered_date == date and record.status == "administered"
          end)
          acc + today_records
        end)

      %{
        growth_records: growth_records_today,
        immunizations_administered: immunizations_today,
        children_with_alerts: count_children_with_health_alerts(child_ids)
      }
    else
      %{growth_records: 0, immunizations_administered: 0, children_with_alerts: 0}
    end
  end

  defp count_children_with_health_alerts(child_ids) do
    Enum.count(child_ids, fn child_id ->
      alerts = HealthRecords.get_health_alerts(child_id)
      length(alerts) > 0
    end)
  end

  # Validation functions

  defp validate_appointment_access(appointment, provider_id) do
    appointment.provider_id == provider_id
  end

  defp validate_date_access(date) do
    # Providers can view appointments for any date, but health modifications
    # are restricted to today's appointments
    Date.compare(date, Date.add(Date.utc_today(), -365)) != :lt and
    Date.compare(date, Date.add(Date.utc_today(), 365)) != :gt
  end

  # Error handling

  defp handle_appointment_error(socket, error_type, appointment_id \\ nil) do
    message = case error_type do
      :not_found -> "Appointment not found."
      :access_denied -> "You don't have access to this appointment."
      :invalid_status -> "Cannot perform this action with current appointment status."
      :invalid_date -> "Invalid date for appointment modification."
      _ -> "An error occurred. Please try again."
    end

    socket
    |> put_flash(:error, message)
    |> assign(
         :appointments,
         get_appointments_for_date(socket.assigns.provider.id, socket.assigns.current_date)
       )
  end
end