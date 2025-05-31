defmodule AppWeb.ChildLive.Show do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(%{"id" => id}, session, socket) do
    user = get_user_from_session(session)

    if user && Accounts.is_parent?(user) do
      child = Accounts.get_child!(id)

      # Verify the user is authorized to view this child
      if child.user_id == user.id do
        # Get child's upcoming and past appointments
        upcoming_appointments = Scheduling.upcoming_appointments(child.id)
        past_appointments = Scheduling.past_appointments(child.id)
        socket =
          socket
          |> assign(:user, user)
          |> assign(:page_title, "Child Details - #{child.name}")
          |> assign(:child, child)
          |> assign(:upcoming_appointments, upcoming_appointments)
          |> assign(:past_appointments, past_appointments)
          |> assign(:show_sidebar, false)

        {:ok, socket}
      else
        {:ok,
         socket
         |> put_flash(:error, "You don't have permission to view this child.")
         |> redirect(to: ~p"/children")}
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

  defp appointment_allowed_to_reschedule?(appointment) do
    today = Date.utc_today()

    # Only allow rescheduling for future appointments that are scheduled or confirmed
    Date.compare(appointment.scheduled_date, today) == :gt &&
    appointment.status in ["scheduled", "confirmed"]
  end

  defp appointment_allowed_to_cancel?(appointment) do
    today = Date.utc_today()

    # Only allow cancellation for future appointments that are scheduled or confirmed
    Date.compare(appointment.scheduled_date, today) == :gt &&
      appointment.status in ["scheduled", "confirmed"]
  end

  def format_next_checkup(child) do
    checkup_info = App.Accounts.Child.next_checkup_age(child)

    case checkup_info do
      %{description: description, is_overdue: true} ->
        "Overdue: #{description}"
      %{description: description, priority: "high"} ->
        "Due: #{description}"
      %{description: description} ->
        description
      _ ->
        "Schedule checkup"
    end
  end

  def checkup_badge_class(child) do
    checkup_info = App.Accounts.Child.next_checkup_age(child)

    case checkup_info do
      %{is_overdue: true} -> "bg-red-100 text-red-800"
      %{priority: "high"} -> "bg-orange-100 text-orange-800"
      %{priority: "medium"} -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-green-100 text-green-800"
    end
  end
end
