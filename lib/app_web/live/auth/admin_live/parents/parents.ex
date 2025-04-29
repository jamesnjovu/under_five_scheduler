defmodule AppWeb.AdminLive.Parents do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "parents:update")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:parents, list_parents_with_details())
        |> assign(:page_title, "Parent Management")
        |> assign(:filter, "all")
        |> assign(:search, "")
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
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    parent = Accounts.get_user!(id)

    # In a real app, consider soft-deletion or checking for dependencies
    case Accounts.delete_user(parent) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Parent deleted successfully.")
         |> assign(:parents, list_parents_with_details())}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not delete parent account.")
         |> assign(:parents, list_parents_with_details())}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp list_parents_with_details do
    # Get all users with role "parent"
    parents = Accounts.list_users_by_role("parent")

    Enum.map(parents, fn parent ->
      # Get children for this parent
      children = Accounts.list_children(parent.id)

      # Calculate registration time in days
      days_since_registration =
        DateTime.utc_now()
        |> DateTime.diff(parent.inserted_at, :day)

      # Return parent with additional details
      %{
        id: parent.id,
        name: parent.name,
        email: parent.email,
        phone: parent.phone,
        children_count: length(children),
        children: children,
        days_since_registration: days_since_registration,
        confirmed: not is_nil(parent.confirmed_at)
      }
    end)
  end

  defp filtered_parents(parents, filter, search) do
    parents
    |> filter_by_criteria(filter)
    |> search_parents(search)
  end

  defp filter_by_criteria(parents, "all"), do: parents

  defp filter_by_criteria(parents, "confirmed") do
    Enum.filter(parents, fn p -> p.confirmed end)
  end

  defp filter_by_criteria(parents, "unconfirmed") do
    Enum.filter(parents, fn p -> not p.confirmed end)
  end

  defp filter_by_criteria(parents, "with_children") do
    Enum.filter(parents, fn p -> p.children_count > 0 end)
  end

  defp filter_by_criteria(parents, "no_children") do
    Enum.filter(parents, fn p -> p.children_count == 0 end)
  end

  defp search_parents(parents, ""), do: parents

  defp search_parents(parents, search) do
    search = String.downcase(search)

    Enum.filter(parents, fn p ->
      String.contains?(String.downcase(p.name), search) ||
        String.contains?(String.downcase(p.email), search) ||
        String.contains?(String.downcase(p.phone), search)
    end)
  end
end
