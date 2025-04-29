defmodule AppWeb.AppointmentLive.Show do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(%{"id" => id}, session, socket) do
    user = get_user_from_session(session)

    if user && Accounts.is_parent?(user) do
      appointment = Scheduling.get_appointment!(id)
      child = Accounts.get_child!(appointment.child_id)

      # Verify the user is authorized to view this appointment
      if child.user_id == user.id do
        socket =
          socket
          |> assign(:user, user)
          |> assign(:page_title, "Appointment Details")
          |> assign(:appointment, appointment)
          |> assign(:show_sidebar, false)

        {:ok, socket}
      else
        {:ok,
         socket
         |> put_flash(:error, "You don't have permission to view this appointment.")
         |> redirect(to: ~p"/appointments")}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be a parent to access this page.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("cancel_appointment", _, socket) do
    appointment = socket.assigns.appointment

    case Scheduling.update_appointment(appointment, %{status: "cancelled"}) do
      {:ok, updated_appointment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Appointment cancelled successfully.")
         |> assign(:appointment, updated_appointment)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not cancel the appointment. Please try again.")}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    Accounts.get_user_by_session_token(token)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end

  defp appointment_allowed_to_cancel?(appointment) do
    today = Date.utc_today()

    # Only allow cancellation for future appointments that are scheduled or confirmed
    Date.compare(appointment.scheduled_date, today) == :gt &&
    appointment.status in ["scheduled", "confirmed"]
  end

  defp appointment_allowed_to_reschedule?(appointment) do
    today = Date.utc_today()

    # Only allow rescheduling for future appointments that are scheduled or confirmed
    Date.compare(appointment.scheduled_date, today) == :gt &&
    appointment.status in ["scheduled", "confirmed"]
  end
end
