defmodule AppWeb.Components.SideNav do
  use Phoenix.Component

  attr :current_user, :any, default: %{role: nil}
  attr :show_sidebar, :boolean, default: false
  attr :render, :boolean, default: false
  attr :socket, :any, required: true
  slot :inner_block, required: false
  def side_nav_res(assigns) do
    ~H"""
    <!-- Mobile sidebar toggle -->
    <div class="fixed z-20 top-4 left-4 md:hidden">
      <button
        phx-click="toggle_sidebar"
        class="p-2 rounded-md bg-indigo-600 text-white shadow-md hover:bg-indigo-700 focus:outline-none"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-6 w-6"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 6h16M4 12h16M4 18h16"
          />
        </svg>
      </button>
    </div>

    <!-- Sidebar navigation - with responsive behavior -->
    <div class={
    "w-64 bg-indigo-800 text-white transform transition-transform duration-300 ease-in-out z-10 h-full md:translate-x-0 fixed md:static " <>
    if(@show_sidebar, do: "translate-x-0", else: "-translate-x-full")
    }>
      <!-- Close button shown only on mobile -->
      <div class="absolute right-2 top-2 md:hidden">
        <button phx-click="toggle_sidebar" class="text-white p-2 hover:bg-indigo-700 rounded">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>
      <div class="p-4">
        <div
          :if={@current_user.role == "provider"}
          class="text-center">
          <span class="text-xl font-bold text-white">Provider Portal</span>
          <div class="mt-2 text-sm text-indigo-200">
            <span>{@provider.name}</span>
          </div>
          <div class="mt-1 text-xs text-indigo-300 capitalize">
            {String.replace(@provider.specialization, "_", " ")}
          </div>
        </div>
      </div>
      {render_slot(@inner_block)}
      {live_render(@socket, AppWeb.Auth.Navigation, sticky: true, id: "Nav")}
    </div>
    """
  end
end