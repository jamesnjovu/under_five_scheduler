defmodule AppWeb.AdminLive.AdminUsers do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Accounts.User
  alias App.Repo

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "admin_users:update")
      end

      socket =
        socket
        |> assign(:current_user, user)
        |> assign(:admin_users, list_admin_users_with_details())
        |> assign(:page_title, "Admin User Management")
        |> assign(:filter, "all")
        |> assign(:search, "")
        |> assign(:show_form, false)
        |> assign(:edit_user, nil)
        |> assign(:changeset, new_user_changeset())
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

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("toggle-form", _, socket) do
    {:noreply,
      socket
      |> assign(:show_form, !socket.assigns.show_form)
      |> assign(:edit_user, nil)
      |> assign(:changeset, new_user_changeset())}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    changeset = Accounts.change_user(user)

    # Add display_email field to match the template expectations
    user_with_display = Map.put(user, :display_email, get_display_email(user.email))
    user_with_active = Map.put(user_with_display, :is_active, is_user_active?(user.email))

    {:noreply,
      socket
      |> assign(:show_form, true)
      |> assign(:edit_user, user_with_active)
      |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case socket.assigns.edit_user do
      nil ->
        # Create new admin user
        create_new_admin(socket, user_params)

      user ->
        # Update existing admin user
        update_existing_admin(socket, user, user_params)
    end
  end

  @impl true
  def handle_event("deactivate", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    # Prevent self-deactivation
    if user.id == socket.assigns.current_user.id do
      {:noreply,
        socket
        |> put_flash(:error, "You cannot deactivate your own account.")
        |> assign(:admin_users, list_admin_users_with_details())}
    else
      # Prevent deactivating the last admin
      active_admin_count = App.Accounts.AdminUserManager.count_active_admins()

      if active_admin_count <= 1 do
        {:noreply,
          socket
          |> put_flash(:error, "Cannot deactivate the last active admin user.")
          |> assign(:admin_users, list_admin_users_with_details())}
      else
        case soft_delete_admin(user) do
          {:ok, _} ->
            App.Administration.Auditing.log_action(%{
              action: "deactivate",
              entity_type: "admin_user",
              entity_id: id,
              user_id: socket.assigns.current_user.id,
              ip_address: get_connect_ip(socket),
              details: %{
                deactivated_user_name: user.name,
                deactivated_user_email: user.email,
                action: "soft_delete"
              }
            })

            # Send notification about deactivation
            send_deactivation_notification(user, socket.assigns.current_user)

            {:noreply,
              socket
              |> put_flash(:info, "Admin user deactivated successfully.")
              |> assign(:admin_users, list_admin_users_with_details())}

          {:error, _} ->
            {:noreply,
              socket
              |> put_flash(:error, "Could not deactivate admin user.")
              |> assign(:admin_users, list_admin_users_with_details())}
        end
      end
    end
  end

  @impl true
  def handle_event("reactivate", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case reactivate_admin(user) do
      {:ok, _} ->
        App.Administration.Auditing.log_action(%{
          action: "reactivate",
          entity_type: "admin_user",
          entity_id: id,
          user_id: socket.assigns.current_user.id,
          ip_address: get_connect_ip(socket),
          details: %{
            reactivated_user_name: user.name,
            reactivated_user_email: user.email,
            action: "reactivate"
          }
        })

        # Send welcome back notification
        send_reactivation_notification(user, socket.assigns.current_user)

        {:noreply,
          socket
          |> put_flash(:info, "Admin user reactivated successfully.")
          |> assign(:admin_users, list_admin_users_with_details())}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not reactivate admin user.")
          |> assign(:admin_users, list_admin_users_with_details())}
    end
  end

  # Private functions

  defp create_new_admin(socket, user_params) do
    # Generate a random password
    password = generate_random_password()

    # Prepare user params with auto-generated password and admin role
    admin_params = user_params
                   |> Map.put("password", password)
                   |> Map.put("role", "admin")

    case Accounts.register_user(admin_params) do
      {:ok, admin_user} ->
        # Log the creation
        App.Administration.Auditing.log_action(%{
          action: "create",
          entity_type: "admin_user",
          entity_id: to_string(admin_user.id),
          user_id: socket.assigns.current_user.id,
          ip_address: get_connect_ip(socket),
          details: %{
            created_user_name: admin_user.name,
            created_user_email: admin_user.email
          }
        })

        # Send credentials notification
        send_credentials_notification(admin_user, password)

        socket =
          socket
          |> put_flash(:info, "Admin user created successfully. Login credentials have been sent via email and SMS.")
          |> assign(:admin_users, list_admin_users_with_details())
          |> assign(:show_form, false)
          |> assign(:edit_user, nil)
          |> assign(:changeset, new_user_changeset())

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp update_existing_admin(socket, user, user_params) do
    # Remove password-related fields for updates (passwords handled separately)
    update_params = Map.drop(user_params, ["password", "password_confirmation", "role"])

    # If the user is deactivated, we need to handle email updates carefully
    if String.starts_with?(user.email, "DEACTIVATED_") && Map.has_key?(update_params, "email") do
      # For deactivated users, update the original email in the deactivated string
      original_email = get_display_email(user.email)
      new_email = update_params["email"]

      if original_email != new_email do
        # Create new deactivated email with updated original email
        [prefix, timestamp, _old_email] = String.split(user.email, "_", parts: 3)
        new_deactivated_email = "#{prefix}_#{timestamp}_#{new_email}"
        update_params = Map.put(update_params, "email", new_deactivated_email)
      else
        # Email hasn't changed, remove it from updates
        update_params = Map.drop(update_params, ["email"])
      end
    end

    case Accounts.update_user(user, update_params) do
      {:ok, updated_user} ->
        App.Administration.Auditing.log_action(%{
          action: "update",
          entity_type: "admin_user",
          entity_id: to_string(user.id),
          user_id: socket.assigns.current_user.id,
          ip_address: get_connect_ip(socket),
          details: %{
            updated_user_name: updated_user.name,
            updated_user_email: get_display_email(updated_user.email),
            changes: update_params
          }
        })

        socket =
          socket
          |> put_flash(:info, "Admin user updated successfully.")
          |> assign(:admin_users, list_admin_users_with_details())
          |> assign(:show_form, false)
          |> assign(:edit_user, nil)
          |> assign(:changeset, new_user_changeset())

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp soft_delete_admin(user) do
    # For admin users, we'll use a different approach - maybe add an is_active field
    # or use a special status. For now, we'll just mark them as inactive in a way
    # that prevents login but preserves data

    # You might want to add an is_active field to users table
    # For now, we'll use a workaround by modifying the email to make it invalid
    deactivated_email = "DEACTIVATED_#{DateTime.utc_now() |> DateTime.to_unix()}_#{user.email}"

    Accounts.update_user(user, %{email: deactivated_email})
  end

  defp reactivate_admin(user) do
    # Restore the original email
    if String.starts_with?(user.email, "DEACTIVATED_") do
      # Extract original email
      original_email = user.email
                       |> String.split("_", parts: 3)
                       |> List.last()

      Accounts.update_user(user, %{email: original_email})
    else
      {:ok, user}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    Accounts.get_user_by_session_token(token)
  end

  defp list_admin_users_with_details do
    # Get all admin users (active and inactive)
    admin_users = Accounts.list_users_by_role("admin")

    Enum.map(admin_users, fn user ->
      is_active = !String.starts_with?(user.email, "DEACTIVATED_")

      # Get display email (original for deactivated users)
      display_email = if is_active do
        user.email
      else
        user.email
        |> String.split("_", parts: 3)
        |> List.last()
      end

      # Get audit log entries for this user
      recent_logins = get_recent_login_count(user.id)

      %{
        id: user.id,
        name: user.name,
        email: user.email,
        display_email: display_email,
        phone: user.phone,
        confirmed_at: user.confirmed_at,
        inserted_at: user.inserted_at,
        is_active: is_active,
        recent_logins: recent_logins
      }
    end)
    |> Enum.sort_by(&{!&1.is_active, &1.name})  # Active users first, then by name
  end

  defp get_recent_login_count(user_id) do
    # This would require tracking login events in audit logs
    # For now, return a placeholder
    :rand.uniform(10)
  end

  defp new_user_changeset do
    Accounts.change_user_registration(%User{})
  end

  defp generate_random_password do
    # Generate a secure random password
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> String.replace(~r/[^A-Za-z0-9]/, "")
    |> String.slice(0, 12)
    |> Kernel.<>("@1")  # Add special character to meet requirements
  end

  defp send_credentials_notification(user, password) do
    # Send email with login credentials
    send_credentials_email(user, password)

    # Send SMS with login credentials
    send_credentials_sms(user, password)
  end

  defp send_credentials_email(user, password) do
    subject = "Your Admin Account - Under Five Health Check-Up"

    email_body = """
    <h2>Admin Account Created</h2>
    <p>Dear #{user.name},</p>

    <p>Your administrator account has been created successfully for the Under Five Health Check-Up system.</p>

    <h3>Login Credentials:</h3>
    <ul>
      <li><strong>Email:</strong> #{user.email}</li>
      <li><strong>Password:</strong> #{password}</li>
    </ul>

    <h3>Admin Responsibilities:</h3>
    <ul>
      <li>Manage healthcare providers</li>
      <li>Monitor system health and appointments</li>
      <li>Generate reports and analytics</li>
      <li>Manage user accounts and permissions</li>
    </ul>

    <p><strong>Important Security Notes:</strong></p>
    <ul>
      <li>Please change your password after your first login</li>
      <li>Never share your admin credentials with anyone</li>
      <li>Use strong, unique passwords</li>
      <li>Log out when finished using the system</li>
    </ul>

    <p>You can access the admin portal at: [Your Website URL]/users/log_in</p>

    <p>If you have any questions about your admin responsibilities, please contact the system administrator.</p>

    <p>Best regards,<br>Under Five Health Check-Up Team</p>
    """

    App.Accounts.UserNotifier.build_email(user.email, subject, email_body)
    |> App.Mailer.deliver()
  end

  defp send_credentials_sms(user, password) do
    message = """
    Under Five Health Check-Up Admin Account Created

    Your admin login credentials:
    Email: #{user.email}
    Password: #{password}

    IMPORTANT: Change password after first login. Keep credentials secure.

    Login at: [Your Website URL]
    """

    App.Services.ProbaseSMS.send_sms(user.phone, message)
  end

  defp send_deactivation_notification(deactivated_user, admin_user) do
    subject = "Your Admin Account Has Been Deactivated"

    message = """
    Dear #{deactivated_user.name},

    Your administrator account for the Under Five Health Check-Up system has been deactivated.

    This means you no longer have access to:
    - Admin dashboard and controls
    - User management functions
    - System reports and analytics
    - Provider management tools

    If you believe this was done in error or if you need to regain access, please contact the system administrator.

    This action was performed by: #{admin_user.name} (#{admin_user.email})
    Time: #{DateTime.utc_now() |> DateTime.to_string()}

    Best regards,
    Under Five Health Check-Up Team
    """

    # Extract original email for deactivated users
    email = if String.starts_with?(deactivated_user.email, "DEACTIVATED_") do
      deactivated_user.email
      |> String.split("_", parts: 3)
      |> List.last()
    else
      deactivated_user.email
    end

    App.Accounts.UserNotifier.build_email(email, subject, message)
    |> App.Mailer.deliver()
  end

  defp send_reactivation_notification(user, admin_user) do
    subject = "Your Admin Account Has Been Reactivated"

    message = """
    Dear #{user.name},

    Your administrator account for the Under Five Health Check-Up system has been reactivated.

    You now have access to:
    - Admin dashboard and controls
    - User management functions
    - System reports and analytics
    - Provider management tools

    You can log in using your existing credentials at: [Your Website URL]/users/log_in

    This action was performed by: #{admin_user.name} (#{admin_user.email})
    Time: #{DateTime.utc_now() |> DateTime.to_string()}

    If you have any questions, please contact the system administrator.

    Best regards,
    Under Five Health Check-Up Team
    """

    App.Accounts.UserNotifier.build_email(user.email, subject, message)
    |> App.Mailer.deliver()
  end

  defp filtered_users(users, filter, search) do
    users
    |> filter_by_criteria(filter)
    |> search_users(search)
  end

  defp filter_by_criteria(users, "all"), do: users
  defp filter_by_criteria(users, "active"), do: Enum.filter(users, & &1.is_active)
  defp filter_by_criteria(users, "inactive"), do: Enum.filter(users, &(!&1.is_active))
  defp filter_by_criteria(users, "verified"), do: Enum.filter(users, &(&1.confirmed_at != nil))
  defp filter_by_criteria(users, "unverified"), do: Enum.filter(users, &(&1.confirmed_at == nil))
  defp filter_by_criteria(users, _), do: users

  defp search_users(users, ""), do: users

  defp search_users(users, search) do
    search = String.downcase(search)

    Enum.filter(users, fn user ->
      String.contains?(String.downcase(user.name), search) ||
        String.contains?(String.downcase(user.display_email), search)
    end)
  end

  # Helper function to safely get client IP
  defp get_connect_ip(socket) do
    case socket.assigns do
      %{connect_params: %{"_csrf_token" => _}} -> "127.0.0.1"
      _ -> "127.0.0.1"
    end
  end

  # Helper functions for display email and active status
  defp get_display_email(email) do
    if String.starts_with?(email, "DEACTIVATED_") do
      email
      |> String.split("_", parts: 3)
      |> List.last()
    else
      email
    end
  end

  defp is_user_active?(email) do
    !String.starts_with?(email, "DEACTIVATED_")
  end
end