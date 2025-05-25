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
    specialization = Specializations.get_by_code(assigns.code)

    assigns = assign(assigns, :specialization, specialization)

    ~H"""
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
        ~s(<svg class="#{class}" fill="currentColor" viewBox="0 0 20 20"><path d="M2 6a2 2 0 012-2h5l2 2h5a2 2 0 012 2v6a2 2 0 01-2 2H4a2 2 0 01-2-2V6z"/></svg>)
      "heart" ->
        ~s(<svg class="#{class}" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/></svg>)
      "clipboard-list" ->
        ~s(<svg class="#{class}" fill="currentColor" viewBox="0 0 20 20"><path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z"/><path fill-rule="evenodd" d="M4 5a2 2 0 012-2v1a2 2 0 002 2h4a2 2 0 002-2V3a2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm3 4a1 1 0 000 2h.01a1 1 0 100-2H7zm3 0a1 1 0 000 2h3a1 1 0 100-2h-3zm-3 4a1 1 0 100 2h.01a1 1 0 100-2H7zm3 0a1 1 0 100 2h3a1 1 0 100-2h-3z" clip-rule="evenodd"/></svg>)
      "users" ->
        ~s(<svg class="#{class}" fill="currentColor" viewBox="0 0 20 20"><path d="M9 6a3 3 0 11-6 0 3 3 0 016 0zM17 6a3 3 0 11-6 0 3 3 0 016 0zM12.93 17c.046-.327.07-.66.07-1a6.97 6.97 0 00-1.5-4.33A5 5 0 0119 16v1h-6.07zM6 11a5 5 0 015 5v1H1v-1a5 5 0 015-5z"/></svg>)
      _ ->
        ~s(<svg class="#{class}" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd"/></svg>)
    end
    |> Phoenix.HTML.raw()
  end
end