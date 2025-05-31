defmodule App.Accounts.AdminUserManager do
  @moduledoc """
  Handles admin user management with enhanced security and audit logging.
  """

  alias App.Accounts
  alias App.Administration.Auditing
  alias App.Repo
  import Ecto.Query

  @doc """
  Safely creates a new admin user with proper validation and notifications.
  """
  def create_admin_user(attrs, creator_user) do
    # Ensure role is set to admin
    admin_attrs = Map.put(attrs, "role", "admin")

    case Accounts.register_user(admin_attrs) do
      {:ok, admin_user} ->
        # Log the creation
        log_admin_action(creator_user, "create", admin_user, %{
          created_user_email: admin_user.email,
          created_user_name: admin_user.name
        })

        # Send welcome notification
        send_admin_welcome_notification(admin_user, attrs["password"])

        {:ok, admin_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates an admin user's information (excluding sensitive fields).
  """
  def update_admin_user(admin_user, attrs, updater_user) do
    # Only allow updating safe fields
    safe_attrs = Map.take(attrs, ["name", "email", "phone"])

    case Accounts.update_user(admin_user, safe_attrs) do
      {:ok, updated_user} ->
        # Log the update
        log_admin_action(updater_user, "update", updated_user, %{
          updated_fields: Map.keys(safe_attrs),
          changes: safe_attrs
        })

        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Safely deactivates an admin user with proper validation.
  """
  def deactivate_admin_user(admin_user, deactivator_user) do
    with {:ok, :can_deactivate} <- validate_can_deactivate(admin_user, deactivator_user),
         {:ok, deactivated_user} <- perform_deactivation(admin_user) do

      # Log the deactivation
      log_admin_action(deactivator_user, "deactivate", deactivated_user, %{
        deactivated_user_email: get_original_email(admin_user.email),
        reason: "administrative_action"
      })

      # Send notification
      send_deactivation_notification(deactivated_user, deactivator_user)

      {:ok, deactivated_user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Reactivates a previously deactivated admin user.
  """
  def reactivate_admin_user(admin_user, reactivator_user) do
    with {:ok, reactivated_user} <- perform_reactivation(admin_user) do
      # Log the reactivation
      log_admin_action(reactivator_user, "reactivate", reactivated_user, %{
        reactivated_user_email: reactivated_user.email,
        reactivated_user_name: reactivated_user.name
      })

      # Send welcome back notification
      send_reactivation_notification(reactivated_user, reactivator_user)

      {:ok, reactivated_user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all admin users with their activity status.
  """
  def list_admin_users_with_activity do
    admin_users = Accounts.list_users_by_role("admin")

    Enum.map(admin_users, fn user ->
      is_active = !String.starts_with?(user.email, "DEACTIVATED_")

      %{
        user: user,
        is_active: is_active,
        display_email: get_original_email(user.email),
        recent_activity: get_recent_admin_activity(user.id),
        login_sessions: count_recent_login_sessions(user.id)
      }
    end)
  end

  @doc """
  Gets comprehensive admin user statistics.
  """
  def get_admin_user_statistics do
    all_admins = Accounts.list_users_by_role("admin")
    active_admins = Enum.filter(all_admins, &(!String.starts_with?(&1.email, "DEACTIVATED_")))
    inactive_admins = all_admins -- active_admins

    verified_admins = Enum.filter(active_admins, &(&1.confirmed_at != nil))
    unverified_admins = active_admins -- verified_admins

    %{
      total: length(all_admins),
      active: length(active_admins),
      inactive: length(inactive_admins),
      verified: length(verified_admins),
      unverified: length(unverified_admins),
      created_this_month: count_admins_created_this_month(),
      last_admin_created: get_last_admin_creation_date()
    }
  end

  @doc """
  Validates admin user management operations.
  """
  def validate_admin_operation(operation, target_user, current_user) do
    case operation do
      :deactivate ->
        validate_can_deactivate(target_user, current_user)

      :delete ->
        {:error, "Admin users cannot be permanently deleted for audit purposes"}

      :change_role ->
        {:error, "Admin role cannot be changed to prevent privilege escalation"}

      :reset_password ->
        validate_can_reset_password(target_user, current_user)

      _ ->
        {:ok, :allowed}
    end
  end

  @doc """
  Generates an audit report for admin user activities.
  """
  def generate_admin_audit_report(date_range \\ nil) do
    {start_date, end_date} = date_range ||
      {Date.add(Date.utc_today(), -30), Date.utc_today()}

    admin_actions = Auditing.list_audit_logs([
      entity_type: "admin_user",
      date_range: {start_date, end_date}
    ])

    admin_logins = get_admin_login_events(start_date, end_date)

    %{
      period: {start_date, end_date},
      admin_management_actions: group_actions_by_type(admin_actions),
      login_activity: analyze_login_patterns(admin_logins),
      security_events: identify_security_events(admin_actions),
      recommendations: generate_security_recommendations(admin_actions, admin_logins)
    }
  end

  # Private helper functions

  defp validate_can_deactivate(target_user, current_user) do
    cond do
      target_user.id == current_user.id ->
        {:error, "Cannot deactivate your own admin account"}

      count_active_admin_users() <= 1 ->
        {:error, "Cannot deactivate the last active admin user"}

      String.starts_with?(target_user.email, "DEACTIVATED_") ->
        {:error, "User is already deactivated"}

      true ->
        {:ok, :can_deactivate}
    end
  end

  defp validate_can_reset_password(target_user, current_user) do
    if target_user.id == current_user.id do
      {:ok, :can_reset_own}
    else
      {:ok, :can_reset_other}
    end
  end

  defp perform_deactivation(user) do
    # Mark email as deactivated
    deactivated_email = "DEACTIVATED_#{DateTime.utc_now() |> DateTime.to_unix()}_#{user.email}"
    Accounts.update_user(user, %{email: deactivated_email})
  end

  defp perform_reactivation(user) do
    if String.starts_with?(user.email, "DEACTIVATED_") do
      original_email = get_original_email(user.email)
      Accounts.update_user(user, %{email: original_email})
    else
      {:ok, user}
    end
  end

  defp get_original_email(email) do
    if String.starts_with?(email, "DEACTIVATED_") do
      email
      |> String.split("_", parts: 3)
      |> List.last()
    else
      email
    end
  end

  defp count_active_admin_users do
    from(u in App.Accounts.User,
      where: u.role == "admin" and not like(u.email, "DEACTIVATED_%"),
      select: count(u.id)
    )
    |> Repo.one()
  end

  defp count_admins_created_this_month do
    start_of_month = Date.beginning_of_month(Date.utc_today())

    from(u in App.Accounts.User,
      where: u.role == "admin" and u.inserted_at >= ^start_of_month,
      select: count(u.id)
    )
    |> Repo.one()
  end

  defp get_last_admin_creation_date do
    from(u in App.Accounts.User,
      where: u.role == "admin",
      order_by: [desc: u.inserted_at],
      limit: 1,
      select: u.inserted_at
    )
    |> Repo.one()
  end

  defp get_recent_admin_activity(user_id, days \\ 7) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days * 24 * 3600, :second)

    # This would query audit logs for recent activity
    # For now, return mock data
    %{
      last_login: DateTime.add(DateTime.utc_now(), -:rand.uniform(7) * 24 * 3600, :second),
      actions_count: :rand.uniform(20),
      last_action: "Updated provider settings"
    }
  end

  defp count_recent_login_sessions(user_id, days \\ 30) do
    # This would count actual login sessions
    # For now, return mock data
    :rand.uniform(15)
  end

  defp get_admin_login_events(start_date, end_date) do
    # This would query login audit events
    # Return mock data for now
    []
  end

  defp group_actions_by_type(actions) do
    Enum.group_by(actions, & &1.action)
    |> Enum.map(fn {action, action_list} ->
      {action, length(action_list)}
    end)
    |> Enum.into(%{})
  end

  defp analyze_login_patterns(logins) do
    %{
      total_logins: length(logins),
      unique_users: logins |> Enum.map(& &1.user_id) |> Enum.uniq() |> length(),
      peak_hours: [9, 10, 14, 15],  # Mock data
      failed_attempts: 0,
      suspicious_activity: []
    }
  end

  defp identify_security_events(actions) do
    # Look for potentially suspicious patterns
    events = []

    # Multiple admin creations in short time
    recent_creates = Enum.filter(actions, &(&1.action == "create"))
    events = if length(recent_creates) > 3 do
      events ++ ["Multiple admin users created recently"]
    else
      events
    end

    # Rapid deactivation/reactivation cycles
    deactivations = Enum.count(actions, &(&1.action == "deactivate"))
    reactivations = Enum.count(actions, &(&1.action == "reactivate"))

    events = if deactivations > 2 && reactivations > 2 do
      events ++ ["Unusual deactivation/reactivation pattern detected"]
    else
      events
    end

    events
  end

  defp generate_security_recommendations(actions, logins) do
    recommendations = []

    # Check admin count
    active_count = count_active_admin_users()
    recommendations = cond do
      active_count < 2 ->
        recommendations ++ ["Consider having at least 2 active admin users for redundancy"]
      active_count > 10 ->
        recommendations ++ ["Consider reducing the number of admin users - only essential personnel should have admin access"]
      true ->
        recommendations
    end

    # Check for unverified admins
    stats = get_admin_user_statistics()
    recommendations = if stats.unverified > 0 do
      recommendations ++ ["#{stats.unverified} admin user(s) have unverified email addresses"]
    else
      recommendations
    end

    # Check activity patterns
    recommendations = if length(actions) == 0 do
      recommendations ++ ["No admin management activity detected - ensure proper oversight"]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["Admin user security appears to be well maintained"]
    else
      recommendations
    end
  end

  defp log_admin_action(acting_user, action, target_user, details \\ %{}) do
    Auditing.log_action(%{
      action: action,
      entity_type: "admin_user",
      entity_id: to_string(target_user.id),
      user_id: acting_user.id,
      details: Map.merge(details, %{
        acting_user_name: acting_user.name,
        acting_user_email: acting_user.email,
        target_user_name: target_user.name,
        target_user_id: target_user.id,
        timestamp: DateTime.utc_now()
      })
    })
  end

  defp send_admin_welcome_notification(admin_user, password) do
    subject = "Welcome to Under Five Health Check-Up Admin Team"

    message = """
    Dear #{admin_user.name},

    Welcome to the Under Five Health Check-Up administration team!

    Your administrator account has been created with the following credentials:
    Email: #{admin_user.email}
    Password: #{password}

    IMPORTANT SECURITY INSTRUCTIONS:
    1. Change your password immediately after your first login
    2. Enable two-factor authentication if available
    3. Never share your admin credentials with anyone
    4. Always log out when finished using the system
    5. Report any suspicious activity immediately

    As an administrator, you have access to:
    - User management and provider oversight
    - System configuration and settings
    - Reports, analytics, and audit logs
    - Appointment and health record management

    Admin Portal: [Your Website URL]/users/log_in

    Please review our admin security policies and contact the system administrator if you have any questions.

    Best regards,
    Under Five Health Check-Up Team
    """

    App.Accounts.UserNotifier.build_email(admin_user.email, subject, message)
    |> App.Mailer.deliver()

    # Also send SMS notification
    sms_message = """
    Welcome to Under Five Health Check-Up Admin Team!

    Your admin account is ready:
    Email: #{admin_user.email}
    Password: #{password}

    CRITICAL: Change password on first login. Keep credentials secure.

    Login: [Your Website URL]
    """

    App.Services.ProbaseSMS.send_sms(admin_user.phone, sms_message)
  end

  defp send_deactivation_notification(deactivated_user, deactivator_user) do
    original_email = get_original_email(deactivated_user.email)

    subject = "Admin Account Deactivated - Under Five Health Check-Up"

    message = """
    Dear #{deactivated_user.name},

    Your administrator account for Under Five Health Check-Up has been deactivated.

    Account Details:
    - Email: #{original_email}
    - Deactivated by: #{deactivator_user.name} (#{deactivator_user.email})
    - Date/Time: #{DateTime.utc_now() |> Calendar.strftime("%B %d, %Y at %I:%M %p UTC")}

    This means you no longer have access to:
    - Administrative dashboard and controls
    - User and provider management
    - System configuration and reports
    - Audit logs and analytics

    Your account data has been preserved for audit purposes, but login access has been revoked.

    If you believe this action was taken in error or if you need clarification, please contact:
    - System Administrator
    - Your supervisor or department head

    For security reasons, please:
    - Clear any saved passwords from your browsers
    - Remove any bookmarks to admin areas
    - Return any admin documentation or access credentials

    Thank you for your service to the Under Five Health Check-Up system.

    Best regards,
    Under Five Health Check-Up Team
    """

    App.Accounts.UserNotifier.build_email(original_email, subject, message)
    |> App.Mailer.deliver()
  end

  defp send_reactivation_notification(reactivated_user, reactivator_user) do
    subject = "Admin Account Reactivated - Under Five Health Check-Up"

    message = """
    Dear #{reactivated_user.name},

    Your administrator account for Under Five Health Check-Up has been reactivated!

    Account Details:
    - Email: #{reactivated_user.email}
    - Reactivated by: #{reactivator_user.name} (#{reactivator_user.email})
    - Date/Time: #{DateTime.utc_now() |> Calendar.strftime("%B %d, %Y at %I:%M %p UTC")}

    You now have full access to:
    - Administrative dashboard and controls
    - User and provider management
    - System configuration and reports
    - Audit logs and analytics

    IMPORTANT SECURITY REMINDERS:
    - Your existing password should still work
    - Consider changing your password as a security precaution
    - Review any system changes that occurred while you were inactive
    - Ensure your contact information is up to date

    Admin Portal: [Your Website URL]/users/log_in

    Welcome back to the admin team!

    Best regards,
    Under Five Health Check-Up Team
    """

    App.Accounts.UserNotifier.build_email(reactivated_user.email, subject, message)
    |> App.Mailer.deliver()
  end

  @doc """
  Schedules automated admin user security checks.
  """
  def schedule_security_health_check do
    audit_report = generate_admin_audit_report()

    if length(audit_report.security_events) > 0 do
      notify_security_team(audit_report.security_events)
    end

    # Check for inactive admin accounts that might need attention
    check_inactive_admin_accounts()

    audit_report
  end

  defp notify_security_team(security_events) do
    # Get all active admin users to notify
    active_admins = list_admin_users_with_activity()
                    |> Enum.filter(& &1.is_active)

    Enum.each(active_admins, fn admin_info ->
      send_security_alert(admin_info.user, security_events)
    end)
  end

  defp send_security_alert(admin_user, events) do
    subject = "Security Alert: Admin User Management"

    events_text = Enum.map_join(events, "\n- ", &"#{&1}")

    message = """
    Dear #{admin_user.name},

    The automated security monitoring system has detected events that require admin attention:

    SECURITY EVENTS DETECTED:
    - #{events_text}

    Please review the admin user management dashboard and take appropriate action if necessary.

    You can access detailed audit logs in the admin portal under Reports > Audit Logs.

    If you have any concerns about these events, please contact the system administrator immediately.

    Best regards,
    Under Five Health Check-Up Security Monitor
    """

    App.Accounts.UserNotifier.build_email(admin_user.email, subject, message)
    |> App.Mailer.deliver()
  end

  defp check_inactive_admin_accounts do
    # Check for admin accounts that haven't been used in a while
    # This could be implemented based on login tracking
    # For now, just return a summary
    %{
      checked_at: DateTime.utc_now(),
      inactive_accounts_found: 0,
      action_taken: "none"
    }
  end

  @doc """
  Bulk operations for admin user management.
  """
  def bulk_admin_operations(operation, admin_ids, acting_user, opts \\ []) do
    results = Enum.map(admin_ids, fn admin_id ->
      admin_user = Accounts.get_user!(admin_id)

      case operation do
        :deactivate -> deactivate_admin_user(admin_user, acting_user)
        :reactivate -> reactivate_admin_user(admin_user, acting_user)
        _ -> {:error, "Unsupported bulk operation"}
      end
    end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = length(results) - successful

    # Log bulk operation
    log_admin_action(acting_user, "bulk_#{operation}", %{id: "bulk"}, %{
      operation: operation,
      total_attempted: length(admin_ids),
      successful: successful,
      failed: failed,
      admin_ids: admin_ids
    })

    %{
      total: length(admin_ids),
      successful: successful,
      failed: failed,
      results: results
    }
  end

  @doc """
  Emergency admin account creation (for when all admins are locked out).
  """
  def create_emergency_admin(attrs) do
    # This should only be used in emergency situations
    # and should require additional verification

    emergency_attrs = attrs
                      |> Map.put("role", "admin")
                      |> Map.put("confirmed_at", DateTime.utc_now())  # Auto-confirm emergency admin

    case Accounts.register_user(emergency_attrs) do
      {:ok, admin_user} ->
        # Log emergency creation
        Auditing.log_action(%{
          action: "emergency_create",
          entity_type: "admin_user",
          entity_id: to_string(admin_user.id),
          user_id: nil,  # No acting user in emergency
          details: %{
            emergency_admin_name: admin_user.name,
            emergency_admin_email: admin_user.email,
            created_at: DateTime.utc_now(),
            reason: "emergency_access_recovery"
          }
        })

        {:ok, admin_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def count_active_admins do
    from(u in User,
      where: u.role == "admin" and not like(u.email, "DEACTIVATED_%"),
      select: count(u.id)
    )
    |> Repo.one()
  end
end
