defmodule AppWeb.Components.SideNav do
  use Phoenix.Component

  def side_nav_res(assigns) do
    ~H"""
    <div class={
      "w-64 bg-indigo-800 text-white transform transition-transform duration-300 ease-in-out z-10 h-full md:translate-x-0 fixed md:static " <>
      if(assigns.show_sidebar, do: "translate-x-0", else: "-translate-x-full")
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

      <%= render_slot(@inner_block) %>

      <nav class="mt-8">
        <%= render_slot(@navigation) %>
      </nav>
    </div>
    """
  end
end