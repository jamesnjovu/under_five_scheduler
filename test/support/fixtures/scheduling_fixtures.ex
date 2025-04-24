defmodule App.SchedulingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `App.Scheduling` context.
  """

  @doc """
  Generate a provider.
  """
  def provider_fixture(attrs \\ %{}) do
    {:ok, provider} =
      attrs
      |> Enum.into(%{
        name: "some name",
        specialization: "some specialization"
      })
      |> App.Scheduling.create_provider()

    provider
  end

  @doc """
  Generate a schedule.
  """
  def schedule_fixture(attrs \\ %{}) do
    {:ok, schedule} =
      attrs
      |> Enum.into(%{
        day_of_week: 42,
        end_time: ~T[14:00:00],
        start_time: ~T[14:00:00]
      })
      |> App.Scheduling.create_schedule()

    schedule
  end

  @doc """
  Generate a appointment.
  """
  def appointment_fixture(attrs \\ %{}) do
    {:ok, appointment} =
      attrs
      |> Enum.into(%{
        notes: "some notes",
        scheduled_date: ~D[2025-04-21],
        scheduled_time: ~T[14:00:00],
        status: "some status"
      })
      |> App.Scheduling.create_appointment()

    appointment
  end
end
