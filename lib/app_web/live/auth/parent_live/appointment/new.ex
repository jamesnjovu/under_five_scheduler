defmodule AppWeb.AppointmentLive.New do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.Scheduling.Appointment

  @impl true
  def mount(params, session, socket) do
    user = get_user_from_session(session)

    if user && Accounts.is_parent?(user) do
      children = Accounts.list_children(user.id)
      providers = Scheduling.list_providers()

      # Pre-select a child if child_id is in params
      selected_child_id =
        case params do
          %{"child_id" => child_id} -> String.to_integer(child_id)
          _ -> nil
        end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "Schedule Appointment")
        |> assign(:children, children)
        |> assign(:providers, providers)
        |> assign(:selected_child_id, selected_child_id)
        |> assign(:selected_provider_id, nil)
        |> assign(:selected_date, nil)
        |> assign(:available_slots, [])
        |> assign(:selected_time, nil)
        |> assign(:appointment_changeset, nil)
        |> assign(
          :current_step,
          if(selected_child_id, do: "select_provider", else: "select_child")
        )
        |> assign(:show_sidebar, false)

      {:ok, socket}
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
  def handle_event("select_child", %{"child_id" => child_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_child_id, String.to_integer(child_id))
     |> assign(:current_step, "select_provider")}
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
    IO.inspect :running
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
      # Create appointment changeset
      appointment_params = %{
        child_id: socket.assigns.selected_child_id,
        provider_id: socket.assigns.selected_provider_id,
        scheduled_date: socket.assigns.selected_date,
        scheduled_time: time,
        status: "scheduled",
        notes: ""
      }

      changeset = Appointment.changeset(%Appointment{}, appointment_params)

      {:noreply,
       socket
       |> assign(:selected_time, time)
       |> assign(:appointment_changeset, changeset)
       |> assign(:current_step, "confirm")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Invalid time selected.")}
    end
  end

  @impl true
  def handle_event("update_notes", %{"notes" => notes}, socket) do
    changeset =
      socket.assigns.appointment_changeset
      |> Ecto.Changeset.put_change(:notes, notes)

    {:noreply, assign(socket, :appointment_changeset, changeset)}
  end

  @impl true
  def handle_event("confirm_appointment", _params, socket) do
    appointment_params = Ecto.Changeset.apply_changes(socket.assigns.appointment_changeset)

    case Scheduling.create_appointment(Map.from_struct(appointment_params)) do
      {:ok, appointment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Appointment scheduled successfully!")
         |> redirect(to: ~p"/appointments/#{appointment.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error creating appointment. Please try again.")
         |> assign(:appointment_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("back", _params, socket) do
    current_step = socket.assigns.current_step

    previous_step =
      case current_step do
        "select_provider" -> "select_child"
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
end
