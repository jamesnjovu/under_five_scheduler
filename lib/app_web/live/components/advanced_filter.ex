defmodule AppWeb.Components.AdvancedFilter do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg mb-6 p-4">
      <div class="flex flex-col space-y-4">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-medium text-gray-900">Advanced Filters</h3>
          <button
            type="button"
            phx-click="reset_filters"
            class="text-sm text-indigo-600 hover:text-indigo-900"
          >
            Reset Filters
          </button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Date Range</label>
            <div class="mt-1 flex space-x-2">
              <input
                type="date"
                name="start_date"
                value={@filters.start_date}
                phx-change="filter_change"
                class="block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              />
              <input
                type="date"
                name="end_date"
                value={@filters.end_date}
                phx-change="filter_change"
                class="block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              />
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Status</label>
            <div class="mt-1">
              <select
                name="status"
                phx-change="filter_change"
                class="block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              >
                <option value="">All Statuses</option>
                <%= for status <- @statuses do %>
                  <option value={status} selected={@filters.status == status}>
                    {String.capitalize(status)}
                  </option>
                <% end %>
              </select>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Provider</label>
            <div class="mt-1">
              <select
                name="provider_id"
                phx-change="filter_change"
                class="block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              >
                <option value="">All Providers</option>
                <%= for provider <- @providers do %>
                  <option value={provider.id} selected={@filters.provider_id == provider.id}>
                    {provider.name}
                  </option>
                <% end %>
              </select>
            </div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700">Search</label>
          <div class="mt-1 relative rounded-md shadow-sm">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg
                class="h-5 w-5 text-gray-400"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <input
              type="text"
              name="search"
              value={@filters.search}
              phx-change="filter_change"
              phx-debounce="300"
              class="focus:ring-indigo-500 focus:border-indigo-500 block w-full pl-10 sm:text-sm border-gray-300 rounded-md"
              placeholder="Search by name, ID, or notes"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
