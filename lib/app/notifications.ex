defmodule App.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias App.Repo

  alias App.Notifications.NotificationPreference

  alias App.Accounts.User
  alias App.Scheduling.Appointment
  alias App.Notifications.NotificationPreference

  def schedule_appointment_reminders(appointment, user) do
    preference = get_user_preference(user.id)

    reminder_time = calculate_reminder_time(appointment, preference.reminder_hours)

    if preference.sms_enabled do
      schedule_sms_reminder(appointment, reminder_time)
    end

    if preference.email_enabled do
      schedule_email_reminder(appointment, reminder_time)
    end
  end

  def send_confirmation_notification(appointment) do
    appointment = Repo.preload(appointment, [child: :user])
    user = appointment.child.user
    preference = get_user_preference(user.id)

    if preference.sms_enabled do
      send_sms_confirmation(appointment, user)
    end

    if preference.email_enabled do
      send_email_confirmation(appointment, user)
    end
  end

  def send_cancellation_notification(appointment) do
    appointment = Repo.preload(appointment, [child: :user])
    user = appointment.child.user
    preference = get_user_preference(user.id)

    if preference.sms_enabled do
      send_sms_cancellation(appointment, user)
    end

    if preference.email_enabled do
      send_email_cancellation(appointment, user)
    end
  end

  # SMS notifications

  defp send_sms_confirmation(appointment, user) do
    message = """
    Your appointment for #{appointment.child.name} has been confirmed for #{Appointment.formatted_datetime(appointment)}.
    """

    send_sms(user.phone, message)
  end

  defp send_sms_cancellation(appointment, user) do
    message = """
    Your appointment for #{appointment.child.name} on #{Appointment.formatted_datetime(appointment)} has been cancelled.
    """

    send_sms(user.phone, message)
  end

  defp schedule_sms_reminder(appointment, reminder_time) do
    # This would integrate with a background job system like Oban
    # to schedule the reminder to be sent at the specified time
    :ok
  end

  defp send_sms(phone_number, message) do
    # This would integrate with an SMS service provider
    # For development, just log the message
    IO.puts("SMS to #{phone_number}: #{message}")
    {:ok, :sent}
  end

  # Email notifications

  defp send_email_confirmation(appointment, user) do
    subject = "Appointment Confirmed - #{appointment.child.name}"

    body = """
    Dear #{user.name},

    Your appointment for #{appointment.child.name} has been confirmed.

    Date: #{Date.to_string(appointment.scheduled_date)}
    Time: #{Time.to_string(appointment.scheduled_time)}
    Provider: #{appointment.provider.name}

    Please arrive 10 minutes before your scheduled time.

    Thank you,
    Under Five Health Check-Up Team
    """

    send_email(user.email, subject, body)
  end

  defp send_email_cancellation(appointment, user) do
    subject = "Appointment Cancelled - #{appointment.child.name}"

    body = """
    Dear #{user.name},

    Your appointment for #{appointment.child.name} on #{Appointment.formatted_datetime(appointment)} has been cancelled.

    Please visit our website to reschedule.

    Thank you,
    Under Five Health Check-Up Team
    """

    send_email(user.email, subject, body)
  end

  defp schedule_email_reminder(appointment, reminder_time) do
    # This would integrate with a background job system like Oban
    # to schedule the reminder to be sent at the specified time
    :ok
  end

  defp send_email(email_address, subject, body) do
    # This would integrate with an email service provider
    # For development, just log the email
    IO.puts("Email to #{email_address}: #{subject}\n#{body}")
    {:ok, :sent}
  end

  # Helper functions

  defp get_user_preference(user_id) do
    Repo.get_by(NotificationPreference, user_id: user_id) ||
      %NotificationPreference{
        sms_enabled: true,
        email_enabled: true,
        reminder_hours: 24
      }
  end

  defp calculate_reminder_time(appointment, hours_before) do
    datetime = DateTime.new!(appointment.scheduled_date, appointment.scheduled_time)
    DateTime.add(datetime, -hours_before * 3600, :second)
  end

  @doc """
  Returns the list of notification_preferences.

  ## Examples

      iex> list_notification_preferences()
      [%NotificationPreference{}, ...]

  """
  def list_notification_preferences do
    Repo.all(NotificationPreference)
  end

  @doc """
  Gets a single notification_preference.

  Raises `Ecto.NoResultsError` if the Notification preference does not exist.

  ## Examples

      iex> get_notification_preference!(123)
      %NotificationPreference{}

      iex> get_notification_preference!(456)
      ** (Ecto.NoResultsError)

  """
  def get_notification_preference!(id), do: Repo.get!(NotificationPreference, id)

  @doc """
  Creates a notification_preference.

  ## Examples

      iex> create_notification_preference(%{field: value})
      {:ok, %NotificationPreference{}}

      iex> create_notification_preference(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_notification_preference(attrs \\ %{}) do
    %NotificationPreference{}
    |> NotificationPreference.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notification_preference.

  ## Examples

      iex> update_notification_preference(notification_preference, %{field: new_value})
      {:ok, %NotificationPreference{}}

      iex> update_notification_preference(notification_preference, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_notification_preference(%NotificationPreference{} = notification_preference, attrs) do
    notification_preference
    |> NotificationPreference.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a notification_preference.

  ## Examples

      iex> delete_notification_preference(notification_preference)
      {:ok, %NotificationPreference{}}

      iex> delete_notification_preference(notification_preference)
      {:error, %Ecto.Changeset{}}

  """
  def delete_notification_preference(%NotificationPreference{} = notification_preference) do
    Repo.delete(notification_preference)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification_preference changes.

  ## Examples

      iex> change_notification_preference(notification_preference)
      %Ecto.Changeset{data: %NotificationPreference{}}

  """
  def change_notification_preference(%NotificationPreference{} = notification_preference, attrs \\ %{}) do
    NotificationPreference.changeset(notification_preference, attrs)
  end
end
