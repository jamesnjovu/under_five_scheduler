defmodule App.Workers.FollowUpReminderWorker do
  @moduledoc """
  Sends reminders for follow-up appointments and overdue checkups.
  """

  use Oban.Worker,
      queue: :notifications,
      max_attempts: 3

  alias App.Accounts
  alias App.HealthRecords
  alias App.Scheduling
  alias App.Notifications

  @impl Oban.Worker
  def perform(
        %Oban.Job{
          args: %{
            "child_id" => child_id
          }
        }
      ) do
    child = Accounts.get_child!(child_id)
    parent = Accounts.get_user!(child.user_id)

    # Check if follow-up is actually needed
    next_checkup_date = HealthRecords.calculate_next_checkup_date(child)
    days_overdue = Date.diff(Date.utc_today(), next_checkup_date)

    if days_overdue > 7 do  # Send reminder if more than 7 days overdue
      send_follow_up_reminder(parent, child, days_overdue)
    end

    :ok
  end

  defp send_follow_up_reminder(parent, child, days_overdue) do
    # Get notification preferences
    preference = Notifications.get_notification_preference(parent.id)

    message = """
    Hello #{parent.name},

    This is a reminder that #{child.name} is due for a routine health checkup.
    The recommended checkup date was #{days_overdue} days ago.

    Please schedule an appointment at your earliest convenience to ensure
    #{child.name} stays healthy and up-to-date with preventive care.

    Thank you,
    Under Five Health Check-Up Team
    """

    # Send SMS if enabled
    if preference.sms_enabled do
      App.Services.ProbaseSMS.send_sms(parent.phone, message)
    end

    # Send email if enabled
    if preference.email_enabled do
      App.Accounts.UserNotifier.build_email(
        parent.email,
        "Health Checkup Reminder for #{child.name}",
        message
      )
      |> App.Mailer.deliver()
    end
  end
end