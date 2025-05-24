# lib/app/workers/health_alert_generator_worker.ex

defmodule App.Workers.HealthAlertGeneratorWorker do
  @moduledoc """
  Background worker that generates health alerts for all children.
  Runs daily to check for overdue immunizations, missed appointments, etc.
  """

  use Oban.Worker,
      queue: :health_monitoring,
      max_attempts: 3

  alias App.Accounts
  alias App.HealthAlerts

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Get all active children
    children = Accounts.list_users_by_role("parent")
               |> Enum.flat_map(
                    fn parent ->
                      Accounts.list_children(parent.id)
                    end
                  )
               |> Enum.filter(&(&1.status == "active"))

    # Generate alerts for each child
    Enum.each(
      children,
      fn child ->
        try do
          HealthAlerts.generate_health_alerts(child.id)
        rescue
          error ->
            # Log error but continue processing other children
            require Logger
            Logger.error("Failed to generate alerts for child #{child.id}: #{inspect(error)}")
        end
      end
    )

    :ok
  end

  @doc """
  Schedules the daily health alert generation job.
  """
  def schedule_daily_job do
    # Schedule to run every day at 6 AM
    %{scheduled_at: next_run_time()}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  defp next_run_time do
    now = DateTime.utc_now()
    tomorrow = DateTime.add(now, 1, :day)

    # Set to 6 AM tomorrow
    %{tomorrow | hour: 6, minute: 0, second: 0, microsecond: {0, 6}}
  end
end

# lib/app/workers/follow_up_reminder_worker.ex

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

# lib/app/workers/growth_trend_analyzer_worker.ex

defmodule App.Workers.GrowthTrendAnalyzerWorker do
  @moduledoc """
  Analyzes growth trends for children and generates alerts for concerning patterns.
  """

  use Oban.Worker,
      queue: :health_monitoring,
      max_attempts: 3

  alias App.Accounts
  alias App.HealthRecords
  alias App.HealthAlerts

  @impl Oban.Worker
  def perform(
        %Oban.Job{
          args: %{
            "child_id" => child_id
          }
        }
      ) do
    child = Accounts.get_child!(child_id)
    growth_records = HealthRecords.list_growth_records(child_id)

    if length(growth_records) >= 3 do
      analyze_growth_trends(child, growth_records)
    end

    :ok
  end

  defp analyze_growth_trends(child, growth_records) do
    trends = HealthRecords.calculate_growth_trends(growth_records)
    age_months = App.Accounts.Child.age_in_months(child)

    # Check for concerning weight trends
    case trends.weight.trend_direction do
      :decreasing when age_months < 24 ->
        HealthAlerts.create_alert(
          %{
            child_id: child.id,
            alert_type: "growth_concern",
            severity: "high",
            message: "Significant weight loss detected in infant",
            action_required: "Immediate medical evaluation required",
            auto_generated: true
          }
        )

      :decreasing ->
        # Check if rate of loss is concerning
        rate = trends.weight.rate_per_month
        if Decimal.compare(rate, Decimal.new("-0.5")) == :lt do
          HealthAlerts.create_alert(
            %{
              child_id: child.id,
              alert_type: "growth_concern",
              severity: "medium",
              message: "Rapid weight loss trend (#{rate} kg/month)",
              action_required: "Nutritional assessment recommended",
              auto_generated: true
            }
          )
        end

      _ -> :ok
    end

    # Check for concerning height trends
    case trends.height.trend_direction do
      :decreasing ->
        HealthAlerts.create_alert(
          %{
            child_id: child.id,
            alert_type: "growth_concern",
            severity: "medium",
            message: "Height growth appears to be slowing",
            action_required: "Consider nutritional and endocrine evaluation",
            auto_generated: true
          }
        )

      _ -> :ok
    end
  end
end

# lib/app/workers/immunization_reminder_worker.ex

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
    upcoming = HealthRecords.get_upcoming_immunizations(child.id)
               |> Enum.filter(
                    fn imm ->
                      Date.diff(imm.due_date, Date.utc_today()) <= 7
                      # Due within a week
                    end
                  )

    if length(upcoming) > 0 do
      vaccine_list = upcoming
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
      vaccine_list = missed
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