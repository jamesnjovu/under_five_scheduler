defmodule AppWeb.DashboardLive.Index do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(App.PubSub, "user:#{user.id}")
    end

    children = Accounts.list_children(user.id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:children, children)
      |> assign(:upcoming_appointments, get_upcoming_appointments(children))
      |> assign(:page_title, "Dashboard")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("book_appointment", %{"child_id" => child_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/appointments/new?child_id=#{child_id}")}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp get_upcoming_appointments(children) do
    children
    |> Enum.flat_map(fn child ->
      Scheduling.upcoming_appointments(child.id)
    end)
    |> Enum.sort_by(fn appointment ->
      {appointment.scheduled_date, appointment.scheduled_time}
    end)
    |> Enum.take(5)
  end
end
