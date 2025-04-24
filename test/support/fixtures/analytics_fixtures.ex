defmodule App.AnalyticsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `App.Analytics` context.
  """

  @doc """
  Generate a appointment_log.
  """
  def appointment_log_fixture(attrs \\ %{}) do
    {:ok, appointment_log} =
      attrs
      |> Enum.into(%{
        action: "some action",
        timestamp: ~U[2025-04-21 07:33:00Z]
      })
      |> App.Analytics.create_appointment_log()

    appointment_log
  end
end
