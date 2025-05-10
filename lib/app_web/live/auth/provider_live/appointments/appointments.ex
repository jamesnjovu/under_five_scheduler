defmodule AppWeb.ProviderLive.Appointments do
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
          # Add available schedule information
        |> assign(:schedule, get_provider_schedule_for_date(provider.id, today))
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
  def handle_event("add_notes", %{"id" => id, "notes" => notes}, socket) do
    appointment = Scheduling.get_appointment!(id)

    case Scheduling.update_appointment(appointment, %{notes: notes}) do
      {:ok, _} ->
        {:noreply,
          socket
          |> put_flash(:info, "Notes updated successfully.")
          |> assign(
               :appointments,
               get_appointments_for_date(socket.assigns.provider.id, socket.assigns.current_date)
             )}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not update notes.")
          |> assign(
               :appointments,
               get_appointments_for_date(socket.assigns.provider.id, socket.assigns.current_date)
             )}
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
        scheduled_time: appointment.scheduled_time,
        formatted_time: format_time(appointment.scheduled_time),
        status: appointment.status,
        notes: appointment.notes,
        age: age
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
        String.contains?(String.downcase(a.notes || ""), search)
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
end