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
  def perform(%Oban.Job{args: %{"child_id" => child_id}}) do
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