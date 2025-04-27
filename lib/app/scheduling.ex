defmodule App.Scheduling do
  @moduledoc """
  The Scheduling context.
  """

  import Ecto.Query, warn: false
  alias App.Repo

  alias App.Scheduling.{Appointment, Provider, Schedule}
  alias App.Analytics.AppointmentLog
  alias App.Notifications

  # Provider functions

  @doc """
  Returns the list of providers.

  ## Examples

      iex> list_providers()
      [%Provider{}, ...]

  """
  def list_providers do
    Provider
    |> order_by(asc: :name)
    |> Repo.all()
  end

  @doc """
  Gets a single provider.

  Raises `Ecto.NoResultsError` if the Provider does not exist.

  ## Examples

      iex> get_provider!(123)
      %Provider{}

      iex> get_provider!(456)
      ** (Ecto.NoResultsError)

  """
  def get_provider!(id) do
    Provider
    |> where(id: ^id)
    |> limit(1)
    |> Repo.one()
  end

  def get_provider_by_user_id(user_id) do
    Repo.get_by(Provider, user_id: user_id)
  end

  @doc """
  Creates a provider.

  ## Examples

      iex> create_provider(%{field: value})
      {:ok, %Provider{}}

      iex> create_provider(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_provider(attrs \\ %{}) do
    %Provider{}
    |> Provider.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a provider.

  ## Examples

      iex> update_provider(provider, %{field: new_value})
      {:ok, %Provider{}}

      iex> update_provider(provider, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_provider(%Provider{} = provider, attrs) do
    provider
    |> Provider.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a provider.

  ## Examples

      iex> delete_provider(provider)
      {:ok, %Provider{}}

      iex> delete_provider(provider)
      {:error, %Ecto.Changeset{}}

  """
  def delete_provider(%Provider{} = provider) do
    Repo.delete(provider)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking provider changes.

  ## Examples

      iex> change_provider(provider)
      %Ecto.Changeset{data: %Provider{}}

  """
  def change_provider(%Provider{} = provider, attrs \\ %{}) do
    Provider.changeset(provider, attrs)
  end

  @doc """
  Returns the list of schedules.

  ## Examples

      iex> list_schedules()
      [%Schedule{}, ...]

  """
  def list_schedules do
    Repo.all(Schedule)
  end

  @doc """
  Gets a single schedule.

  Raises `Ecto.NoResultsError` if the Schedule does not exist.

  ## Examples

      iex> get_schedule!(123)
      %Schedule{}

      iex> get_schedule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_schedule!(id), do: Repo.get!(Schedule, id)

  # Schedule functions

  def get_provider_schedule(provider_id, day_of_week) do
    Schedule
    |> where(provider_id: ^provider_id, day_of_week: ^day_of_week)
    |> Repo.one()
  end

  @doc """
  Creates a schedule.

  ## Examples

      iex> create_schedule(%{field: value})
      {:ok, %Schedule{}}

      iex> create_schedule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_schedule(provider, attrs \\ %{}) do
    %Schedule{}
    |> Schedule.changeset(Map.put(attrs, "provider_id", provider.id))
    |> Repo.insert()
  end

  @doc """
  Updates a schedule.

  ## Examples

      iex> update_schedule(schedule, %{field: new_value})
      {:ok, %Schedule{}}

      iex> update_schedule(schedule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_schedule(%Schedule{} = schedule, attrs) do
    schedule
    |> Schedule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a schedule.

  ## Examples

      iex> delete_schedule(schedule)
      {:ok, %Schedule{}}

      iex> delete_schedule(schedule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_schedule(%Schedule{} = schedule) do
    Repo.delete(schedule)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking schedule changes.

  ## Examples

      iex> change_schedule(schedule)
      %Ecto.Changeset{data: %Schedule{}}

  """
  def change_schedule(%Schedule{} = schedule, attrs \\ %{}) do
    Schedule.changeset(schedule, attrs)
  end

  # Appointment functions

  @doc """
  Returns the list of appointments.

  ## Examples

      iex> list_appointments()
      [%Appointment{}, ...]

  """
  def list_appointments(opts \\ []) do
    base_query = from(a in Appointment, order_by: [asc: a.scheduled_date, asc: a.scheduled_time])

    Enum.reduce(opts, base_query, fn
      {:child_id, child_id}, query ->
        where(query, [a], a.child_id == ^child_id)

      {:provider_id, provider_id}, query ->
        where(query, [a], a.provider_id == ^provider_id)

      {:status, status}, query ->
        where(query, [a], a.status == ^status)

      {:date, date}, query ->
        where(query, [a], a.scheduled_date == ^date)

      _, query ->
        query
    end)
    |> Repo.all()
    |> Repo.preload([:child, :provider])
  end

  @doc """
  Gets a single appointment.

  Raises `Ecto.NoResultsError` if the Appointment does not exist.

  ## Examples

      iex> get_appointment!(123)
      %Appointment{}

      iex> get_appointment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_appointment!(id) do
    Appointment
    |> Repo.get!(id)
    |> Repo.preload([:child, :provider])
  end

  @doc """
  Creates a appointment.

  ## Examples

      iex> create_appointment(%{field: value})
      {:ok, %Appointment{}}

      iex> create_appointment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_appointment(attrs \\ %{}) do
    %Appointment{}
    |> Appointment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, appointment} ->
        appointment = Repo.preload(appointment, [:child, :provider])
        log_appointment_action(appointment, "created")
        schedule_appointment_notifications(appointment)
        {:ok, appointment}

      error ->
        error
    end
  end

  @doc """
  Updates a appointment.

  ## Examples

      iex> update_appointment(appointment, %{field: new_value})
      {:ok, %Appointment{}}

      iex> update_appointment(appointment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_appointment(%Appointment{} = appointment, attrs) do
    appointment
    |> Appointment.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_appointment} ->
        log_appointment_action(updated_appointment, "updated")

        if updated_appointment.status != appointment.status do
          handle_status_change(updated_appointment, appointment.status)
        end

        {:ok, updated_appointment}

      error ->
        error
    end
  end

  defp handle_status_change(appointment, old_status) do
    case {old_status, appointment.status} do
      {_, "cancelled"} ->
        Notifications.send_cancellation_notification(appointment)

      {"scheduled", "confirmed"} ->
        Notifications.send_confirmation_notification(appointment)

      {_, "rescheduled"} ->
        schedule_appointment_notifications(appointment)

      _ ->
        :ok
    end
  end

  def get_available_slots(provider_id, date) do
    provider = get_provider!(provider_id)
    day_of_week = Date.day_of_week(date)
    schedule = get_provider_schedule(provider_id, day_of_week)

    case schedule do
      nil ->
        []

      schedule ->
        existing_appointments = list_appointments(provider_id: provider_id, date: date)
        generate_available_slots(schedule, existing_appointments)
    end
  end

  defp generate_available_slots(schedule, existing_appointments) do
    # Generate 30-minute slots from provider's schedule
    start_time = schedule.start_time
    end_time = schedule.end_time

    # This would generate all possible 30-minute slots and filter out
    # those that already have appointments
    # Placeholder - implement actual slot generation logic
    []
  end

  @doc """
  Deletes a appointment.

  ## Examples

      iex> delete_appointment(appointment)
      {:ok, %Appointment{}}

      iex> delete_appointment(appointment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_appointment(%Appointment{} = appointment) do
    Repo.delete(appointment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking appointment changes.

  ## Examples

      iex> change_appointment(appointment)
      %Ecto.Changeset{data: %Appointment{}}

  """
  def change_appointment(%Appointment{} = appointment, attrs \\ %{}) do
    Appointment.changeset(appointment, attrs)
  end

  # Logging functions

  defp log_appointment_action(appointment, action) do
    %AppointmentLog{}
    |> AppointmentLog.changeset(%{
      appointment_id: appointment.id,
      action: action,
      timestamp: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp schedule_appointment_notifications(appointment) do
    appointment = Repo.preload(appointment, child: :user)
    IO.inspect(appointment)
    user = appointment.child.user

    # Schedule reminder notifications based on user preferences
    Notifications.schedule_appointment_reminders(appointment, user)
  end

  # Utility functions
  def upcoming_appointments(child_id) do
    today = Date.utc_today()

    from(a in Appointment,
      where: a.child_id == ^child_id,
      where: a.scheduled_date >= ^today,
      where: a.status in ["scheduled", "confirmed"],
      order_by: [asc: a.scheduled_date, asc: a.scheduled_time],
      limit: 5
    )
    |> Repo.all()
    |> Repo.preload([:provider])
  end

  def past_appointments(child_id) do
    today = Date.utc_today()

    from(a in Appointment,
      where: a.child_id == ^child_id,
      where: a.scheduled_date < ^today,
      order_by: [desc: a.scheduled_date, desc: a.scheduled_time],
      limit: 10
    )
    |> Repo.all()
    |> Repo.preload([:provider])
  end

  def provider_appointments_for_date(provider_id, date) do
    from(a in Appointment,
      where: a.provider_id == ^provider_id,
      where: a.scheduled_date == ^date,
      where: a.status in ["scheduled", "confirmed"],
      order_by: [asc: a.scheduled_time]
    )
    |> Repo.all()
    |> Repo.preload([:child])
  end

  def check_appointment_conflicts(provider_id, date, time, exclude_appointment_id \\ nil) do
    query =
      from(a in Appointment,
        where: a.provider_id == ^provider_id,
        where: a.scheduled_date == ^date,
        where: a.scheduled_time == ^time,
        where: a.status in ["scheduled", "confirmed"]
      )

    query =
      if exclude_appointment_id do
        where(query, [a], a.id != ^exclude_appointment_id)
      else
        query
      end

    Repo.exists?(query)
  end

  # Analytics functions

  def appointment_statistics(provider_id, start_date, end_date) do
    from(a in Appointment,
      where: a.provider_id == ^provider_id,
      where: a.scheduled_date >= ^start_date,
      where: a.scheduled_date <= ^end_date,
      group_by: a.status,
      select: {a.status, count(a.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  def missed_appointments_rate(provider_id, start_date, end_date) do
    stats = appointment_statistics(provider_id, start_date, end_date)
    total = Enum.sum(Map.values(stats))
    no_shows = Map.get(stats, "no_show", 0)

    if total > 0 do
      Float.round(no_shows / total * 100, 1)
    else
      0.0
    end
  end
end
