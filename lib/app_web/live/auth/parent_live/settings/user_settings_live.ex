defmodule AppWeb.UserSettingsLive do
  use AppWeb, :live_view

  alias App.Accounts

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if user && Accounts.is_parent?(user) do
      user = socket.assigns.current_user

      # Fetch user's notification preferences
      notification_preference = App.Notifications.get_user_preference(user.id)

      email_changeset = Accounts.change_user_email(user)
      password_changeset = Accounts.change_user_password(user)
      notification_changeset = App.Notifications.change_notification_preference(notification_preference)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "Parent Settings")
        |> assign(:active_tab, "profile")
        |> assign(:current_password, nil)
        |> assign(:email_form_current_password, nil)
        |> assign(:current_email, user.email)
        |> assign(:email_form, to_form(email_changeset))
        |> assign(:password_form, to_form(password_changeset))
        |> assign(:notification_form, to_form(notification_changeset))
        |> assign(:trigger_submit, false)
        |> assign(:show_sidebar, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be a parent to access this page.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("update_notification_preferences", %{"notification_preference" => params}, socket) do
    user = socket.assigns.current_user

    # Fetch the user's notification preference
    notification_preference = App.Notifications.get_user_preference(user.id)

    # Update notification preferences
    case App.Notifications.update_notification_preference(notification_preference, params) do
      {:ok, _preference} ->
        {:noreply,
          socket
          |> put_flash(:info, "Notification preferences updated successfully.")
          |> push_navigate(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, notification_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  @impl true
  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  @impl true
  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  @impl true
  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    Accounts.get_user_by_session_token(token)
  end
end
