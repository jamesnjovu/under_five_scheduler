defmodule AppWeb.ProviderLive.Settings do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.Notifications.NotificationPreference

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    # Ensure the user is a provider
    if Accounts.is_provider?(user) do
      provider = Scheduling.get_provider_by_user_id(user.id)
      notification_preference = Accounts.get_notification_preference(user.id)

      # Create a default notification preference if none exists
      notification_preference =
        notification_preference ||
          %NotificationPreference{
            email_enabled: true,
            sms_enabled: true,
            reminder_hours: 24,
            user_id: user.id
          }

      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "user:#{user.id}")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:page_title, "Provider Settings")
        |> assign(:active_tab, "profile")
        |> assign(:notification_preference, notification_preference)
        |> assign(:show_sidebar, false)
        |> assign(:profile_form, to_form(Accounts.change_user(user)))
        |> assign(:provider_form, to_form(Scheduling.change_provider(provider)))
        |> assign(
          :notification_form,
          to_form(Accounts.change_notification_preference(notification_preference))
        )
        |> assign(
          :password_form,
          to_form(%{
            "email" => user.email,
            "current_password" => nil,
            "password" => nil,
            "password_confirmation" => nil
          })
        )
        |> assign(:current_password, nil)
        |> assign(:trigger_submit, false)

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
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("update_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.user

    case Accounts.update_user(user, user_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully.")
         |> assign(:user, updated_user)
         |> assign(:profile_form, to_form(Accounts.change_user(updated_user)))}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("update_provider_info", %{"provider" => provider_params}, socket) do
    provider = socket.assigns.provider

    case Scheduling.update_provider(provider, provider_params) do
      {:ok, updated_provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "Provider information updated successfully.")
         |> assign(:provider, updated_provider)
         |> assign(:provider_form, to_form(Scheduling.change_provider(updated_provider)))}

      {:error, changeset} ->
        {:noreply, assign(socket, :provider_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("update_notification_settings", %{"notification_preference" => params}, socket) do
    notification_preference = socket.assigns.notification_preference

    case Accounts.update_notification_preference(notification_preference, params) do
      {:ok, updated_preference} ->
        {:noreply,
         socket
         |> put_flash(:info, "Notification settings updated successfully.")
         |> assign(:notification_preference, updated_preference)
         |> assign(
           :notification_form,
           to_form(Accounts.change_notification_preference(updated_preference))
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, :notification_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  @impl true
  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Password updated successfully.")
         |> assign(trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end
end
