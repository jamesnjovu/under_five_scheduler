defmodule App.AnalyticsTest do
  use App.DataCase

  alias App.Analytics

  describe "appointment_logs" do
    alias App.Analytics.AppointmentLog

    import App.AnalyticsFixtures

    @invalid_attrs %{action: nil, timestamp: nil}

    test "list_appointment_logs/0 returns all appointment_logs" do
      appointment_log = appointment_log_fixture()
      assert Analytics.list_appointment_logs() == [appointment_log]
    end

    test "get_appointment_log!/1 returns the appointment_log with given id" do
      appointment_log = appointment_log_fixture()
      assert Analytics.get_appointment_log!(appointment_log.id) == appointment_log
    end

    test "create_appointment_log/1 with valid data creates a appointment_log" do
      valid_attrs = %{action: "some action", timestamp: ~U[2025-04-21 07:33:00Z]}

      assert {:ok, %AppointmentLog{} = appointment_log} = Analytics.create_appointment_log(valid_attrs)
      assert appointment_log.action == "some action"
      assert appointment_log.timestamp == ~U[2025-04-21 07:33:00Z]
    end

    test "create_appointment_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Analytics.create_appointment_log(@invalid_attrs)
    end

    test "update_appointment_log/2 with valid data updates the appointment_log" do
      appointment_log = appointment_log_fixture()
      update_attrs = %{action: "some updated action", timestamp: ~U[2025-04-22 07:33:00Z]}

      assert {:ok, %AppointmentLog{} = appointment_log} = Analytics.update_appointment_log(appointment_log, update_attrs)
      assert appointment_log.action == "some updated action"
      assert appointment_log.timestamp == ~U[2025-04-22 07:33:00Z]
    end

    test "update_appointment_log/2 with invalid data returns error changeset" do
      appointment_log = appointment_log_fixture()
      assert {:error, %Ecto.Changeset{}} = Analytics.update_appointment_log(appointment_log, @invalid_attrs)
      assert appointment_log == Analytics.get_appointment_log!(appointment_log.id)
    end

    test "delete_appointment_log/1 deletes the appointment_log" do
      appointment_log = appointment_log_fixture()
      assert {:ok, %AppointmentLog{}} = Analytics.delete_appointment_log(appointment_log)
      assert_raise Ecto.NoResultsError, fn -> Analytics.get_appointment_log!(appointment_log.id) end
    end

    test "change_appointment_log/1 returns a appointment_log changeset" do
      appointment_log = appointment_log_fixture()
      assert %Ecto.Changeset{} = Analytics.change_appointment_log(appointment_log)
    end
  end
end
