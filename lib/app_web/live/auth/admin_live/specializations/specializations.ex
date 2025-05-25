defmodule AppWeb.AdminLive.Specializations do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Config.{Specializations, Specialization, SpecializationCategory}

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "Specialization Management")
        |> assign(:specializations, Specializations.list_specializations())
        |> assign(:categories, Specializations.list_categories())
        |> assign(:grouped_specializations, Specializations.grouped_by_category())
        |> assign(:statistics, Specializations.get_statistics())
        |> assign(:show_specialization_form, false)
        |> assign(:show_category_form, false)
        |> assign(:editing_specialization, nil)
        |> assign(:editing_category, nil)
        |> assign(:specialization_changeset, Specializations.change_specialization(%Specialization{}))
        |> assign(:category_changeset, Specializations.change_category(%SpecializationCategory{}))
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

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  # Specialization events
  @impl true
  def handle_event("new_specialization", _, socket) do
    changeset = Specializations.change_specialization(%Specialization{})

    {:noreply,
      socket
      |> assign(:show_specialization_form, true)
      |> assign(:editing_specialization, nil)
      |> assign(:specialization_changeset, changeset)}
  end

  @impl true
  def handle_event("edit_specialization", %{"id" => id}, socket) do
    specialization = Specializations.get_specialization!(id)
    changeset = Specializations.change_specialization(specialization)

    {:noreply,
      socket
      |> assign(:show_specialization_form, true)
      |> assign(:editing_specialization, specialization)
      |> assign(:specialization_changeset, changeset)}
  end

  @impl true
  def handle_event("save_specialization", %{"specialization" => specialization_params}, socket) do
    case socket.assigns.editing_specialization do
      nil ->
        case Specializations.create_specialization(specialization_params) do
          {:ok, _specialization} ->
            {:noreply,
              socket
              |> put_flash(:info, "Specialization created successfully.")
              |> refresh_data()
              |> assign(:show_specialization_form, false)
              |> assign(:specialization_changeset, Specializations.change_specialization(%Specialization{}))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :specialization_changeset, changeset)}
        end

      specialization ->
        case Specializations.update_specialization(specialization, specialization_params) do
          {:ok, _specialization} ->
            {:noreply,
              socket
              |> put_flash(:info, "Specialization updated successfully.")
              |> refresh_data()
              |> assign(:show_specialization_form, false)
              |> assign(:editing_specialization, nil)
              |> assign(:specialization_changeset, Specializations.change_specialization(%Specialization{}))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :specialization_changeset, changeset)}
        end
    end
  end

  @impl true
  def handle_event("delete_specialization", %{"id" => id}, socket) do
    specialization = Specializations.get_specialization!(id)

    case Specializations.delete_specialization(specialization) do
      {:ok, _} ->
        {:noreply,
          socket
          |> put_flash(:info, "Specialization deleted successfully.")
          |> refresh_data()}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not delete specialization. It may be referenced by existing providers.")
          |> refresh_data()}
    end
  end

  # Category events
  @impl true
  def handle_event("new_category", _, socket) do
    changeset = Specializations.change_category(%SpecializationCategory{})

    {:noreply,
      socket
      |> assign(:show_category_form, true)
      |> assign(:editing_category, nil)
      |> assign(:category_changeset, changeset)}
  end

  @impl true
  def handle_event("edit_category", %{"id" => id}, socket) do
    category = Specializations.get_category!(id)
    changeset = Specializations.change_category(category)

    {:noreply,
      socket
      |> assign(:show_category_form, true)
      |> assign(:editing_category, category)
      |> assign(:category_changeset, changeset)}
  end

  @impl true
  def handle_event("save_category", %{"specialization_category" => category_params}, socket) do
    case socket.assigns.editing_category do
      nil ->
        case Specializations.create_category(category_params) do
          {:ok, _category} ->
            {:noreply,
              socket
              |> put_flash(:info, "Category created successfully.")
              |> refresh_data()
              |> assign(:show_category_form, false)
              |> assign(:category_changeset, Specializations.change_category(%SpecializationCategory{}))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :category_changeset, changeset)}
        end

      category ->
        case Specializations.update_category(category, category_params) do
          {:ok, _category} ->
            {:noreply,
              socket
              |> put_flash(:info, "Category updated successfully.")
              |> refresh_data()
              |> assign(:show_category_form, false)
              |> assign(:editing_category, nil)
              |> assign(:category_changeset, Specializations.change_category(%SpecializationCategory{}))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :category_changeset, changeset)}
        end
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    category = Specializations.get_category!(id)

    case Specializations.delete_category(category) do
      {:ok, _} ->
        {:noreply,
          socket
          |> put_flash(:info, "Category deleted successfully.")
          |> refresh_data()}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not delete category. It may contain specializations.")
          |> refresh_data()}
    end
  end

  # Form cancellation events
  @impl true
  def handle_event("cancel_specialization_form", _, socket) do
    {:noreply,
      socket
      |> assign(:show_specialization_form, false)
      |> assign(:editing_specialization, nil)
      |> assign(:specialization_changeset, Specializations.change_specialization(%Specialization{}))}
  end

  @impl true
  def handle_event("cancel_category_form", _, socket) do
    {:noreply,
      socket
      |> assign(:show_category_form, false)
      |> assign(:editing_category, nil)
      |> assign(:category_changeset, Specializations.change_category(%SpecializationCategory{}))}
  end

  # Validation events
  @impl true
  def handle_event("validate_specialization", %{"specialization" => specialization_params}, socket) do
    specialization = socket.assigns.editing_specialization || %Specialization{}
    changeset =
      specialization
      |> Specializations.change_specialization(specialization_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :specialization_changeset, changeset)}
  end

  @impl true
  def handle_event("validate_category", %{"specialization_category" => category_params}, socket) do
    category = socket.assigns.editing_category || %SpecializationCategory{}
    changeset =
      category
      |> Specializations.change_category(category_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :category_changeset, changeset)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp refresh_data(socket) do
    socket
    |> assign(:specializations, Specializations.list_specializations())
    |> assign(:categories, Specializations.list_categories())
    |> assign(:grouped_specializations, Specializations.grouped_by_category())
    |> assign(:statistics, Specializations.get_statistics())
  end

  # Helper functions for the template
  defp count_by_category(grouped_specializations, category_code) do
    grouped_specializations
    |> Map.get(category_code, [])
    |> length()
  end

  defp get_prescribing_count(statistics) do
    statistics.prescribing_count
  end

  defp get_licensed_count(statistics) do
    statistics.licensed_count
  end
end