defmodule App.HealthAlerts do
  @moduledoc """
  The HealthAlerts context for managing health alerts and notifications.
  """

  import Ecto.Query, warn: false
  alias App.Repo
  alias App.HealthRecords.HealthAlert
  alias App.HealthRecords
  alias App.Accounts

  @doc """
  Creates a health alert for a child.
  """
  def create_alert(attrs \\ %{}) do
    %HealthAlert{}
    |> HealthAlert.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all active (unresolved) alerts for a child.
  """
  def get_active_alerts(child_id) do
    HealthAlert
    |> where([a], a.child_id == ^child_id and a.is_resolved == false)
    |> order_by([a], [desc: :severity, desc: :inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets all alerts for a child, including resolved ones.
  """
  def get_all_alerts(child_id) do
    HealthAlert
    |> where([a], a.child_id == ^child_id)
    |> order_by([a], [desc: :inserted_at])
    |> Repo.all()
    |> Repo.preload([:child])
  end

  @doc """
  Resolves an alert.
  """
  def resolve_alert(alert_id, user_id) do
    alert = Repo.get!(HealthAlert, alert_id)

    alert
    |> HealthAlert.resolve_alert(user_id)
    |> Repo.update()
  end

  @doc """
  Generates health alerts for a child based on current health status.
  This function analyzes immunization records, growth data, and appointment history.
  """
  def generate_health_alerts(child_id) do
    child = Accounts.get_child!(child_id)
    _existing_alerts = get_active_alerts(child_id)

    # Clear existing auto-generated alerts
    clear_auto_generated_alerts(child_id)

    alerts_to_create = []

    # Check immunization status
    alerts_to_create = alerts_to_create ++ check_immunization_alerts(child_id)

    # Check growth concerns
    alerts_to_create = alerts_to_create ++ check_growth_alerts(child_id, child)

    # Check missed appointments
    alerts_to_create = alerts_to_create ++ check_missed_appointments(child_id)

    # Check overdue follow-ups
    alerts_to_create = alerts_to_create ++ check_overdue_followups(child_id, child)

    # Create new alerts
    Enum.each(alerts_to_create, &create_alert/1)

    # Return updated alerts
    get_active_alerts(child_id)
  end

  @doc """
  Gets alerts for a provider's patients.
  """
  def get_provider_alerts(provider_id) do
    # Get all children that have appointments with this provider
    child_ids = get_provider_patient_ids(provider_id)

    HealthAlert
    |> where([a], a.child_id in ^child_ids and a.is_resolved == false)
    |> order_by([a], [desc: :severity, desc: :inserted_at])
    |> Repo.all()
    |> Repo.preload([:child])
  end

  @doc """
  Gets alert statistics for dashboard.
  """
  def get_alert_statistics(provider_id \\ nil) do
    base_query = if provider_id do
      child_ids = get_provider_patient_ids(provider_id)
      HealthAlert |> where([a], a.child_id in ^child_ids)
    else
      HealthAlert
    end

    active_alerts = base_query |> where([a], a.is_resolved == false)

    %{
      total_active: Repo.aggregate(active_alerts, :count, :id),
      critical: active_alerts |> where([a], a.severity == "critical") |> Repo.aggregate(:count, :id),
      high: active_alerts |> where([a], a.severity == "high") |> Repo.aggregate(:count, :id),
      medium: active_alerts |> where([a], a.severity == "medium") |> Repo.aggregate(:count, :id),
      low: active_alerts |> where([a], a.severity == "low") |> Repo.aggregate(:count, :id),
      by_type: get_alerts_by_type(base_query)
    }
  end

  # Private helper functions

  defp clear_auto_generated_alerts(child_id) do
    HealthAlert
    |> where([a], a.child_id == ^child_id and a.auto_generated == true and a.is_resolved == false)
    |> Repo.delete_all()
  end

  defp check_immunization_alerts(child_id) do
    missed_immunizations = HealthRecords.get_missed_immunizations(child_id)
    upcoming_immunizations = HealthRecords.get_upcoming_immunizations(child_id)

    alerts = []

    # Critical: Missed immunizations
    alerts = if length(missed_immunizations) > 0 do
      vaccine_names = Enum.map(missed_immunizations, & &1.vaccine_name) |> Enum.join(", ")

      alerts ++ [%{
        child_id: child_id,
        alert_type: "immunization_overdue",
        severity: "high",
        message: "#{length(missed_immunizations)} overdue vaccination(s): #{vaccine_names}",
        action_required: "Schedule immediate catch-up vaccinations",
        auto_generated: true
      }]
    else
      alerts
    end

    # Medium: Upcoming immunizations (within 2 weeks)
    due_soon = Enum.filter(upcoming_immunizations, fn imm ->
      Date.diff(imm.due_date, Date.utc_today()) <= 14
    end)

    alerts = if length(due_soon) > 0 do
      vaccine_names = Enum.map(due_soon, & &1.vaccine_name) |> Enum.join(", ")

      alerts ++ [%{
        child_id: child_id,
        alert_type: "immunization_overdue",
        severity: "medium",
        message: "#{length(due_soon)} vaccination(s) due soon: #{vaccine_names}",
        action_required: "Schedule vaccination appointment",
        auto_generated: true
      }]
    else
      alerts
    end

    alerts
  end

  defp check_growth_alerts(child_id, child) do
    growth_records = HealthRecords.list_growth_records(child_id)
    latest_growth = List.first(growth_records)

    alerts = []

    # Check if growth measurements are overdue
    age_months = App.Accounts.Child.age_in_months(child)
    expected_interval = if age_months < 12, do: 90, else: 180  # 3 or 6 months

    alerts = if latest_growth do
      days_since = Date.diff(Date.utc_today(), latest_growth.measurement_date)

      if days_since > expected_interval do
        alerts ++ [%{
          child_id: child_id,
          alert_type: "growth_concern",
          severity: "medium",
          message: "Growth measurements overdue (#{days_since} days since last measurement)",
          action_required: "Record current weight and height measurements",
          auto_generated: true
        }]
      else
        alerts
      end
    else
      alerts ++ [%{
        child_id: child_id,
        alert_type: "growth_concern",
        severity: "medium",
        message: "No growth records available",
        action_required: "Establish baseline growth measurements",
        auto_generated: true
      }]
    end

    # Check for concerning growth trends
    if length(growth_records) >= 2 do
      trends = HealthRecords.calculate_growth_trends(growth_records)

      alerts = case trends.weight.trend_direction do
        :decreasing when age_months < 24 ->
          alerts ++ [%{
            child_id: child_id,
            alert_type: "growth_concern",
            severity: "high",
            message: "Weight loss detected in infant",
            action_required: "Immediate nutritional evaluation required",
            auto_generated: true
          }]

        :decreasing ->
          alerts ++ [%{
            child_id: child_id,
            alert_type: "growth_concern",
            severity: "medium",
            message: "Declining weight trend observed",
            action_required: "Monitor nutrition and feeding patterns",
            auto_generated: true
          }]

        _ -> alerts
      end

      alerts
    else
      alerts
    end
  end

  defp check_missed_appointments(child_id) do
    # Check for no-show appointments in the last 6 months
    six_months_ago = Date.add(Date.utc_today(), -180)

    missed_count = App.Scheduling.list_appointments(child_id: child_id)
                   |> Enum.filter(fn appt ->
      appt.status == "no_show" and
      Date.compare(appt.scheduled_date, six_months_ago) == :gt
    end)
                   |> length()

    if missed_count >= 2 do
      [%{
        child_id: child_id,
        alert_type: "missed_appointment",
        severity: "medium",
        message: "Multiple missed appointments (#{missed_count} in last 6 months)",
        action_required: "Contact family to discuss appointment adherence",
        auto_generated: true
      }]
    else
      []
    end
  end

  defp check_overdue_followups(child_id, child) do
    # Calculate when next checkup should be based on age
    last_appointment = App.Scheduling.list_appointments(child_id: child_id)
                       |> Enum.filter(&(&1.status == "completed"))
                       |> Enum.sort_by(& &1.scheduled_date, :desc)
                       |> List.first()

    if last_appointment do
      next_checkup_date = HealthRecords.calculate_next_checkup_date(child, last_appointment.scheduled_date)
      days_overdue = Date.diff(Date.utc_today(), next_checkup_date)

      if days_overdue > 30 do  # More than 30 days overdue
        [%{
          child_id: child_id,
          alert_type: "follow_up_required",
          severity: "medium",
          message: "Routine checkup overdue by #{days_overdue} days",
          action_required: "Schedule routine health checkup",
          auto_generated: true
        }]
      else
        []
      end
    else
      []
    end
  end

  defp get_provider_patient_ids(provider_id) do
    App.Scheduling.list_appointments(provider_id: provider_id)
    |> Enum.map(& &1.child_id)
    |> Enum.uniq()
  end

  defp get_alerts_by_type(base_query) do
    base_query
    |> where([a], a.is_resolved == false)
    |> group_by([a], a.alert_type)
    |> select([a], {a.alert_type, count(a.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end
end