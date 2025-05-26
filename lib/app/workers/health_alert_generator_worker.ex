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
    children =
      Accounts.list_users_by_role("parent")
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
