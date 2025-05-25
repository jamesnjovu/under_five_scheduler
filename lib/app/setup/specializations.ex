defmodule App.Config.Specializations do
  @moduledoc """
  Centralized configuration for provider specializations.
  This module manages all specialization types, their display names,
  descriptions, and validation rules.
  """

  @specializations [
    %{
      code: "pediatrician",
      name: "Pediatrician",
      description: "Specialized in medical care of infants, children, and adolescents",
      category: "medical_doctor",
      requires_license: true,
      can_prescribe: true,
      icon: "stethoscope"
    },
    %{
      code: "general_practitioner",
      name: "General Practitioner",
      description: "Primary care physician providing comprehensive healthcare",
      category: "medical_doctor",
      requires_license: true,
      can_prescribe: true,
      icon: "medical-bag"
    },
    %{
      code: "nurse",
      name: "Registered Nurse",
      description: "Registered nurse specializing in child healthcare",
      category: "nursing",
      requires_license: true,
      can_prescribe: false,
      icon: "heart"
    },
    %{
      code: "nurse_practitioner",
      name: "Nurse Practitioner",
      description: "Advanced practice nurse with prescriptive authority",
      category: "nursing",
      requires_license: true,
      can_prescribe: true,
      icon: "heart"
    },
    %{
      code: "clinical_officer",
      name: "Clinical Officer",
      description: "Mid-level healthcare provider trained in clinical medicine",
      category: "mid_level",
      requires_license: true,
      can_prescribe: true,
      icon: "clipboard-list"
    },
    %{
      code: "community_health_worker",
      name: "Community Health Worker",
      description: "Community-based healthcare provider focused on health promotion",
      category: "community",
      requires_license: false,
      can_prescribe: false,
      icon: "users"
    },
    %{
      code: "nutritionist",
      name: "Nutritionist",
      description: "Specialist in nutrition and dietary counseling for children",
      category: "allied_health",
      requires_license: true,
      can_prescribe: false,
      icon: "apple-alt"
    },
    %{
      code: "psychologist",
      name: "Child Psychologist",
      description: "Specialist in child mental health and development",
      category: "mental_health",
      requires_license: true,
      can_prescribe: false,
      icon: "brain"
    }
  ]

  @categories [
    %{code: "medical_doctor", name: "Medical Doctors", description: "Licensed physicians"},
    %{code: "nursing", name: "Nursing Professionals", description: "Registered nurses and nurse practitioners"},
    %{code: "mid_level", name: "Mid-level Providers", description: "Clinical officers and similar roles"},
    %{code: "community", name: "Community Health", description: "Community-based health workers"},
    %{code: "allied_health", name: "Allied Health", description: "Specialized health professionals"},
    %{code: "mental_health", name: "Mental Health", description: "Psychological and psychiatric professionals"}
  ]

  @doc """
  Returns all available specializations.
  """
  def all_specializations, do: @specializations

  @doc """
  Returns all specialization categories.
  """
  def all_categories, do: @categories

  @doc """
  Returns a list of specialization codes for validation.
  """
  def valid_codes do
    Enum.map(@specializations, & &1.code)
  end

  @doc """
  Returns specializations grouped by category.
  """
  def grouped_by_category do
    Enum.group_by(@specializations, & &1.category)
  end

  @doc """
  Returns a specific specialization by code.
  """
  def get_by_code(code) do
    Enum.find(@specializations, &(&1.code == code))
  end

  @doc """
  Returns the display name for a specialization code.
  """
  def display_name(code) do
    case get_by_code(code) do
      %{name: name} -> name
      nil -> String.replace(code || "", "_", " ") |> String.capitalize()
    end
  end

  @doc """
  Returns the description for a specialization code.
  """
  def description(code) do
    case get_by_code(code) do
      %{description: desc} -> desc
      nil -> nil
    end
  end

  @doc """
  Returns specializations that can prescribe medications.
  """
  def prescribing_specializations do
    Enum.filter(@specializations, & &1.can_prescribe)
  end

  @doc """
  Returns specializations that require licensing.
  """
  def licensed_specializations do
    Enum.filter(@specializations, & &1.requires_license)
  end

  @doc """
  Returns specializations for a specific category.
  """
  def by_category(category_code) do
    Enum.filter(@specializations, &(&1.category == category_code))
  end

  @doc """
  Returns options for HTML select elements.
  Format: [{display_name, code}, ...]
  """
  def select_options do
    @specializations
    |> Enum.map(&{&1.name, &1.code})
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc """
  Returns options grouped by category for HTML select elements.
  Format: %{category_name => [{display_name, code}, ...]}
  """
  def grouped_select_options do
    @specializations
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category_code, specializations} ->
      category = Enum.find(@categories, &(&1.code == category_code))
      category_name = if category, do: category.name, else: String.capitalize(category_code)

      options = specializations
                |> Enum.map(&{&1.name, &1.code})
                |> Enum.sort_by(&elem(&1, 0))

      {category_name, options}
    end)
    |> Enum.sort_by(&elem(&1, 0))
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
  def icon(code) do
    case get_by_code(code) do
      %{icon: icon} -> icon
      nil -> "user-md"
    end
  end

  @doc """
  Returns specializations that are most common in pediatric care.
  """
  def pediatric_focused do
    ["pediatrician", "nurse", "clinical_officer", "community_health_worker"]
    |> Enum.map(&get_by_code/1)
    |> Enum.filter(& &1)
  end

  @doc """
  Returns specializations suitable for primary care.
  """
  def primary_care do
    ["pediatrician", "general_practitioner", "nurse_practitioner", "clinical_officer"]
    |> Enum.map(&get_by_code/1)
    |> Enum.filter(& &1)
  end
end