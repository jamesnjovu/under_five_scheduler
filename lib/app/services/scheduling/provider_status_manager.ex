defmodule App.Scheduling.ProviderStatusManager do
  @moduledoc """
  Handles provider status changes and related business logic.
  """

  alias App.Scheduling
  alias App.Accounts
  alias App.Notifications
  alias App.Administration.Auditing

  @doc """
  Safely deactivates a provider with proper notifications and cleanup.
  """
  def deactivate_provider(provider, admin_user, opts \\ []) do
    force = Keyword.get(opts, :force, false)
    notify_patients = Keyword.get(opts, :notify_patients, true)

    # Check if provider can be deactivated
    validation = Scheduling.can_deactivate_provider?(provider.id)

    if validation.can_deactivate or force do
      case Scheduling.deactivate_provider(provider) do
        {:ok, updated_provider} ->
          # Log the action
          log_provider_status_change(provider, admin_user, "deactivated")

          # Handle appointments if there are any
          if validation.upcoming_appointments > 0 do
            cancelled_count = cancel_future_appointments(provider.id, notify_patients)

            # Notify admin about cancelled appointments
            send_admin_notification(admin_user, provider, "deactivated", %{
              cancelled_appointments: cancelled_count
            })
          end

          {:ok, updated_provider, validation}

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, "Provider cannot be deactivated due to upcoming appointments"}
    end
  end

  @doc """
  Reactivates a provider and restores their access.
  """
  def reactivate_provider(provider, admin_user) do
    case Scheduling.reactivate_provider(provider) do
      {:ok, updated_provider} ->
        # Log the action
        log_provider_status_change(provider, admin_user, "reactivated")

        # Send welcome back notification
        send_provider_reactivation_notification(updated_provider)

        # Notify admin
        send_admin_notification(admin_user, provider, "reactivated", %{})

        {:ok, updated_provider}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a summary of provider status changes for reporting.
  """
  def get_status_change_summary(date_range \\ nil) do
    {start_date, end_date} = date_range || {Date.add(Date.utc_today(), -30), Date.utc_today()}

    # Query audit logs for provider status changes
    status_changes = Auditing.list_audit_logs([
      entity_type: "provider",
      action: ["deactivate", "reactivate"],
      date_range: {start_date, end_date}
    ])

    %{
      total_changes: length(status_changes),
      deactivations: Enum.count(status_changes, &(&1.action == "deactivate")),
      reactivations: Enum.count(status_changes, &(&1.action == "reactivate")),
      date_range: {start_date, end_date},
      changes: status_changes
    }
  end

  @doc """
  Checks provider status health across the system.
  """
  def provider_status_health_check do
    stats = Scheduling.get_provider_statistics()

    # Calculate health metrics
    active_percentage = if stats.total > 0, do: (stats.active / stats.total * 100), else: 0

    # Identify potential issues
    issues = []

    issues = if active_percentage < 50 do
      issues ++ ["Low active provider percentage: #{Float.round(active_percentage, 1)}%"]
    else
      issues
    end

    issues = if stats.active < 3 do
      issues ++ ["Very few active providers: #{stats.active}"]
    else
      issues
    end

    # Check for specialization coverage
    critical_specializations = ["pediatrician", "nurse", "clinical_officer"]
    missing_specializations = Enum.filter(critical_specializations, fn spec ->
      Map.get(stats.by_specialization, spec, 0) == 0
    end)

    issues = if length(missing_specializations) > 0 do
      issues ++ ["Missing critical specializations: #{Enum.join(missing_specializations, ", ")}"]
    else
      issues
    end

    %{
      overall_health: if(length(issues) == 0, do: :healthy, else: :warning),
      statistics: stats,
      active_percentage: Float.round(active_percentage, 1),
      issues: issues,
      recommendations: generate_recommendations(stats, issues)
    }
  end

  # Private helper functions

  defp cancel_future_appointments(provider_id, notify_patients) do
    today = Date.utc_today()

    future_appointments =
      App.Scheduling.list_appointments(provider_id: provider_id)
      |> Enum.filter(fn appointment ->
        Date.compare(appointment.scheduled_date, today) == :gt and
        appointment.status in ["scheduled", "confirmed"]
      end)

    Enum.each(future_appointments, fn appointment ->
      # Cancel the appointment
      App.Scheduling.update_appointment(appointment, %{
        status: "cancelled",
        notes: "Cancelled due to provider unavailability. Please contact us to reschedule."
      })

      # Send notification to patient if requested
      if notify_patients do
        Notifications.send_cancellation_notification(appointment)
      end
    end)

    length(future_appointments)
  end

  defp log_provider_status_change(provider, admin_user, action) do
    Auditing.log_action(%{
      action: action,
      entity_type: "provider",
      entity_id: to_string(provider.id),
      user_id: admin_user.id,
      details: %{
        provider_name: provider.name,
        provider_email: provider.user.email,
        specialization: provider.specialization,
        action_timestamp: DateTime.utc_now()
      }
    })
  end

  defp send_provider_reactivation_notification(provider) do
    # Send email to provider about reactivation
    subject = "Your Provider Account Has Been Reactivated"

    message = """
    Dear #{provider.name},

    Your healthcare provider account has been reactivated and you can now log in to the system.

    You can access your provider portal to:
    - View your schedule
    - Manage appointments
    - Access patient records
    - Update your availability

    If you have any questions, please contact the administrator.

    Best regards,
    Under Five Health Check-Up Team
    """

    Accounts.UserNotifier.build_email(provider.user.email, subject, message)
    |> App.Mailer.deliver()
  end

  defp send_admin_notification(admin_user, provider, action, details) do
    subject = "Provider Status Changed: #{provider.name}"

    cancelled_info = case Map.get(details, :cancelled_appointments, 0) do
      0 -> ""
      count -> "\n\nAs a result, #{count} upcoming appointment(s) have been cancelled and patients have been notified."
    end

    message = """
    Dear #{admin_user.name},

    Provider status has been changed:

    Provider: #{provider.name}
    Email: #{provider.user.email}
    Specialization: #{App.Setup.Specializations.display_name(provider.specialization)}
    Action: #{String.capitalize(action)}
    Time: #{DateTime.utc_now() |> DateTime.to_string()}#{cancelled_info}

    You can view and manage providers in the admin portal.

    Best regards,
    Under Five Health Check-Up System
    """

    Accounts.UserNotifier.build_email(admin_user.email, subject, message)
    |> App.Mailer.deliver()
  end

  defp generate_recommendations(stats, issues) do
    recommendations = []

    recommendations = if stats.active < 5 do
      recommendations ++ ["Consider recruiting more healthcare providers to ensure adequate coverage"]
    else
      recommendations
    end

    recommendations = if Map.get(stats.by_specialization, "pediatrician", 0) == 0 do
      recommendations ++ ["Urgent: No active pediatricians available - this is critical for under-5 healthcare"]
    else
      recommendations
    end

    recommendations = if Map.get(stats.by_specialization, "nurse", 0) < 2 do
      recommendations ++ ["Consider adding more nursing staff for better patient support"]
    else
      recommendations
    end

    recommendations = if stats.inactive > stats.active do
      recommendations ++ ["Review inactive providers - some may be reactivated if appropriate"]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["Provider coverage appears adequate - continue monitoring"]
    else
      recommendations
    end
  end

  @doc """
  Bulk operations for provider status management.
  """
  def bulk_update_provider_status(provider_ids, new_status, admin_user, opts \\ []) do
    notify_patients = Keyword.get(opts, :notify_patients, true)

    results = Enum.map(provider_ids, fn provider_id ->
      provider = Scheduling.get_provider!(provider_id)

      case new_status do
        :active -> reactivate_provider(provider, admin_user)
        :inactive -> deactivate_provider(provider, admin_user, notify_patients: notify_patients)
        _ -> {:error, "Invalid status"}
      end
    end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = length(results) - successful

    %{
      total: length(provider_ids),
      successful: successful,
      failed: failed,
      results: results
    }
  end

  @doc """
  Schedules automated provider status checks.
  """
  def schedule_status_health_check do
    # This could be called by a scheduled job to regularly check provider status
    health_check = provider_status_health_check()

    if health_check.overall_health == :warning do
      # Send alert to admin users
      admin_users = Accounts.list_users_by_role("admin")

      Enum.each(admin_users, fn admin ->
        send_health_check_alert(admin, health_check)
      end)
    end

    health_check
  end

  defp send_health_check_alert(admin_user, health_check) do
    subject = "Provider Status Health Alert"

    issues_text = Enum.map_join(health_check.issues, "\n- ", &"#{&1}")
    recommendations_text = Enum.map_join(health_check.recommendations, "\n- ", &"#{&1}")

    message = """
    Dear #{admin_user.name},

    The automated provider status health check has detected some issues that require attention:

    CURRENT STATUS:
    - Total Providers: #{health_check.statistics.total}
    - Active Providers: #{health_check.statistics.active}
    - Inactive Providers: #{health_check.statistics.inactive}
    - Active Percentage: #{health_check.active_percentage}%

    ISSUES DETECTED:
    - #{issues_text}

    RECOMMENDATIONS:
    - #{recommendations_text}

    Please review the provider management dashboard and take appropriate action.

    Best regards,
    Under Five Health Check-Up System
    """

    Accounts.UserNotifier.build_email(admin_user.email, subject, message)
    |> App.Mailer.deliver()
  end

  @doc """
  Exports provider status report for external analysis.
  """
  def export_provider_status_report(format \\ :csv) do
    providers = Scheduling.list_providers(include_inactive: true)

    data = Enum.map(providers, fn provider ->
      user = Accounts.get_user!(provider.user_id)

      %{
        id: provider.id,
        name: provider.name,
        email: user.email,
        phone: user.phone,
        specialization: provider.specialization,
        specialization_display: App.Setup.Specializations.display_name(provider.specialization),
        license_number: provider.license_number,
        is_active: provider.is_active,
        status: if(provider.is_active, do: "Active", else: "Inactive"),
        created_at: provider.inserted_at,
        updated_at: provider.updated_at,
        verified: not is_nil(user.confirmed_at)
      }
    end)

    case format do
      :csv -> format_as_csv(data)
      :json -> Jason.encode!(data)
      _ -> data
    end
  end

  defp format_as_csv(data) do
    if length(data) == 0, do: ""

    headers = data |> List.first() |> Map.keys() |> Enum.map(&to_string/1) |> Enum.join(",")

    rows = Enum.map(data, fn row ->
      row
      |> Map.values()
      |> Enum.map(&format_csv_value/1)
      |> Enum.join(",")
    end)

    [headers | rows] |> Enum.join("\n")
  end

  defp format_csv_value(value) when is_binary(value), do: "\"#{String.replace(value, "\"", "\"\"")}\""
  defp format_csv_value(value) when is_boolean(value), do: to_string(value)
  defp format_csv_value(value) when is_nil(value), do: ""
  defp format_csv_value(value), do: to_string(value)
end