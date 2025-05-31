defmodule AppWeb.DashboardLive.Index do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if user && Accounts.is_parent?(user) do
      children = Accounts.list_children(user.id)

      # Get upcoming appointments for all children
      upcoming_appointments =
        children
        |> Enum.flat_map(fn child ->
          Scheduling.upcoming_appointments(child.id)
        end)
        |> Enum.sort_by(fn appt -> {appt.scheduled_date, appt.scheduled_time} end)
        |> Enum.take(5)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "Parent Dashboard")
        |> assign(:children, children)
        |> assign(:upcoming_appointments, upcoming_appointments)
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
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Parent Dashboard")
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

  defp format_next_checkup(child) do
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
end
