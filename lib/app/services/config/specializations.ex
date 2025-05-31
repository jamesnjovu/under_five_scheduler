defmodule App.Config.Specializations do
  @moduledoc """
  Database-backed specialization management system.
  Provides functions for managing provider specializations and categories.

  This module works in conjunction with the configuration-based specializations
  to provide a hybrid approach where core specializations are defined in config
  but can be extended and managed through the database.
  """

  import Ecto.Query, warn: false
  alias App.Repo
  alias App.Config.{Specialization, SpecializationCategory}

  # Category functions

  @doc """
  Returns the list of all active categories ordered by display order.
  """
  def list_categories do
    SpecializationCategory
    |> where([c], c.is_active == true)
    |> order_by([c], [asc: c.display_order, asc: c.name])
    |> Repo.all()
  end

  @doc """
  Gets a single category by ID.
  """
  def get_category!(id), do: Repo.get!(SpecializationCategory, id)

  @doc """
  Gets a category by code.
  """
  def get_category_by_code(code) do
    Repo.get_by(SpecializationCategory, code: code, is_active: true)
  end

  @doc """
  Creates a category.
  """
  def create_category(attrs \\ %{}) do
    %SpecializationCategory{}
    |> SpecializationCategory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category.
  """
  def update_category(%SpecializationCategory{} = category, attrs) do
    category
    |> SpecializationCategory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category (soft delete by setting is_active to false).
  """
  def delete_category(%SpecializationCategory{} = category) do
    update_category(category, %{is_active: false})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.
  """
  def change_category(%SpecializationCategory{} = category, attrs \\ %{}) do
    SpecializationCategory.changeset(category, attrs)
  end

  # Specialization functions

  @doc """
  Returns the list of all active specializations ordered by display order.
  """
  def list_specializations do
    Specialization
    |> where([s], s.is_active == true)
    |> order_by([s], [asc: s.display_order, asc: s.name])
    |> preload(:category)
    |> Repo.all()
  end

  @doc """
  Returns specializations grouped by category.
  """
  def list_specializations_grouped do
    categories = list_categories()

    Enum.map(categories, fn category ->
      specializations =
        Specialization
        |> where([s], s.category_id == ^category.id and s.is_active == true)
        |> order_by([s], [asc: s.display_order, asc: s.name])
        |> Repo.all()

      {category, specializations}
    end)
    |> Enum.filter(fn {_category, specializations} -> length(specializations) > 0 end)
  end

  @doc """
  Gets a single specialization by ID.
  """
  def get_specialization!(id) do
    Specialization
    |> preload(:category)
    |> Repo.get!(id)
  end

  @doc """
  Gets a specialization by code.
  """
  def get_specialization_by_code(code) do
    Specialization
    |> where([s], s.code == ^code and s.is_active == true)
    |> preload(:category)
    |> Repo.one()
  end

  @doc """
  Creates a specialization.
  """
  def create_specialization(attrs \\ %{}) do
    %Specialization{}
    |> Specialization.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a specialization.
  """
  def update_specialization(%Specialization{} = specialization, attrs) do
    specialization
    |> Specialization.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a specialization (soft delete by setting is_active to false).
  """
  def delete_specialization(%Specialization{} = specialization) do
    update_specialization(specialization, %{is_active: false})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking specialization changes.
  """
  def change_specialization(%Specialization{} = specialization, attrs \\ %{}) do
    Specialization.changeset(specialization, attrs)
  end

  # Query helpers

  @doc """
  Returns a list of specialization codes for validation.
  """
  def valid_codes do
    Specialization
    |> where([s], s.is_active == true)
    |> select([s], s.code)
    |> Repo.all()
  end

  @doc """
  Returns the display name for a specialization code.
  """
  def display_name(code) when is_binary(code) do
    case get_specialization_by_code(code) do
      %Specialization{name: name} -> name
      nil ->
        # Fallback to configuration-based lookup
        case App.Setup.Specializations.get_by_code(code) do
          %{name: name} -> name
          nil -> String.replace(code, "_", " ") |> String.capitalize()
        end
    end
  end

  @doc """
  Returns the description for a specialization code.
  """
  def description(code) when is_binary(code) do
    case get_specialization_by_code(code) do
      %Specialization{description: desc} -> desc
      nil ->
        # Fallback to configuration-based lookup
        case App.Setup.Specializations.get_by_code(code) do
          %{description: desc} -> desc
          nil -> nil
        end
    end
  end

  @doc """
  Returns specializations that can prescribe medications.
  """
  def prescribing_specializations do
    Specialization
    |> where([s], s.can_prescribe == true and s.is_active == true)
    |> preload(:category)
    |> Repo.all()
  end

  @doc """
  Returns specializations that require licensing.
  """
  def licensed_specializations do
    Specialization
    |> where([s], s.requires_license == true and s.is_active == true)
    |> preload(:category)
    |> Repo.all()
  end

  @doc """
  Returns specializations for a specific category.
  """
  def specializations_by_category(category_code) do
    category = get_category_by_code(category_code)

    if category do
      Specialization
      |> where([s], s.category_id == ^category.id and s.is_active == true)
      |> order_by([s], [asc: s.display_order, asc: s.name])
      |> Repo.all()
    else
      []
    end
  end

  @doc """
  Returns options for HTML select elements.
  Format: [{display_name, code}, ...]
  """
  def select_options do
    list_specializations()
    |> Enum.map(&{&1.name, &1.code})
  end

  @doc """
  Returns options grouped by category for HTML select elements.
  Format: %{category_name => [{display_name, code}, ...]}
  """
  def grouped_select_options do
    list_specializations_grouped()
    |> Enum.map(fn {category, specializations} ->
      options = Enum.map(specializations, &{&1.name, &1.code})
      {category.name, options}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Validates if a specialization code is valid.
  """
  def valid?(code) do
    code in valid_codes()
  end

  @doc """
  Returns the icon class for a specialization.
  """
  def icon(code) when is_binary(code) do
    case get_specialization_by_code(code) do
      %Specialization{icon: icon} -> icon || "user-md"
      nil ->
        # Fallback to configuration-based lookup
        case App.Setup.Specializations.get_by_code(code) do
          %{icon: icon} -> icon
          nil -> "user-md"
        end
    end
  end

  @doc """
  Returns specializations that are most common in pediatric care.
  """
  def pediatric_focused do
    codes = ["pediatrician", "nurse", "clinical_officer", "community_health_worker"]

    Specialization
    |> where([s], s.code in ^codes and s.is_active == true)
    |> preload(:category)
    |> Repo.all()
  end

  @doc """
  Returns specializations suitable for primary care.
  """
  def primary_care do
    codes = ["pediatrician", "general_practitioner", "nurse_practitioner", "clinical_officer"]

    Specialization
    |> where([s], s.code in ^codes and s.is_active == true)
    |> preload(:category)
    |> Repo.all()
  end

  # Administrative functions

  @doc """
  Reorders specializations within a category.
  """
  def reorder_specializations(specialization_ids) do
    Repo.transaction(fn ->
      specialization_ids
      |> Enum.with_index(1)
      |> Enum.each(fn {id, order} ->
        from(s in Specialization, where: s.id == ^id)
        |> Repo.update_all(set: [display_order: order])
      end)
    end)
  end

  @doc """
  Reorders categories.
  """
  def reorder_categories(category_ids) do
    Repo.transaction(fn ->
      category_ids
      |> Enum.with_index(1)
      |> Enum.each(fn {id, order} ->
        from(c in SpecializationCategory, where: c.id == ^id)
        |> Repo.update_all(set: [display_order: order])
      end)
    end)
  end

  @doc """
  Gets statistics about specializations.
  """
  def get_statistics do
    total_specializations = Repo.aggregate(Specialization, :count, :id, where: [is_active: true])
    total_categories = Repo.aggregate(SpecializationCategory, :count, :id, where: [is_active: true])
    prescribing_count = Repo.aggregate(Specialization, :count, :id, where: [can_prescribe: true, is_active: true])
    licensed_count = Repo.aggregate(Specialization, :count, :id, where: [requires_license: true, is_active: true])

    %{
      total_specializations: total_specializations,
      total_categories: total_categories,
      prescribing_count: prescribing_count,
      licensed_count: licensed_count
    }
  end

  @doc """
  Initializes the database with specializations from the configuration.
  This function can be called during migrations or setup to populate
  the database with the configuration-based specializations.
  """
  def initialize_from_config do
    config_specializations = App.Setup.Specializations.all_specializations()
    config_categories = App.Setup.Specializations.all_categories()

    Repo.transaction(fn ->
      # Create categories first
      Enum.each(config_categories, fn category_config ->
        case get_category_by_code(category_config.code) do
          nil ->
            create_category(%{
              code: category_config.code,
              name: category_config.name,
              description: category_config.description,
              display_order: 0,
              is_active: true
            })
          _existing -> :ok
        end
      end)

      # Create specializations
      Enum.each(config_specializations, fn spec_config ->
        case get_specialization_by_code(spec_config.code) do
          nil ->
            category = get_category_by_code(spec_config.category)
            if category do
              create_specialization(%{
                code: spec_config.code,
                name: spec_config.name,
                description: spec_config.description,
                category_id: category.id,
                requires_license: spec_config.requires_license,
                can_prescribe: spec_config.can_prescribe,
                icon: spec_config.icon,
                display_order: 0,
                is_active: true
              })
            end
          _existing -> :ok
        end
      end)
    end)
  end

  # Legacy compatibility functions for existing code

  @doc """
  Returns all specializations (for backward compatibility).
  """
  def all_specializations, do: list_specializations()

  @doc """
  Returns all categories (for backward compatibility).
  """
  def all_categories, do: list_categories()

  @doc """
  Returns specializations grouped by category code.
  """
  def grouped_by_category do
    list_specializations_grouped()
    |> Enum.map(fn {category, specializations} ->
      {category.code, specializations}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Returns a specific specialization by code (for backward compatibility).
  """
  def get_by_code(code), do: get_specialization_by_code(code)

  @doc """
  Returns specializations by category code (for backward compatibility).
  """
  def by_category(category_code), do: specializations_by_category(category_code)

  @doc """
  Sync database specializations with configuration.
  This can be useful during deployments to ensure database is up to date.
  """
  def sync_with_config do
    config_specs = App.Setup.Specializations.all_specializations()
    db_specs = list_specializations()

    # Find specializations that exist in config but not in database
    config_codes = Enum.map(config_specs, & &1.code)
    db_codes = Enum.map(db_specs, & &1.code)

    missing_codes = config_codes -- db_codes

    if length(missing_codes) > 0 do
      initialize_from_config()
      {:ok, "Added #{length(missing_codes)} specializations from configuration"}
    else
      {:ok, "Database is already in sync with configuration"}
    end
  end

  @doc """
  Returns specializations that are available in configuration but not in database.
  """
  def missing_from_database do
    config_specs = App.Setup.Specializations.all_specializations()
    db_codes = valid_codes()

    Enum.filter(config_specs, fn spec -> spec.code not in db_codes end)
  end

  @doc """
  Returns specializations that are in database but not in configuration.
  This might indicate outdated entries that could be deactivated.
  """
  def not_in_configuration do
    config_codes = App.Setup.Specializations.all_specializations()
                   |> Enum.map(& &1.code)

    list_specializations()
    |> Enum.filter(fn spec -> spec.code not in config_codes end)
  end

  @doc """
  Health check function to ensure database and configuration are consistent.
  """
  def health_check do
    missing = missing_from_database()
    extra = not_in_configuration()
    total_db = Repo.aggregate(Specialization, :count, :id, where: [is_active: true])
    total_config = length(App.Setup.Specializations.all_specializations())

    %{
      status: if(length(missing) == 0 and length(extra) == 0, do: :healthy, else: :needs_sync),
      total_in_database: total_db,
      total_in_configuration: total_config,
      missing_from_database: length(missing),
      not_in_configuration: length(extra),
      suggestions: generate_health_suggestions(missing, extra)
    }
  end

  defp generate_health_suggestions(missing, extra) do
    suggestions = []

    suggestions = if length(missing) > 0 do
      suggestions ++ ["Run sync_with_config/0 to add missing specializations"]
    else
      suggestions
    end

    suggestions = if length(extra) > 0 do
      suggestions ++ ["Consider deactivating specializations not in configuration: #{Enum.map(extra, & &1.code) |> Enum.join(", ")}"]
    else
      suggestions
    end

    if length(suggestions) == 0 do
      ["Database and configuration are in sync"]
    else
      suggestions
    end
  end
end
