defmodule App.NotificationsTest do
  use App.DataCase

  alias App.Notifications

  describe "notification_preferences" do
    alias App.Notifications.NotificationPreference

    import App.NotificationsFixtures

    @invalid_attrs %{email_enabled: nil, reminder_hours: nil, sms_enabled: nil}

    test "list_notification_preferences/0 returns all notification_preferences" do
      notification_preference = notification_preference_fixture()
      assert Notifications.list_notification_preferences() == [notification_preference]
    end

    test "get_notification_preference!/1 returns the notification_preference with given id" do
      notification_preference = notification_preference_fixture()
      assert Notifications.get_notification_preference!(notification_preference.id) == notification_preference
    end

    test "create_notification_preference/1 with valid data creates a notification_preference" do
      valid_attrs = %{email_enabled: true, reminder_hours: 42, sms_enabled: true}

      assert {:ok, %NotificationPreference{} = notification_preference} = Notifications.create_notification_preference(valid_attrs)
      assert notification_preference.email_enabled == true
      assert notification_preference.reminder_hours == 42
      assert notification_preference.sms_enabled == true
    end

    test "create_notification_preference/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Notifications.create_notification_preference(@invalid_attrs)
    end

    test "update_notification_preference/2 with valid data updates the notification_preference" do
      notification_preference = notification_preference_fixture()
      update_attrs = %{email_enabled: false, reminder_hours: 43, sms_enabled: false}

      assert {:ok, %NotificationPreference{} = notification_preference} = Notifications.update_notification_preference(notification_preference, update_attrs)
      assert notification_preference.email_enabled == false
      assert notification_preference.reminder_hours == 43
      assert notification_preference.sms_enabled == false
    end

    test "update_notification_preference/2 with invalid data returns error changeset" do
      notification_preference = notification_preference_fixture()
      assert {:error, %Ecto.Changeset{}} = Notifications.update_notification_preference(notification_preference, @invalid_attrs)
      assert notification_preference == Notifications.get_notification_preference!(notification_preference.id)
    end

    test "delete_notification_preference/1 deletes the notification_preference" do
      notification_preference = notification_preference_fixture()
      assert {:ok, %NotificationPreference{}} = Notifications.delete_notification_preference(notification_preference)
      assert_raise Ecto.NoResultsError, fn -> Notifications.get_notification_preference!(notification_preference.id) end
    end

    test "change_notification_preference/1 returns a notification_preference changeset" do
      notification_preference = notification_preference_fixture()
      assert %Ecto.Changeset{} = Notifications.change_notification_preference(notification_preference)
    end
  end
end
