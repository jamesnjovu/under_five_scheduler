defmodule AppWeb.Auth.Navigation do
  @moduledoc false
  use AppWeb, :live_view

  on_mount({AppWeb.UserAuth, :mount_current_user})
  on_mount({AppWeb.UserAuth, :ensure_authenticated})

  def nav_class, do: "block px-4 py-2 hover:bg-indigo-700 flex items-center space-x-2"

  def active_class,
    do: "block px-4 py-2 bg-indigo-900 border-l-4 border-white flex items-center space-x-2"

  @impl true
  def render(assigns) do
    ~H"""
    <nav phx-hook="ActiveNav" id={"activeNav#{:os.system_time}"}>
      <.link
        navigate={
          case @current_user.role do
            "admin" -> ~p"/admin/dashboard"
            "provider" -> ~p"/provider/dashboard"
            _a -> ~p"/dashboard"
          end
        }
        class={
          if @current_url in [
               ~p"/admin/dashboard",
               ~p"/provider/dashboard",
               ~p"/dashboard"
             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <rect x="3" y="3" width="7" height="9" />
          <rect x="14" y="3" width="7" height="5" />
          <rect x="14" y="12" width="7" height="9" />
          <rect x="3" y="16" width="7" height="5" />
        </svg>
        <span>Dashboard</span>
      </.link>
      <.link
        :if={@current_user.role == "provider"}
        navigate={~p"/provider/health_dashboard"}
        class={
          if @current_url in [
               ~p"/provider/health_dashboard"
             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <rect x="3" y="3" width="7" height="9" />
          <rect x="14" y="3" width="7" height="5" />
          <rect x="14" y="12" width="7" height="9" />
          <rect x="3" y="16" width="7" height="5" />
        </svg>
        <span>Health Dashboard</span>
      </.link>

      <.link
        :if={@current_user.role == "admin"}
        navigate={~p"/admin/providers"}
        class={
          if @current_url in [
               ~p"/admin/providers"
             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
          <circle cx="9" cy="7" r="4"></circle>
          <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
          <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
        </svg>
        <span>Providers</span>
      </.link>

      <.link
        :if={@current_user.role == "parent"}
        navigate={~p"/children"}
        class={
          if @current_url in [
               ~p"/children"
             ],
             do: active_class(),
             else: nav_class()
        }
      >
      <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M12 4.354a4 4 0 1 1 0 5.292M15 21H3v-1a6 6 0 0 1 12 0v1zm0 0h6v-1a6 6 0 0 0-9-5.197L15 21z" />
        </svg>
        <span>My Children</span>
      </.link>
    <.link
    :if={@current_user.role == "admin"}
    navigate={~p"/admin/vaccine_schedules"}
    class={
    if @current_url in [
         ~p"/admin/vaccine_schedules"
       ],
       do: active_class(),
       else: nav_class()
    }
    >
    <svg
    xmlns="http://www.w3.org/2000/svg"
    class="h-5 w-5"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="2"
    >
    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    <span>Vaccine Schedules</span>
    </.link>

<.link
    :if={@current_user.role == "admin"}
    navigate={~p"/admin/specializations"}
    class={
    if @current_url in [
         ~p"/admin/specializations"
       ],
       do: active_class(),
       else: nav_class()
    }
    >
    <svg
    xmlns="http://www.w3.org/2000/svg"
    class="h-5 w-5"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="2"
    >
    <path stroke-linecap="round" stroke-linejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
    </svg>
    <span>Specializations</span>
    </.link>
      <.link
        :if={@current_user.role == "admin"}
        navigate={~p"/admin/parents"}
        class={
          if @current_url in [
               ~p"/admin/parents"
             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
          <circle cx="12" cy="7" r="4"></circle>
        </svg>
        <span>Parents</span>
      </.link>

      <.link
        :if={@current_user.role in ["admin", "provider","parent"]}
        navigate={
          case @current_user.role do
            "admin" -> ~p"/admin/appointments"
            "parent" -> ~p"/appointments"
            "provider" -> ~p"/provider/appointments"
            _a -> ~p"/"
          end
        }
        class={
          if @current_url in [
               ~p"/admin/appointments",
               ~p"/appointments",
               ~p"/provider/appointments",

             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
          <line x1="16" y1="2" x2="16" y2="6"></line>
          <line x1="8" y1="2" x2="8" y2="6"></line>
          <line x1="3" y1="10" x2="21" y2="10"></line>
        </svg>
        <span>Appointments</span>
      </.link>

      <.link
        :if={@current_user.role == "provider"}
        navigate={~p"/provider/schedule"}
        class={
          if @current_url in [
               ~p"/provider/schedule"
             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
          <circle cx="9" cy="7" r="4"></circle>
          <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
          <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
        </svg>
        <span>My Schedule</span>
      </.link>

      <.link
        :if={@current_user.role == "provider"}
        navigate={~p"/provider/patients"}
        class={
          if @current_url in [
               ~p"/provider/patients"
             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
          <circle cx="9" cy="7" r="4"></circle>
          <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
          <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
        </svg>
        <span>Patients</span>
      </.link>

      <.link
        :if={@current_user.role in ["admin", "provider"]}
        navigate={
          case @current_user.role do
            "admin" -> ~p"/admin/reports"
            "provider" -> ~p"/provider/reports"
            _a -> ~p"/dashboard"
          end
        }
        class={
          if @current_url in [
               ~p"/admin/reports",
               ~p"/provider/reports",
             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M12 20V10"></path>
          <path d="M18 14l-6-6-6 6"></path>
        </svg>
        <span>Reports</span>
      </.link>

      <.link
        :if={@current_user.role in ["admin", "provider", "parent"]}
        navigate={
          case @current_user.role do
            "admin" -> ~p"/admin/settings"
            "provider" -> ~p"/provider/settings"
            "parent" -> ~p"/users/settings"
            _a -> ~p"/"
          end
        }
        class={
          if @current_url in [
               ~p"/admin/settings",
               ~p"/provider/settings",
               ~p"/user/settings",
             ],
             do: active_class(),
             else: nav_class()
        }
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <circle cx="12" cy="12" r="3"></circle>
          <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z">
          </path>
        </svg>
        <span>Settings</span>
      </.link>

      <div class="mt-8 border-t border-indigo-700"></div>

      <.link navigate={~p"/users/log_out"} class={nav_class()}>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
          <polyline points="16 17 21 12 16 7"></polyline>
          <line x1="21" y1="12" x2="9" y2="12"></line>
        </svg>
        <span>Logout</span>
      </.link>
    </nav>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:current_url, "/")
    |> ok()
  end

  @impl true
  def handle_event("change_nav", params, socket) do
    assign(socket, current_url: params["url"])
    |> noreply()
  end
end
