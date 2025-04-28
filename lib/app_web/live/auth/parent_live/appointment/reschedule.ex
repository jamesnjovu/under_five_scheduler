defmodule AppWeb.AppointmentLive.Reschedule do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(%{"id" => id}, session, socket) do
    user = get_user_from_session(session)

    if user && Accounts.is_parent?(user) do
      appointment = Scheduling.get_appointment!(id)
      child = Accounts.get_child!(appointment.child_id)

      # Verify the user is authorized to reschedule this appointment
      if child.user_id == user.id do
        # Only allow rescheduling of future appointments that are scheduled or confirmed
        if appointment_allowed_to_reschedule?(appointment) do
          providers = Scheduling.list_providers()

          socket =
            socket
            |> assign(:user, user)
            |> assign(:page_title, "Reschedule Appointment")
            |> assign(:appointment, appointment)
            |> assign(:child, child)
            |> assign(:providers, providers)
            |> assign(:selected_provider_id, appointment.provider_id)
            |> assign(:selected_date, nil)
            |> assign(:available_slots, [])
            |> assign(:selected_time, nil)
            |> assign(:show_sidebar, false)
            |> assign(:current_step, "select_provider")

          {:ok, socket}
        else
          {:ok,
           socket
           |> put_flash(:error, "This appointment cannot be rescheduled.")
           |> redirect(to: ~p"/appointments/#{appointment.id}")}
        end
      else
        {:ok,
         socket
         |> put_flash(:error, "You don't have permission to reschedule this appointment.")
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
  def handle_event("select_provider", %{"provider_id" => provider_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_provider_id, String.to_integer(provider_id))
     |> assign(:current_step, "select_date")}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    with {:ok, date} <- Date.from_iso8601(date_string),
         provider_id = socket.assigns.selected_provider_id do

      # Get available slots for the selected date and provider
      available_slots = Scheduling.get_available_slots(provider_id, date)

      {:noreply,
       socket
       |> assign(:selected_date, date)
       |> assign(:available_slots, available_slots)
       |> assign(:current_step, "select_time")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Invalid date selected.")}
    end
  end

  @impl true
  def handle_event("select_time", %{"time" => time_string}, socket) do
    with [hour, minute] <- String.split(time_string, ":"),
         {hour, _} <- Integer.parse(hour),
         {minute, _} <- Integer.parse(minute),
         time = Time.new!(hour, minute, 0) do

      {:noreply,
       socket
       |> assign(:selected_time, time)
       |> assign(:current_step, "confirm")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Invalid time selected.")}
    end
  end

  @impl true
  def handle_event("confirm_reschedule", _, socket) do
    appointment = socket.assigns.appointment

    # Mark original appointment as rescheduled
    case Scheduling.update_appointment(appointment, %{status: "rescheduled"}) do
      {:ok, _} ->
        # Create new appointment
        new_appointment_params = %{
          child_id: appointment.child_id,
          provider_id: socket.assigns.selected_provider_id,
          scheduled_date: socket.assigns.selected_date,
          scheduled_time: socket.assigns.selected_time,
          status: "scheduled",
          notes: appointment.notes
        }

        case Scheduling.create_appointment(new_appointment_params) do
          {:ok, new_appointment} ->
            {:noreply,
             socket
             |> put_flash(:info, "Appointment rescheduled successfully!")
             |> redirect(to: ~p"/appointments/#{new_appointment.id}")}

          {:error, _changeset} ->
            # If we can't create the new appointment, revert the status change
            Scheduling.update_appointment(appointment, %{status: appointment.status})

            {:noreply,
             socket
             |> put_flash(:error, "Could not reschedule the appointment. Please try again.")}
        end

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not reschedule the appointment. Please try again.")}
    end
  end

  @impl true
  def handle_event("back", _params, socket) do
    current_step = socket.assigns.current_step

    previous_step = case current_step do
      "select_date" -> "select_provider"
      "select_time" -> "select_date"
      "confirm" -> "select_time"
      _ -> current_step
    end

    {:noreply, assign(socket, :current_step, previous_step)}
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

  defp appointment_allowed_to_reschedule?(appointment) do
    today = Date.utc_today()

    # Only allow rescheduling for future appointments that are scheduled or confirmed
    Date.compare(appointment.scheduled_date, today) == :gt &&
    appointment.status in ["scheduled", "confirmed"]
  end
end
