defmodule AppWeb.SpecializationHelpers do
  @moduledoc """
  Helper functions for working with specializations in templates.
  """

  alias App.Config.Specializations
  use Phoenix.Component

  @doc """
  Returns the display name for a specialization code.
  """
  def specialization_name(code) do
    Specializations.display_name(code)
  end

  @doc """
  Returns the description for a specialization code.
  """
  def specialization_description(code) do
    Specializations.description(code)
  end

  @doc """
  Returns a specialization badge component.
  """
  def specialization_badge(assigns) do
    specialization = case assigns.code do
      code when is_binary(code) -> Specializations.get_specialization_by_code(code)
      %{} = spec -> spec
      _ -> nil
    end

    assigns = assign(assigns, :specialization, specialization)

    ~H"""
    <%= if @specialization do %>
      <div class="flex flex-wrap gap-1">
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
          {@specialization.name}
        </span>

        <%= if @specialization.can_prescribe do %>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd" />
            </svg>
            Prescribes
          </span>
        <% end %>

        <%= if @specialization.requires_license do %>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
            Licensed
          </span>
        <% end %>
      </div>
    <% else %>
      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
        Unknown Specialization
      </span>
    <% end %>
    """
  end

  @doc """
  Returns category badge styling based on category code.
  """
  def category_badge_class(category_code) do
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

  @doc """
  Returns icon HTML for a specialization.
  """
  def specialization_icon(code, opts \\ []) do
    icon_name = Specializations.icon(code)
    class = Keyword.get(opts, :class, "h-5 w-5")

    case icon_name do
      "stethoscope" ->
        ~s(<svg class="#{
          class
        }" fill="currentColor" viewBox="0 0 20 20"><path d="M2 6a2 2 0 012-2h5l2 2h5a2 2 0 012 2v6a2 2 0 01-2 2H4a2 2 0 01-2-2V6z"/></svg>)
      "heart" ->
        ~s(<svg class="#{
          class
        }" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/></svg>)
      "clipboard-list" ->
        ~s(<svg class="#{
          class
        }" fill="currentColor" viewBox="0 0 20 20"><path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z"/><path fill-rule="evenodd" d="M4 5a2 2 0 012-2v1a2 2 0 002 2h4a2 2 0 002-2V3a2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm3 4a1 1 0 000 2h.01a1 1 0 100-2H7zm3 0a1 1 0 000 2h3a1 1 0 100-2h-3zm-3 4a1 1 0 100 2h.01a1 1 0 100-2H7zm3 0a1 1 0 100 2h3a1 1 0 100-2h-3z" clip-rule="evenodd"/></svg>)
      "users" ->
        ~s(<svg class="#{
          class
        }" fill="currentColor" viewBox="0 0 20 20"><path d="M9 6a3 3 0 11-6 0 3 3 0 016 0zM17 6a3 3 0 11-6 0 3 3 0 016 0zM12.93 17c.046-.327.07-.66.07-1a6.97 6.97 0 00-1.5-4.33A5 5 0 0119 16v1h-6.07zM6 11a5 5 0 015 5v1H1v-1a5 5 0 015-5z"/></svg>)
      "medical-bag" ->
        ~s(<svg class="#{
          class
        }" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M8 2a2 2 0 00-2 2v1.5h8V4a2 2 0 00-2-2H8zM6 7v8a2 2 0 002 2h4a2 2 0 002-2V7H6zm3 1a1 1 0 011 1v2h2a1 1 0 110 2h-2v2a1 1 0 11-2 0v-2H6a1 1 0 110-2h2V9a1 1 0 011-1z" clip-rule="evenodd"/></svg>)
      "apple-alt" ->
        ~s(<svg class="#{
          class
        }" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 2a6 6 0 00-6 6c0 1.887-.454 3.665-1.257 5.234a.75.75 0 00.515 1.076 32.94 32.94 0 003.256.508 3.5 3.5 0 006.972 0 32.933 32.933 0 003.256-.508.75.75 0 00.515-1.076A11.448 11.448 0 0016 8a6 6 0 00-6-6zm0 14.5a2 2 0 11-4 0 2 2 0 014 0z" clip-rule="evenodd"/></svg>)
      "brain" ->
        ~s(<svg class="#{
          class
        }" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" clip-rule="evenodd"/></svg>)
      _ ->
        ~s(<svg class="#{
          class
        }" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd"/></svg>)
    end
    |> Phoenix.HTML.raw()
  end

  @doc """
  Formats a specialization for display with category information.
  """
  def format_specialization_with_category(specialization, categories \\ []) do
    category_name = case specialization do
      %{
        category: %{
          name: name
        }
      } -> name
      %{category_id: category_id} when is_list(categories) ->
        case Enum.find(categories, &(&1.id == category_id)) do
          %{name: name} -> name
          _ -> "Unknown Category"
        end
      _ -> "Unknown Category"
    end

    "#{specialization.name} (#{category_name})"
  end

  @doc """
  Returns capabilities list for a specialization.
  """
  def specialization_capabilities(specialization) do
    capabilities = []

    capabilities = if specialization.can_prescribe do
      capabilities ++ ["Can Prescribe Medications"]
    else
      capabilities
    end

    capabilities = if specialization.requires_license do
      capabilities ++ ["Requires Professional License"]
    else
      capabilities
    end

    case capabilities do
      [] -> ["General Healthcare Provider"]
      caps -> caps
    end
  end

  @doc """
  Checks if a specialization is suitable for pediatric care.
  """
  def pediatric_suitable?(specialization) do
    pediatric_codes = ["pediatrician", "nurse", "clinical_officer", "community_health_worker", "general_practitioner"]
    specialization.code in pediatric_codes
  end

  @doc """
  Returns a short description for a specialization category.
  """
  def category_description(category_code) do
    case category_code do
      "medical_doctor" -> "Licensed physicians with medical degrees"
      "nursing" -> "Registered nurses and nurse practitioners"
      "mid_level" -> "Clinical officers and mid-level practitioners"
      "community" -> "Community-based health workers"
      "allied_health" -> "Specialized health professionals"
      "mental_health" -> "Mental health and psychology professionals"
      _ -> "Healthcare professionals"
    end
  end
end