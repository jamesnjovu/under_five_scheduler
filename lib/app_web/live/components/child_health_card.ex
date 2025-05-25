defmodule AppWeb.Components.ChildHealthCard do
  use AppWeb, :live_component
  alias App.Accounts.Child

  attr :child, :any, required: true
  attr :class, :string, default: ""

  def child_health_card(assigns) do
    ~H"""
    <div class={"bg-white rounded-lg shadow-md p-6 #{@class}"}>
      <div class="flex items-start justify-between mb-4">
        <div>
          <h3 class="text-lg font-semibold text-gray-900">{@child.name}</h3>
          <p class="text-sm text-gray-600">{Child.formatted_age(@child)}</p>
          <p class="text-xs text-gray-500">MRN: {@child.medical_record_number}</p>
        </div>

        <div class="flex items-center space-x-2">
          <.health_status_badge child={@child} />
        </div>
      </div>

      <div class="space-y-4">
        <.next_checkup_info child={@child} />
        <.quick_health_stats child={@child} />
      </div>

      <div class="mt-6 flex space-x-3">
        <.link
          navigate={~p"/children/#{@child.id}"}
          class="flex-1 bg-indigo-600 text-white text-center py-2 px-4 rounded-md text-sm font-medium hover:bg-indigo-700"
        >
          View Details
        </.link>

        <.link
          navigate={~p"/appointments/new?child_id=#{@child.id}"}
          class="flex-1 bg-gray-100 text-gray-700 text-center py-2 px-4 rounded-md text-sm font-medium hover:bg-gray-200"
        >
          Book Appointment
        </.link>
      </div>
    </div>
    """
  end

  attr :child, :any, required: true

  def health_status_badge(assigns) do
    ~H"""
    <span class={
      "px-2 py-1 text-xs font-semibold rounded-full " <>
      case @child.status do
        "active" -> "bg-green-100 text-green-800"
        "grown" -> "bg-blue-100 text-blue-800"
        _ -> "bg-gray-100 text-gray-800"
      end
    }>
      {String.capitalize(@child.status)}
    </span>
    """
  end

  attr :child, :any, required: true

  def next_checkup_info(assigns) do
    checkup_info = Child.next_checkup_age(assigns.child)
    assigns = assign(assigns, :checkup_info, checkup_info)

    ~H"""
    <div class="bg-gray-50 rounded-lg p-4">
      <h4 class="text-sm font-medium text-gray-900 mb-2">Next Checkup</h4>

      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm text-gray-700">{@checkup_info.description}</p>
          <%= if @checkup_info.target_date do %>
            <p class="text-xs text-gray-500">
              Target: {Calendar.strftime(@checkup_info.target_date, "%b %d, %Y")}
            </p>
          <% end %>
        </div>

        <div class="text-right">
          <%= if @checkup_info.is_overdue do %>
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
              <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
              </svg>
              Overdue
            </span>
          <% else %>
            <span class={
              "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium " <>
              case @checkup_info.priority do
                "high" -> "bg-orange-100 text-orange-800"
                "medium" -> "bg-yellow-100 text-yellow-800"
                _ -> "bg-green-100 text-green-800"
              end
            }>
              <%= if @checkup_info.months_until == 0 do %>
                Due now
              <% else %>
                In {@checkup_info.months_until} month{if @checkup_info.months_until == 1, do: "", else: "s"}
              <% end %>
            </span>
          <% end %>
        </div>
      </div>

      <%= if length(@checkup_info.recommendations) > 0 do %>
        <details class="mt-3">
          <summary class="text-xs text-gray-600 cursor-pointer hover:text-gray-800">
            View recommended activities
          </summary>
          <ul class="mt-2 text-xs text-gray-600 space-y-1">
            <%= for recommendation <- Enum.take(@checkup_info.recommendations, 3) do %>
              <li class="flex items-center">
                <svg class="w-3 h-3 mr-1 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                </svg>
                {recommendation}
              </li>
            <% end %>
            <%= if length(@checkup_info.recommendations) > 3 do %>
              <li class="text-gray-500">
                +{length(@checkup_info.recommendations) - 3} more...
              </li>
            <% end %>
          </ul>
        </details>
      <% end %>
    </div>
    """
  end

  attr :child, :any, required: true

  def quick_health_stats(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4">
      <div class="text-center">
        <div class="text-lg font-semibold text-gray-900">
          {Child.age_in_months(@child)}
        </div>
        <div class="text-xs text-gray-500">Months old</div>
      </div>

      <div class="text-center">
        <div class="text-lg font-semibold text-gray-900">
          {Child.age_in_days(@child)}
        </div>
        <div class="text-xs text-gray-500">Days old</div>
      </div>
    </div>
    """
  end
end
