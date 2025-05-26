defmodule App.Workers.ImmunizationReminderWorker do
  @moduledoc """
  Sends reminders for upcoming and overdue immunizations.
  """

  use Oban.Worker,
      queue: :notifications,
      max_attempts: 3

  alias App.Accounts
  alias App.HealthRecords
  alias App.Notifications

  @impl Oban.Worker
  def perform(
        %Oban.Job{
          args: %{
            "child_id" => child_id,
            "reminder_type" => type
          }
        }
      ) do
    child = Accounts.get_child!(child_id)
    parent = Accounts.get_user!(child.user_id)

    case type do
      "upcoming" -> send_upcoming_reminder(parent, child)
      "overdue" -> send_overdue_reminder(parent, child)
    end

    :ok
  end

  defp send_upcoming_reminder(parent, child) do
    upcoming =
      HealthRecords.get_upcoming_immunizations(child.id)
      |> Enum.filter(
           fn imm ->
             Date.diff(imm.due_date, Date.utc_today()) <= 7
             # Due within a week
           end
         )

    if length(upcoming) > 0 do
      vaccine_list =
        upcoming
        |> Enum.map(fn imm -> "#{imm.vaccine_name} (due #{Date.to_string(imm.due_date)})" end)
        |> Enum.join(", ")

      message = """
      Hello #{parent.name},

      This is a reminder that #{child.name} has upcoming vaccinations:
      #{vaccine_list}

      Please schedule an appointment to keep #{child.name}'s immunizations up to date.

      Thank you,
      Under Five Health Check-Up Team
      """

      send_notification(parent, "Upcoming Vaccinations for #{child.name}", message)
    end
  end

  defp send_overdue_reminder(parent, child) do
    missed = HealthRecords.get_missed_immunizations(child.id)

    if length(missed) > 0 do
      vaccine_list =
        missed
        |> Enum.map(fn imm -> "#{imm.vaccine_name} (was due #{Date.to_string(imm.due_date)})" end)
        |> Enum.join(", ")

      message = """
      IMPORTANT: #{child.name} has overdue vaccinations that need immediate attention:
      #{vaccine_list}

      Please schedule an appointment as soon as possible to catch up on these important immunizations.

      Under Five Health Check-Up Team
      """

      send_notification(parent, "URGENT: Overdue Vaccinations for #{child.name}", message)
    end
  end

  defp send_notification(parent, subject, message) do
    preference = Notifications.get_notification_preference(parent.id)

    # Send SMS if enabled
    if preference.sms_enabled do
      App.Services.ProbaseSMS.send_sms(parent.phone, message)
    end

    # Send email if enabled
    if preference.email_enabled do
      App.Accounts.UserNotifier.build_email(parent.email, subject, message)
      |> App.Mailer.deliver()
    end
  end
end