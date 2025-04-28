defmodule AppWeb.ChildLive.Index do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Accounts.Child
  alias App.Scheduling

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if user && Accounts.is_parent?(user) do
      children = Accounts.list_children(user.id)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "My Children")
        |> assign(:children, children)
        |> assign(:child, %Child{})
        |> assign(:changeset, Accounts.change_child(%Child{}))
        |> assign(:show_sidebar, false)
        |> assign(:show_modal, false)

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

  defp apply_action(socket, :edit, %{"id" => id}) do
    child = Accounts.get_child!(id)

    socket
    |> assign(:page_title, "Edit Child")
    |> assign(:child, child)
    |> assign(:changeset, Accounts.change_child(child))
    |> assign(:show_modal, true)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add New Child")
    |> assign(:child, %Child{})
    |> assign(:changeset, Accounts.change_child(%Child{}))
    |> assign(:show_modal, true)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "My Children")
    |> assign(:child, %Child{})
    |> assign(:show_modal, false)
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/children")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    child = Accounts.get_child!(id)
    {:ok, _} = Accounts.delete_child(child)

    {:noreply,
     socket
     |> put_flash(:info, "Child deleted successfully.")
     |> assign(:children, Accounts.list_children(socket.assigns.user.id))}
  end

  @impl true
  def handle_event("save", %{"child" => child_params}, socket) do
    save_child(socket, socket.assigns.live_action, child_params)
  end

  @impl true
  def handle_event("validate", %{"child" => child_params}, socket) do
    changeset =
      socket.assigns.child
      |> Accounts.change_child(child_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  defp save_child(socket, :edit, child_params) do
    case Accounts.update_child(socket.assigns.child, child_params) do
      {:ok, _child} ->
        {:noreply,
         socket
         |> put_flash(:info, "Child updated successfully.")
         |> push_patch(to: ~p"/children")
         |> assign(:children, Accounts.list_children(socket.assigns.user.id))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_child(socket, :new, child_params) do
    case Accounts.create_child(socket.assigns.user, child_params) do
      {:ok, _child} ->
        {:noreply,
         socket
         |> put_flash(:info, "Child added successfully.")
         |> push_patch(to: ~p"/children")
         |> assign(:children, Accounts.list_children(socket.assigns.user.id))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    Accounts.get_user_by_session_token(token)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end
end
