defmodule AppWeb.AppointmentLive.Index do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if user && Accounts.is_parent?(user) do
      children = Accounts.list_children(user.id)

      # Get appointments for all children
      all_appointments =
        children
        |> Enum.flat_map(fn child ->
          Scheduling.list_appointments(child_id: child.id)
        end)
        |> Enum.sort_by(fn appt -> {appt.scheduled_date, appt.scheduled_time} end, :desc)

      # Separate upcoming and past appointments
      today = Date.utc_today()

      {upcoming, past} =
        Enum.split_with(all_appointments, fn appt ->
          Date.compare(appt.scheduled_date, today) in [:eq, :gt]
        end)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "My Appointments")
        |> assign(:children, children)
        |> assign(:upcoming_appointments, upcoming)
        |> assign(:past_appointments, past)
        |> assign(:show_sidebar, false)
        |> assign(:filter, "all")
        |> assign(:search, "")
        |> assign(:active_tab, "upcoming")

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be a parent to access this page.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "My Appointments")
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
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
  def handle_event("change_tab", %{"tab" => tab}, socket) when tab in ["upcoming", "past"] do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("cancel_appointment", %{"id" => id}, socket) do
    appointment = Scheduling.get_appointment!(id)

    # Verify the user has permission to cancel this appointment
    child = Accounts.get_child!(appointment.child_id)

    if child.user_id == socket.assigns.user.id do
      case Scheduling.update_appointment(appointment, %{status: "cancelled"}) do
        {:ok, _updated} ->
          # Refresh the appointment lists
          handle_info(:refresh_appointments, socket)

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not cancel the appointment. Please try again.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to cancel this appointment.")}
    end
  end

  @impl true
  def handle_info(:refresh_appointments, socket) do
    user = socket.assigns.user
    children = socket.assigns.children

    # Refresh all appointments
    all_appointments =
      children
      |> Enum.flat_map(fn child ->
        Scheduling.list_appointments(child_id: child.id)
      end)
      |> Enum.sort_by(fn appt -> {appt.scheduled_date, appt.scheduled_time} end, :desc)

    # Separate upcoming and past appointments
    today = Date.utc_today()

    {upcoming, past} =
      Enum.split_with(all_appointments, fn appt ->
        Date.compare(appt.scheduled_date, today) in [:eq, :gt]
      end)

    {:noreply,
     socket
     |> put_flash(:info, "Appointment updated successfully.")
     |> assign(:upcoming_appointments, upcoming)
     |> assign(:past_appointments, past)}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    Accounts.get_user_by_session_token(token)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
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

    Enum.filter(appointments, fn appt ->
      child_name = appt.child.name |> String.downcase()
      provider_name = appt.provider.name |> String.downcase()
      notes = (appt.notes || "") |> String.downcase()

      String.contains?(child_name, search) ||
        String.contains?(provider_name, search) ||
        String.contains?(notes, search)
    end)
  end
end
