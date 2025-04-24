defmodule App.NotificationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `App.Notifications` context.
  """

  @doc """
  Generate a notification_preference.
  """
  def notification_preference_fixture(attrs \\ %{}) do
    {:ok, notification_preference} =
      attrs
      |> Enum.into(%{
        email_enabled: true,
        reminder_hours: 42,
        sms_enabled: true
      })
      |> App.Notifications.create_notification_preference()

    notification_preference
  end
end
