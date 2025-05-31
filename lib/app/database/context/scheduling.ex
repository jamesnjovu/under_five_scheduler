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
  def list_providers(opts \\ []) do
    base_query = from(
      p in Provider,
      order_by: [
        asc: p.name
      ]
    )

    query = Enum.reduce(
      opts,
      base_query,
      fn
        {:active_only, true}, query ->
          where(query, [p], p.is_active == true)

        {:include_inactive, true}, query ->
          query
        # Return all providers (active and inactive)

        {:specialization, spec}, query ->
          where(query, [p], p.specialization == ^spec)

        _, query ->
          query
      end
    )

    Repo.all(query)
  end

  def list_active_providers do
    list_providers(active_only: true)
  end

  def deactivate_provider(%Provider{} = provider) do
    provider
    |> Provider.changeset(%{is_active: false})
    |> Repo.update()
  end

  def reactivate_provider(%Provider{} = provider) do
    provider
    |> Provider.changeset(%{is_active: true})
    |> Repo.update()
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
    base_query = from(
      a in Appointment,
      order_by: [
        asc: a.scheduled_date,
        asc: a.scheduled_time
      ]
    )

    Enum.reduce(
      opts,
      base_query,
      fn
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
      end
    )
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
           # Preload associations needed for notifications
           appointment = Repo.preload(appointment, [child: :user, provider: []])

           # Log the creation action
           log_appointment_action(appointment, "created")

           # Send confirmation notification to the parent
           App.Notifications.send_confirmation_notification(appointment)

           # Schedule appointment reminders based on user preferences
           user = appointment.child.user
           App.Notifications.schedule_appointment_reminders(appointment, user)

           {:ok, appointment}

         error ->
           error
       end
  end

  def create_appointment_with_validation(attrs \\ %{}) do
    with {:ok, provider} <- validate_provider_active(attrs["provider_id"]),
         {:ok, appointment} <- create_appointment(attrs) do
      {:ok, appointment}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_provider_active(provider_id) when is_binary(provider_id) do
    validate_provider_active(String.to_integer(provider_id))
  end

  defp validate_provider_active(provider_id) when is_integer(provider_id) do
    case get_provider!(provider_id) do
      %Provider{is_active: true} = provider -> {:ok, provider}
      %Provider{is_active: false} -> {:error, "Provider is not currently active"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Provider not found"}
  end

  def get_provider_statistics do
    total_providers = Repo.aggregate(Provider, :count, :id)
    active_providers = Repo.aggregate(
      Provider,
      :count,
      :id,
      where: [
        is_active: true
      ]
    )
    inactive_providers = total_providers - active_providers

    # Group by specialization
    specialization_stats =
      from(
        p in Provider,
        where: p.is_active == true,
        group_by: p.specialization,
        select: {p.specialization, count(p.id)}
      )
      |> Repo.all()
      |> Enum.into(%{})

    %{
      total: total_providers,
      active: active_providers,
      inactive: inactive_providers,
      by_specialization: specialization_stats
    }
  end

  def notify_provider_status_change(provider, old_status, new_status) do
    # Cancel future appointments if provider becomes inactive
    if old_status == true && new_status == false do
      cancel_future_appointments_for_provider(provider.id)
    end

    # Send notification to admin users about status change
    admin_users = App.Accounts.list_users_by_role("admin")

    Enum.each(
      admin_users,
      fn admin ->
        # You could send email/SMS notification here
        # App.Notifications.send_provider_status_notification(admin, provider, new_status)
      end
    )
  end

  defp cancel_future_appointments_for_provider(provider_id) do
    today = Date.utc_today()

    # Get all future appointments for this provider
    future_appointments =
      from(
        a in Appointment,
        where: a.provider_id == ^provider_id,
        where: a.scheduled_date > ^today,
        where: a.status in ["scheduled", "confirmed"]
      )
      |> Repo.all()
      |> Repo.preload([child: :user])

    # Cancel each appointment and notify patients
    Enum.each(
      future_appointments,
      fn appointment ->
        # Update appointment status
        update_appointment(
          appointment,
          %{
            status: "cancelled",
            notes: "Appointment cancelled due to provider unavailability. Please reschedule."
          }
        )

        # Send cancellation notification
        App.Notifications.send_cancellation_notification(appointment)
      end
    )

    length(future_appointments)
  end

  def can_deactivate_provider?(provider_id) do
    today = Date.utc_today()

    # Check if provider has any upcoming appointments
    upcoming_count =
      from(
        a in Appointment,
        where: a.provider_id == ^provider_id,
        where: a.scheduled_date > ^today,
        where: a.status in ["scheduled", "confirmed"]
      )
      |> Repo.aggregate(:count, :id)

    # Provider can be deactivated if they have no upcoming appointments
    # Or admin can force deactivation (which will cancel appointments)
    %{
      can_deactivate: true, # Always allow, but warn about consequences
      upcoming_appointments: upcoming_count,
      warning: if(
        upcoming_count > 0,
        do: "This will cancel #{upcoming_count} upcoming appointments",
        else: nil
      )
    }
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
    # Store the original appointment data before updating
    original_date = appointment.scheduled_date
    original_time = appointment.scheduled_time
    original_status = appointment.status

    appointment
    |> Appointment.changeset(attrs)
    |> Repo.update()
    |> case do
         {:ok, updated_appointment} ->
           # Preload associations needed for notifications
           updated_appointment = Repo.preload(updated_appointment, [child: :user, provider: []])

           # Log the update action
           log_appointment_action(updated_appointment, "updated")

           # Handle status changes
           if updated_appointment.status != original_status do
             handle_status_change(updated_appointment, original_status)
           end

           # Handle date/time changes (rescheduling)
           if updated_appointment.scheduled_date != original_date ||
                updated_appointment.scheduled_time != original_time do
             # Notify about reschedule
             user = updated_appointment.child.user
             App.Notifications.send_reschedule_notification(updated_appointment, original_date, original_time)

             # Re-schedule reminders based on new date/time
             App.Notifications.schedule_appointment_reminders(updated_appointment, user)
           end

           # Broadcast to all subscribers
           Phoenix.PubSub.broadcast(
             App.PubSub,
             "appointments:updates",
             {:appointment_updated, updated_appointment}
           )

           # Also broadcast to dashboard for metric updates
           Phoenix.PubSub.broadcast(App.PubSub, "dashboard:updates", {:stats_updated})
           {:ok, updated_appointment}

         error ->
           error
       end
  end

  defp handle_status_change(appointment, old_status) do
    appointment = Repo.preload(appointment, [child: :user, provider: []])
    user = appointment.child.user

    case {old_status, appointment.status} do
      {_, "cancelled"} ->
        App.Notifications.send_cancellation_notification(appointment)

        # Send push notification if enabled
        preference = App.Notifications.get_notification_preference(user.id)
        if preference.push_enabled do
          App.Notifications.send_push_notification(
            user.id,
            "Appointment Cancelled",
            "Your appointment for #{appointment.child.name} on #{format_date_time(appointment)} has been cancelled."
          )
        end

      {"scheduled", "confirmed"} ->
        App.Notifications.send_confirmation_notification(appointment)

        # Send push notification if enabled
        preference = App.Notifications.get_notification_preference(user.id)
        if preference.push_enabled do
          App.Notifications.send_push_notification(
            user.id,
            "Appointment Confirmed",
            "Your appointment for #{appointment.child.name} on #{format_date_time(appointment)} has been confirmed."
          )
        end

      {_, "rescheduled"} ->
        schedule_appointment_notifications(appointment)

      _ ->
        :ok
    end
  end

  def get_available_slots(provider_id, date) do
    provider = get_provider!(provider_id)

    # Only return slots if provider is active
    if provider.is_active do
      day_of_week = Date.day_of_week(date)
      schedule = get_provider_schedule(provider_id, day_of_week)

      case schedule do
        nil ->
          []

        schedule ->
          existing_appointments = list_appointments(provider_id: provider_id, date: date)
          generate_available_slots(schedule, existing_appointments)
      end
    else
      # Return empty list for inactive providers
      []
    end
  end

  defp generate_available_slots(schedule, existing_appointments) do
    # Generate 30-minute slots from provider's schedule
    start_time = schedule.start_time
    end_time = schedule.end_time

    # Get existing appointment times
    booked_times = Enum.map(existing_appointments, &(&1.scheduled_time))

    # Calculate slot interval in minutes
    slot_interval = 30

    # Convert times to minutes for easier calculation
    start_minutes = time_to_minutes(start_time)
    end_minutes = time_to_minutes(end_time)

    # Generate possible slots
    start_minutes
    start_minutes
    |> Stream.iterate(&(&1 + slot_interval))
    |> Enum.take_while(&(&1 < end_minutes - slot_interval)) # Ensure slots fit within schedule
    |> Enum.map(&minutes_to_time/1)
    |> Enum.filter(
         fn slot_time ->
           # Only include slots that aren't already booked
           not Enum.member?(booked_times, slot_time)
         end
       )
  end

  # Helper to convert Time to minutes since midnight
  defp time_to_minutes(time) do
    time.hour * 60 + time.minute
  end

  # Helper to convert minutes since midnight to Time
  defp minutes_to_time(minutes) do
    hours = div(minutes, 60)
    mins = rem(minutes, 60)
    Time.new!(hours, mins, 0)
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
    |> AppointmentLog.changeset(
         %{
           appointment_id: appointment.id,
           action: action,
           timestamp: DateTime.utc_now()
         }
       )
    |> Repo.insert()
  end

  defp schedule_appointment_notifications(appointment) do
    appointment = Repo.preload(appointment, child: :user)
    user = appointment.child.user

    # Schedule reminder notifications based on user preferences
    Notifications.schedule_appointment_reminders(appointment, user)
  end

  # Utility functions
  def upcoming_appointments(child_id) do
    today = Date.utc_today()

    from(
      a in Appointment,
      where: a.child_id == ^child_id,
      where: a.scheduled_date >= ^today,
      where: a.status in ["scheduled", "confirmed"],
      order_by: [
        asc: a.scheduled_date,
        asc: a.scheduled_time
      ],
      limit: 5
    )
    |> Repo.all()
    |> Repo.preload([:provider, :child])
  end

  def past_appointments(child_id) do
    today = Date.utc_today()

    from(
      a in Appointment,
      where: a.child_id == ^child_id,
      where: a.scheduled_date < ^today,
      order_by: [
        desc: a.scheduled_date,
        desc: a.scheduled_time
      ],
      limit: 10
    )
    |> Repo.all()
    |> Repo.preload([:provider])
  end

  def provider_appointments_for_date(provider_id, date) do
    provider = get_provider!(provider_id)

    if provider.is_active do
      from(a in Appointment,
        where: a.provider_id == ^provider_id,
        where: a.scheduled_date == ^date,
        where: a.status in ["scheduled", "confirmed"],
        order_by: [asc: a.scheduled_time]
      )
      |> Repo.all()
      |> Repo.preload([:child])
    else
      []
    end
  end

  def search_providers(search_term, opts \\ []) do
    active_only = Keyword.get(opts, :active_only, false)

    base_query =
      from(p in Provider,
        where: ilike(p.name, ^"%#{search_term}%"),
        order_by: [asc: p.name]
      )

    query = if active_only do
      where(base_query, [p], p.is_active == true)
    else
      base_query
    end

    Repo.all(query)
  end

  def check_appointment_conflicts(provider_id, date, time, exclude_appointment_id \\ nil) do
    query =
      from(
        a in Appointment,
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
    from(
      a in Appointment,
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

  defp format_date_time(appointment) do
    "#{format_date(appointment.scheduled_date)} at #{format_time(appointment.scheduled_time)}"
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end

  @doc """
  Checks if a provider can access and modify health records for a specific appointment.
  Returns true if:
  - The appointment belongs to the provider
  - The appointment is scheduled for today
  - The appointment status allows modifications (scheduled, confirmed, in_progress)
  """
  def can_provider_modify_health_records?(provider_id, appointment_id) do
    case get_appointment!(appointment_id) do
      %Appointment{provider_id: ^provider_id, scheduled_date: scheduled_date, status: status} ->
        today = Date.utc_today()
        Date.compare(scheduled_date, today) == :eq and
        status in ["scheduled", "confirmed", "in_progress"]

      _ ->
        false
    end
  rescue
    Ecto.NoResultsError -> false
  end

  @doc """
  Gets all appointments for a provider that are eligible for health record updates.
  These are appointments that are:
  - Scheduled for today
  - Have status of scheduled, confirmed, or in_progress
  """
  def list_provider_active_appointments(provider_id) do
    today = Date.utc_today()

    from(
      a in Appointment,
      where: a.provider_id == ^provider_id,
      where: a.scheduled_date == ^today,
      where: a.status in ["scheduled", "confirmed", "in_progress"],
      order_by: [
        asc: a.scheduled_time
      ]
    )
    |> Repo.all()
    |> Repo.preload([:child, :provider])
  end

  @doc """
  Updates appointment status to "in_progress" when provider starts the health check.
  Also logs the action for audit purposes.
  """
  def start_appointment(appointment) do
    with {:ok, updated_appointment} <-
           update_appointment(appointment, %{status: "in_progress"}) do

      # Log the action
      log_appointment_action(updated_appointment, "started")

      # Broadcast update
      Phoenix.PubSub.broadcast(
        App.PubSub,
        "appointments:updates",
        {:appointment_started, updated_appointment}
      )

      {:ok, updated_appointment}
    end
  end

  @doc """
  Completes an appointment and finalizes health records.
  Sets status to "completed" and ensures all records are properly saved.
  """
  def complete_appointment(appointment, final_notes \\ nil) do
    attrs = %{status: "completed"}
    attrs = if final_notes, do: Map.put(attrs, :notes, final_notes), else: attrs

    with {:ok, updated_appointment} <- update_appointment(appointment, attrs) do
      # Log the completion
      log_appointment_action(updated_appointment, "completed")

      # Broadcast completion
      Phoenix.PubSub.broadcast(
        App.PubSub,
        "appointments:updates",
        {:appointment_completed, updated_appointment}
      )

      # Trigger any post-appointment workflows (e.g., follow-up scheduling)
      schedule_follow_up_if_needed(updated_appointment)

      {:ok, updated_appointment}
    end
  end

  @doc """
  Gets appointment with full health context including growth and immunization records.
  """
  def get_appointment_with_health_context!(id) do
    appointment = get_appointment!(id)
    child = App.Accounts.get_child!(appointment.child_id)

    # Preload all health-related data
    child_with_health =
      child
      |> Repo.preload(
           [
             :growth_records,
             :immunization_records
           ]
         )

    # Attach health data to appointment
    Map.put(appointment, :child_health_data, child_with_health)
  end

  @doc """
  Determines if follow-up appointment should be scheduled based on child's age and last visit.
  """
  defp schedule_follow_up_if_needed(appointment) do
    child = App.Accounts.get_child!(appointment.child_id)
    age_months = App.Accounts.Child.age_in_months(child)

    # Follow-up scheduling logic based on WHO guidelines
    follow_up_months = case age_months do
      months when months < 6 -> 2
      # Every 2 months for under 6 months
      months when months < 12 -> 3
      # Every 3 months for 6-12 months
      months when months < 24 -> 6
      # Every 6 months for 1-2 years
      _ -> 12                       # Yearly for 2-5 years
    end

    # Create a reminder or suggestion for the next appointment
    suggested_date = Date.add(appointment.scheduled_date, follow_up_months * 30)

    # You could implement automatic scheduling or just create a reminder
    create_follow_up_reminder(appointment, suggested_date)
  end

  defp create_follow_up_reminder(appointment, suggested_date) do
    # This could be implemented to create a follow-up reminder
    # For now, we'll just log it
    require Logger
    Logger.info("Follow-up recommended for child #{appointment.child_id} on #{suggested_date}")
  end

  @doc """
  Gets statistics for completed appointments with health record updates.
  Useful for provider dashboard and reporting.
  """
  def get_provider_health_activity_stats(provider_id, date_range \\ nil) do
    {start_date, end_date} = date_range || {Date.add(Date.utc_today(), -30), Date.utc_today()}

    # Get completed appointments in date range
    completed_appointments =
      from(
        a in Appointment,
        where: a.provider_id == ^provider_id,
        where: a.status == "completed",
        where: a.scheduled_date >= ^start_date and a.scheduled_date <= ^end_date,
        select: a.child_id
      )
      |> Repo.all()
      |> Enum.uniq()

    # Count health records created during this period
    growth_records_count =
      from(
        g in App.HealthRecords.Growth,
        where: g.child_id in ^completed_appointments,
        where: g.measurement_date >= ^start_date and g.measurement_date <= ^end_date
      )
      |> Repo.aggregate(:count, :id)

    immunizations_administered =
      from(
        i in App.HealthRecords.Immunization,
        where: i.child_id in ^completed_appointments,
        where: i.status == "administered",
        where: i.administered_date >= ^start_date and i.administered_date <= ^end_date
      )
      |> Repo.aggregate(:count, :id)

    %{
      completed_appointments: length(completed_appointments),
      unique_children_seen: length(completed_appointments),
      growth_records_added: growth_records_count,
      immunizations_administered: immunizations_administered,
      period: {start_date, end_date}
    }
  end

  @doc """
  Validates that an appointment can be modified based on current status and timing.
  """
  def validate_appointment_modification(appointment) do
    cond do
      appointment.status not in ["scheduled", "confirmed", "in_progress"] ->
        {:error, "Appointment cannot be modified in current status: #{appointment.status}"}

      Date.compare(appointment.scheduled_date, Date.utc_today()) == :lt ->
        {:error, "Cannot modify past appointments"}

      appointment.status == "completed" ->
        {:error, "Completed appointments cannot be modified"}

      true ->
        {:ok, appointment}
    end
  end

  @doc """
  Gets appointment summary for health record context.
  Includes previous visits and health trends.
  """
  def get_appointment_health_summary(appointment_id) do
    appointment = get_appointment!(appointment_id)
    child_id = appointment.child_id

    # Get previous appointments for this child
    previous_appointments =
      from(
        a in Appointment,
        where: a.child_id == ^child_id,
        where: a.id != ^appointment_id,
        where: a.status == "completed",
        order_by: [
          desc: a.scheduled_date
        ],
        limit: 5
      )
      |> Repo.all()
      |> Repo.preload([:provider])

    # Get recent health records
    recent_growth = App.HealthRecords.list_growth_records(child_id)
                    |> Enum.take(3)
    recent_immunizations =
      from(
        i in App.HealthRecords.Immunization,
        where: i.child_id == ^child_id,
        where: i.status == "administered",
        order_by: [
          desc: i.administered_date
        ],
        limit: 5
      )
      |> Repo.all()

    %{
      current_appointment: appointment,
      previous_appointments: previous_appointments,
      recent_growth_records: recent_growth,
      recent_immunizations: recent_immunizations,
      health_trends: calculate_health_trends(recent_growth)
    }
  end

  defp calculate_health_trends(growth_records) when length(growth_records) >= 2 do
    [latest, previous | _] = growth_records

    weight_trend =
      if latest.weight && previous.weight do
        calculate_percentage_change(previous.weight, latest.weight)
      else
        nil
      end

    height_trend =
      if latest.height && previous.height do
        calculate_percentage_change(previous.height, latest.height)
      else
        nil
      end

    %{
      weight_trend: weight_trend,
      height_trend: height_trend,
      trend_period: Date.diff(latest.measurement_date, previous.measurement_date)
    }
  end

  defp calculate_health_trends(_), do: %{weight_trend: nil, height_trend: nil, trend_period: nil}

  defp calculate_percentage_change(old_value, new_value) do
    if Decimal.compare(old_value, Decimal.new(0)) == :gt do
      Decimal.sub(new_value, old_value)
      |> Decimal.div(old_value)
      |> Decimal.mult(Decimal.new(100))
      |> Decimal.round(1)
    else
      nil
    end
  end
end
