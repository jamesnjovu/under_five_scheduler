defmodule App.SchedulingTest do
  use App.DataCase

  alias App.Scheduling

  describe "providers" do
    alias App.Scheduling.Provider

    import App.SchedulingFixtures

    @invalid_attrs %{name: nil, specialization: nil}

    test "list_providers/0 returns all providers" do
      provider = provider_fixture()
      assert Scheduling.list_providers() == [provider]
    end

    test "get_provider!/1 returns the provider with given id" do
      provider = provider_fixture()
      assert Scheduling.get_provider!(provider.id) == provider
    end

    test "create_provider/1 with valid data creates a provider" do
      valid_attrs = %{name: "some name", specialization: "some specialization"}

      assert {:ok, %Provider{} = provider} = Scheduling.create_provider(valid_attrs)
      assert provider.name == "some name"
      assert provider.specialization == "some specialization"
    end

    test "create_provider/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Scheduling.create_provider(@invalid_attrs)
    end

    test "update_provider/2 with valid data updates the provider" do
      provider = provider_fixture()
      update_attrs = %{name: "some updated name", specialization: "some updated specialization"}

      assert {:ok, %Provider{} = provider} = Scheduling.update_provider(provider, update_attrs)
      assert provider.name == "some updated name"
      assert provider.specialization == "some updated specialization"
    end

    test "update_provider/2 with invalid data returns error changeset" do
      provider = provider_fixture()
      assert {:error, %Ecto.Changeset{}} = Scheduling.update_provider(provider, @invalid_attrs)
      assert provider == Scheduling.get_provider!(provider.id)
    end

    test "delete_provider/1 deletes the provider" do
      provider = provider_fixture()
      assert {:ok, %Provider{}} = Scheduling.delete_provider(provider)
      assert_raise Ecto.NoResultsError, fn -> Scheduling.get_provider!(provider.id) end
    end

    test "change_provider/1 returns a provider changeset" do
      provider = provider_fixture()
      assert %Ecto.Changeset{} = Scheduling.change_provider(provider)
    end
  end

  describe "schedules" do
    alias App.Scheduling.Schedule

    import App.SchedulingFixtures

    @invalid_attrs %{day_of_week: nil, end_time: nil, start_time: nil}

    test "list_schedules/0 returns all schedules" do
      schedule = schedule_fixture()
      assert Scheduling.list_schedules() == [schedule]
    end

    test "get_schedule!/1 returns the schedule with given id" do
      schedule = schedule_fixture()
      assert Scheduling.get_schedule!(schedule.id) == schedule
    end

    test "create_schedule/1 with valid data creates a schedule" do
      valid_attrs = %{day_of_week: 42, end_time: ~T[14:00:00], start_time: ~T[14:00:00]}

      assert {:ok, %Schedule{} = schedule} = Scheduling.create_schedule(valid_attrs)
      assert schedule.day_of_week == 42
      assert schedule.end_time == ~T[14:00:00]
      assert schedule.start_time == ~T[14:00:00]
    end

    test "create_schedule/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Scheduling.create_schedule(@invalid_attrs)
    end

    test "update_schedule/2 with valid data updates the schedule" do
      schedule = schedule_fixture()
      update_attrs = %{day_of_week: 43, end_time: ~T[15:01:01], start_time: ~T[15:01:01]}

      assert {:ok, %Schedule{} = schedule} = Scheduling.update_schedule(schedule, update_attrs)
      assert schedule.day_of_week == 43
      assert schedule.end_time == ~T[15:01:01]
      assert schedule.start_time == ~T[15:01:01]
    end

    test "update_schedule/2 with invalid data returns error changeset" do
      schedule = schedule_fixture()
      assert {:error, %Ecto.Changeset{}} = Scheduling.update_schedule(schedule, @invalid_attrs)
      assert schedule == Scheduling.get_schedule!(schedule.id)
    end

    test "delete_schedule/1 deletes the schedule" do
      schedule = schedule_fixture()
      assert {:ok, %Schedule{}} = Scheduling.delete_schedule(schedule)
      assert_raise Ecto.NoResultsError, fn -> Scheduling.get_schedule!(schedule.id) end
    end

    test "change_schedule/1 returns a schedule changeset" do
      schedule = schedule_fixture()
      assert %Ecto.Changeset{} = Scheduling.change_schedule(schedule)
    end
  end

  describe "appointments" do
    alias App.Scheduling.Appointment

    import App.SchedulingFixtures

    @invalid_attrs %{notes: nil, scheduled_date: nil, scheduled_time: nil, status: nil}

    test "list_appointments/0 returns all appointments" do
      appointment = appointment_fixture()
      assert Scheduling.list_appointments() == [appointment]
    end

    test "get_appointment!/1 returns the appointment with given id" do
      appointment = appointment_fixture()
      assert Scheduling.get_appointment!(appointment.id) == appointment
    end

    test "create_appointment/1 with valid data creates a appointment" do
      valid_attrs = %{notes: "some notes", scheduled_date: ~D[2025-04-21], scheduled_time: ~T[14:00:00], status: "some status"}

      assert {:ok, %Appointment{} = appointment} = Scheduling.create_appointment(valid_attrs)
      assert appointment.notes == "some notes"
      assert appointment.scheduled_date == ~D[2025-04-21]
      assert appointment.scheduled_time == ~T[14:00:00]
      assert appointment.status == "some status"
    end

    test "create_appointment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Scheduling.create_appointment(@invalid_attrs)
    end

    test "update_appointment/2 with valid data updates the appointment" do
      appointment = appointment_fixture()
      update_attrs = %{notes: "some updated notes", scheduled_date: ~D[2025-04-22], scheduled_time: ~T[15:01:01], status: "some updated status"}

      assert {:ok, %Appointment{} = appointment} = Scheduling.update_appointment(appointment, update_attrs)
      assert appointment.notes == "some updated notes"
      assert appointment.scheduled_date == ~D[2025-04-22]
      assert appointment.scheduled_time == ~T[15:01:01]
      assert appointment.status == "some updated status"
    end

    test "update_appointment/2 with invalid data returns error changeset" do
      appointment = appointment_fixture()
      assert {:error, %Ecto.Changeset{}} = Scheduling.update_appointment(appointment, @invalid_attrs)
      assert appointment == Scheduling.get_appointment!(appointment.id)
    end

    test "delete_appointment/1 deletes the appointment" do
      appointment = appointment_fixture()
      assert {:ok, %Appointment{}} = Scheduling.delete_appointment(appointment)
      assert_raise Ecto.NoResultsError, fn -> Scheduling.get_appointment!(appointment.id) end
    end

    test "change_appointment/1 returns a appointment changeset" do
      appointment = appointment_fixture()
      assert %Ecto.Changeset{} = Scheduling.change_appointment(appointment)
    end
  end
end
