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
        |> assign(:specializations, list_all_specializations())
        |> assign(:categories, list_all_categories())
        |> assign(:statistics, get_statistics())
        |> assign(:show_specialization_form, false)
        |> assign(:show_category_form, false)
        |> assign(:editing_specialization, nil)
        |> assign(:editing_category, nil)
        |> assign(:specialization_changeset, create_empty_specialization_changeset())
        |> assign(:category_changeset, create_empty_category_changeset())
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
    changeset = create_empty_specialization_changeset()

    {:noreply,
      socket
      |> assign(:show_specialization_form, true)
      |> assign(:editing_specialization, nil)
      |> assign(:specialization_changeset, changeset)}
  end

  @impl true
  def handle_event("edit_specialization", %{"id" => id}, socket) do
    try do
      specialization = Specializations.get_specialization!(id)
      changeset = Specializations.change_specialization(specialization)

      {:noreply,
        socket
        |> assign(:show_specialization_form, true)
        |> assign(:editing_specialization, specialization)
        |> assign(:specialization_changeset, changeset)}
    rescue
      _ ->
        {:noreply,
          socket
          |> put_flash(:error, "Specialization not found.")
          |> refresh_data()}
    end
  end

  @impl true
  def handle_event("save_specialization", %{"specialization" => specialization_params}, socket) do
    case socket.assigns.editing_specialization do
      nil ->
        # Creating new specialization
        case Specializations.create_specialization(specialization_params) do
          {:ok, _specialization} ->
            {:noreply,
              socket
              |> put_flash(:info, "Specialization created successfully.")
              |> refresh_data()
              |> assign(:show_specialization_form, false)
              |> assign(:specialization_changeset, create_empty_specialization_changeset())}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :specialization_changeset, changeset)}
        end

      specialization ->
        # Updating existing specialization
        case Specializations.update_specialization(specialization, specialization_params) do
          {:ok, _specialization} ->
            {:noreply,
              socket
              |> put_flash(:info, "Specialization updated successfully.")
              |> refresh_data()
              |> assign(:show_specialization_form, false)
              |> assign(:editing_specialization, nil)
              |> assign(:specialization_changeset, create_empty_specialization_changeset())}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :specialization_changeset, changeset)}
        end
    end
  end

  @impl true
  def handle_event("delete_specialization", %{"id" => id}, socket) do
    try do
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
    rescue
      _ ->
        {:noreply,
          socket
          |> put_flash(:error, "Specialization not found.")
          |> refresh_data()}
    end
  end

  # Category events
  @impl true
  def handle_event("new_category", _, socket) do
    changeset = create_empty_category_changeset()

    {:noreply,
      socket
      |> assign(:show_category_form, true)
      |> assign(:editing_category, nil)
      |> assign(:category_changeset, changeset)}
  end

  @impl true
  def handle_event("edit_category", %{"id" => id}, socket) do
    try do
      category = Specializations.get_category!(id)
      changeset = Specializations.change_category(category)

      {:noreply,
        socket
        |> assign(:show_category_form, true)
        |> assign(:editing_category, category)
        |> assign(:category_changeset, changeset)}
    rescue
      _ ->
        {:noreply,
          socket
          |> put_flash(:error, "Category not found.")
          |> refresh_data()}
    end
  end

  @impl true
  def handle_event("save_category", %{"specialization_category" => category_params}, socket) do
    case socket.assigns.editing_category do
      nil ->
        # Creating new category
        case Specializations.create_category(category_params) do
          {:ok, _category} ->
            {:noreply,
              socket
              |> put_flash(:info, "Category created successfully.")
              |> refresh_data()
              |> assign(:show_category_form, false)
              |> assign(:category_changeset, create_empty_category_changeset())}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :category_changeset, changeset)}
        end

      category ->
        # Updating existing category
        case Specializations.update_category(category, category_params) do
          {:ok, _category} ->
            {:noreply,
              socket
              |> put_flash(:info, "Category updated successfully.")
              |> refresh_data()
              |> assign(:show_category_form, false)
              |> assign(:editing_category, nil)
              |> assign(:category_changeset, create_empty_category_changeset())}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :category_changeset, changeset)}
        end
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    try do
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
            |> put_flash(:error, "Could not delete category. It may contain active specializations.")
            |> refresh_data()}
      end
    rescue
      _ ->
        {:noreply,
          socket
          |> put_flash(:error, "Category not found.")
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
      |> assign(:specialization_changeset, create_empty_specialization_changeset())}
  end

  @impl true
  def handle_event("cancel_category_form", _, socket) do
    {:noreply,
      socket
      |> assign(:show_category_form, false)
      |> assign(:editing_category, nil)
      |> assign(:category_changeset, create_empty_category_changeset())}
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

  # Private helper functions

  defp apply_action(socket, :index, _params) do
    socket
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    Accounts.get_user_by_session_token(token)
  end

  defp refresh_data(socket) do
    socket
    |> assign(:specializations, list_all_specializations())
    |> assign(:categories, list_all_categories())
    |> assign(:statistics, get_statistics())
  end

  # Helper functions that combine database and configuration data
  defp list_all_specializations do
    # Get database specializations
    db_specializations = try do
      Specializations.list_specializations()
    rescue
      _ -> []
    end

    # Get configuration specializations
    config_specializations = App.Setup.Specializations.all_specializations()

    # Combine them, preferring database entries
    db_codes = Enum.map(db_specializations, & &1.code)

    missing_from_db = Enum.filter(config_specializations, fn config_spec ->
      config_spec.code not in db_codes
    end)

    # Convert config specs to a similar format for display
    config_as_db_format = Enum.map(missing_from_db, fn config_spec ->
      %{
        id: "config_#{config_spec.code}",
        code: config_spec.code,
        name: config_spec.name,
        description: config_spec.description,
        can_prescribe: config_spec.can_prescribe,
        requires_license: config_spec.requires_license,
        icon: config_spec.icon,
        category: config_spec.category,
        is_active: true,
        source: :config
      }
    end)

    # Mark database entries and sort by name
    db_with_source = Enum.map(db_specializations, fn spec ->
      Map.put(spec, :source, :database)
    end)

    (db_with_source ++ config_as_db_format)
    |> Enum.sort_by(& &1.name)
  end

  defp list_all_categories do
    # Get database categories
    db_categories = try do
      Specializations.list_categories()
    rescue
      _ -> []
    end

    # Get configuration categories
    config_categories = App.Setup.Specializations.all_categories()

    # Combine them, preferring database entries
    db_codes = Enum.map(db_categories, & &1.code)

    missing_from_db = Enum.filter(config_categories, fn config_cat ->
      config_cat.code not in db_codes
    end)

    # Convert config categories to a similar format
    config_as_db_format = Enum.map(missing_from_db, fn config_cat ->
      %{
        id: "config_#{config_cat.code}",
        code: config_cat.code,
        name: config_cat.name,
        description: config_cat.description,
        is_active: true,
        source: :config
      }
    end)

    # Mark database entries and sort by name
    db_with_source = Enum.map(db_categories, fn cat ->
      Map.put(cat, :source, :database)
    end)

    (db_with_source ++ config_as_db_format)
    |> Enum.sort_by(& &1.name)
  end

  defp get_statistics do
    specializations = list_all_specializations()
    categories = list_all_categories()

    %{
      total_specializations: length(specializations),
      total_categories: length(categories),
      prescribing_count: Enum.count(specializations, &(&1.can_prescribe)),
      licensed_count: Enum.count(specializations, &(&1.requires_license)),
      database_specializations: Enum.count(specializations, &(&1.source == :database)),
      config_specializations: Enum.count(specializations, &(&1.source == :config))
    }
  end

  defp create_empty_specialization_changeset do
    try do
      Specializations.change_specialization(%Specialization{})
    rescue
      _ ->
        # Fallback if Specialization module is not available
        %Ecto.Changeset{
          action: nil,
          changes: %{},
          errors: [],
          data: %{},
          valid?: true
        }
    end
  end

  defp create_empty_category_changeset do
    try do
      Specializations.change_category(%SpecializationCategory{})
    rescue
      _ ->
        # Fallback if SpecializationCategory module is not available
        %Ecto.Changeset{
          action: nil,
          changes: %{},
          errors: [],
          data: %{},
          valid?: true
        }
    end
  end

  # Helper functions for the template
  defp category_badge_class(category_code) do
    case category_code do
      "medical_doctor" -> "bg-red-100 text-red-800"
      "nursing" -> "bg-blue-100 text-blue-800"
      "mid_level" -> "bg-green-100 text-green-800"
      "community" -> "bg-yellow-100 text-yellow-800"
      "allied_health" -> "bg-purple-100 text-purple-800"
      "mental_health" -> "bg-indigo-100 text-indigo-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  # Validation helpers
  defp validate_specialization_code(code) when is_binary(code) do
    # Basic validation - could be enhanced
    case String.match?(code, ~r/^[a-z_]+$/) do
      true -> :ok
      false -> {:error, "Code must contain only lowercase letters and underscores"}
    end
  end

  defp validate_specialization_code(_), do: {:error, "Code is required"}

  defp validate_category_code(code) when is_binary(code) do
    # Basic validation - could be enhanced
    case String.match?(code, ~r/^[a-z_]+$/) do
      true -> :ok
      false -> {:error, "Code must contain only lowercase letters and underscores"}
    end
  end

  defp validate_category_code(_), do: {:error, "Code is required"}

  # Additional helper functions for working with specializations
  defp specialization_used_by_providers?(specialization_code) do
    # Check if any providers are using this specialization
    try do
      providers = App.Scheduling.list_providers()
      Enum.any?(providers, fn provider ->
        provider.specialization == specialization_code
      end)
    rescue
      _ -> false
    end
  end

  defp category_has_specializations?(category_id) when is_integer(category_id) do
    # Check if category has any specializations
    try do
      specializations = Specializations.list_specializations()
      Enum.any?(specializations, fn spec ->
        spec.category_id == category_id
      end)
    rescue
      _ -> false
    end
  end

  defp category_has_specializations?(_), do: false

  # Debug helpers (can be removed in production)
  defp debug_assigns(socket) do
    require Logger
    Logger.debug("Socket assigns: #{inspect(Map.keys(socket.assigns))}")
    socket
  end

  defp debug_changeset(changeset, label \\ "Changeset") do
    require Logger
    Logger.debug("#{label}: valid? #{changeset.valid?}, errors: #{inspect(changeset.errors)}")
    changeset
  end
end