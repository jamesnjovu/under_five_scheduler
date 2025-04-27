defmodule AppWeb.AdminLive.Settings do
  use AppWeb, :live_view

  alias App.Accounts

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "Admin Settings")
        |> assign(:notification_settings, %{
          email_enabled: true,
          sms_enabled: true,
          reminder_hours: 24
        })
        |> assign(:appointment_settings, %{
          allow_reschedule_hours: 24,
          max_appointments_per_day: 10,
          appointment_duration_minutes: 30
        })
        |> assign(:ussd_settings, %{
          enabled: true,
          service_code: "*123#",
          provider: "Default"
        })
        |> assign(:active_tab, "notification")
        # For responsive sidebar toggle
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

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("update_notification_settings", %{"notification" => params}, socket) do
    # In a real app, this would update the database
    updated_settings = %{
      email_enabled: params["email_enabled"] == "true",
      sms_enabled: params["sms_enabled"] == "true",
      reminder_hours: String.to_integer(params["reminder_hours"] || "24")
    }

    {:noreply,
     socket
     |> put_flash(:info, "Notification settings updated successfully.")
     |> assign(:notification_settings, updated_settings)}
  end

  @impl true
  def handle_event("update_appointment_settings", %{"appointment" => params}, socket) do
    # In a real app, this would update the database
    updated_settings = %{
      allow_reschedule_hours: String.to_integer(params["allow_reschedule_hours"] || "24"),
      max_appointments_per_day: String.to_integer(params["max_appointments_per_day"] || "10"),
      appointment_duration_minutes:
        String.to_integer(params["appointment_duration_minutes"] || "30")
    }

    {:noreply,
     socket
     |> put_flash(:info, "Appointment settings updated successfully.")
     |> assign(:appointment_settings, updated_settings)}
  end

  @impl true
  def handle_event("update_ussd_settings", %{"ussd" => params}, socket) do
    # In a real app, this would update the database
    updated_settings = %{
      enabled: params["enabled"] == "true",
      service_code: params["service_code"] || "*123#",
      provider: params["provider"] || "Default"
    }

    {:noreply,
     socket
     |> put_flash(:info, "USSD settings updated successfully.")
     |> assign(:ussd_settings, updated_settings)}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end
end
