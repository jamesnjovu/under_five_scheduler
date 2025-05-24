defmodule App.HealthMonitoring.Scheduler do
  @moduledoc """
  Schedules and coordinates health monitoring tasks.
  """

  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    # Schedule initial health monitoring tasks
    schedule_initial_tasks()

    # Set up periodic tasks
    schedule_periodic_tasks()

    {:ok, %{started_at: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:daily_health_check, state) do
    Logger.info("Running daily health monitoring checks")

    # Schedule health alert generation for all children
    %{}
    |> App.Workers.HealthAlertGeneratorWorker.new()
    |> Oban.insert()

    # Schedule next daily check
    :timer.send_after(:timer.hours(24), self(), :daily_health_check)

    {:noreply, state}
  end

  @impl true
  def handle_info(:weekly_analytics, state) do
    Logger.info("Running weekly health analytics")

    # Generate weekly health reports
    generate_weekly_reports()

    # Schedule next weekly check
    :timer.send_after(:timer.hours(24 * 7), self(), :weekly_analytics)

    {:noreply, state}
  end

  defp schedule_initial_tasks do
    # Run initial health check after 30 seconds
    :timer.send_after(:timer.seconds(30), self(), :daily_health_check)
  end

  defp schedule_periodic_tasks do
    # Schedule weekly analytics (run on Sundays)
    current_day = Date.day_of_week(Date.utc_today())
    days_until_sunday = rem(7 - current_day + 7, 7)
    days_until_sunday = if days_until_sunday == 0, do: 7, else: days_until_sunday

    :timer.send_after(:timer.hours(24 * days_until_sunday), self(), :weekly_analytics)
  end

  defp generate_weekly_reports do
    # This could generate comprehensive health reports
    # For now, just log that it's running
    Logger.info("Weekly health analytics completed")
  end
end
