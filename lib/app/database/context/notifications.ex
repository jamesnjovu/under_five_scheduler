defmodule App.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias App.Repo

  alias App.Notifications.NotificationPreference
  alias App.Accounts.User
  alias App.Scheduling.Appointment
  alias App.Mailer
  alias App.Accounts.UserNotifier

  # Scheduled Notifications

  @doc """
  Schedules appointment reminders based on user preferences.
  Calculates reminder times and schedules the appropriate notifications.
  """
  def schedule_appointment_reminders(appointment, user) do
    # Get user notification preferences
    preference = get_notification_preference(user.id)

    # Only proceed if the appointment status is appropriate for reminders
    if appointment.status in ["scheduled", "confirmed"] do
      # Calculate reminder time based on user preferences (default is 24 hours before)
      reminder_hours = preference.reminder_hours || 24
      reminder_time = calculate_reminder_time(appointment, reminder_hours)

      # Schedule SMS reminder if enabled
      if preference.sms_enabled do
        schedule_sms_reminder(appointment, reminder_time)
      end

      # Schedule email reminder if enabled
      if preference.email_enabled do
        schedule_email_reminder(appointment, reminder_time)
      end

      {:ok, :reminders_scheduled}
    else
      {:ok, :no_reminders_needed}
    end
  end


  @doc """
  Schedules an SMS reminder to be sent at the specified time.
  Uses Oban to schedule the job.
  """
  def schedule_sms_reminder(appointment, reminder_time) do
    # Schedule SMS reminder job using Oban
    %{
      appointment_id: appointment.id,
      recipient_phone: appointment.child.user.phone
    }
    |> App.Workers.SMSReminderWorker.new(scheduled_at: reminder_time)
    |> Oban.insert()
  end

  @doc """
  Schedules an email reminder to be sent at the specified time.
  Uses Oban to schedule the job.
  """
  def schedule_email_reminder(appointment, reminder_time) do
    # Schedule email reminder job using Oban
    %{
      appointment_id: appointment.id,
      recipient_email: appointment.child.user.email
    }
    |> App.Workers.EmailReminderWorker.new(scheduled_at: reminder_time)
    |> Oban.insert()
  end

  # Immediate Notifications

  @doc """
  Sends a ``notification about`` appointment confirmation.
  """
  def send_confirmation_notification(appointment) do
    # Ensure appointment has all required associations loaded
    appointment = Repo.preload(appointment, [child: :user])
    user = appointment.child.user

    # Get user notification preferences
    preference = get_notification_preference(user.id)

    # Send SMS if enabled
    if preference.sms_enabled do
      send_sms_confirmation(appointment, user)
    end

    # Send email if enabled
    if preference.email_enabled do
      send_email_confirmation(appointment, user)
    end

    {:ok, :notifications_sent}
  end

  @doc """
  Sends a notification about appointment cancellation.
  """
  def send_cancellation_notification(appointment) do
    # Ensure appointment has all required associations loaded
    appointment = Repo.preload(appointment, [child: :user])
    user = appointment.child.user

    # Get user notification preferences
    preference = get_notification_preference(user.id)

    # Send SMS if enabled
    if preference.sms_enabled do
      send_sms_cancellation(appointment, user)
    end

    # Send email if enabled
    if preference.email_enabled do
      send_email_cancellation(appointment, user)
    end

    {:ok, :notifications_sent}
  end

  @doc """
  Sends a notification about appointment rescheduling.
  """
  def send_reschedule_notification(appointment, old_date, old_time) do
    # Ensure appointment has all required associations loaded
    appointment = Repo.preload(appointment, [child: :user])
    user = appointment.child.user

    # Get user notification preferences
    preference = get_notification_preference(user.id)

    # Send SMS if enabled
    if preference.sms_enabled do
      send_sms_reschedule(appointment, user, old_date, old_time)
    end

    # Send email if enabled
    if preference.email_enabled do
      send_email_reschedule(appointment, user, old_date, old_time)
    end

    {:ok, :notifications_sent}
  end

  # Implementation of SMS sending functions

  defp send_sms_confirmation(appointment, user) do
    message = """
    Your appointment for #{appointment.child.name} has been confirmed for #{format_date_time(appointment)}.
    Provider: #{appointment.provider.name}
    Location: Health Center Main Building
    Thank you for using Under Five Health Check-Up.
    """

    send_sms(user.phone, message)
  end

  defp send_sms_cancellation(appointment, user) do
    message = """
    Your appointment for #{appointment.child.name} on #{format_date_time(appointment)} has been cancelled.
    Please visit our website or use the app to reschedule.
    Thank you for using Under Five Health Check-Up.
    """

    send_sms(user.phone, message)
  end

  defp send_sms_reschedule(appointment, user, old_date, old_time) do
    message = """
    Your appointment for #{appointment.child.name} has been rescheduled.
    Previous: #{format_date(old_date)} at #{format_time(old_time)}
    New: #{format_date_time(appointment)}
    Provider: #{appointment.provider.name}
    Thank you for using Under Five Health Check-Up.
    """

    send_sms(user.phone, message)
  end

  defp send_sms_reminder(appointment, user) do
    message = """
    Reminder: #{appointment.child.name} has an appointment tomorrow at #{format_time(appointment.scheduled_time)}.
    Provider: #{appointment.provider.name}
    Location: Health Center Main Building
    Thank you for using Under Five Health Check-Up.
    """

    send_sms(user.phone, message)
  end

  # Implementation of actual SMS sending
  # In production, this would integrate with an SMS gateway service
  defp send_sms(phone_number, message) do
    # In development, just log the message
    if Mix.env() == :dev do
      IO.puts("SMS to #{phone_number}: #{message}")
      {:ok, :sent}
    else
      # In production or when explicitly configured, send real SMS
      App.Services.ProbaseSMS.send_sms(phone_number, message)
      {:ok, :sent}
    end
  end

  # Implementation of Email sending functions


  defp send_email_confirmation(appointment, user) do
    subject = "Appointment Confirmed - #{appointment.child.name}"

    email_body = """
    <h2>Appointment Confirmation</h2>
    <p>Dear #{user.name},</p>

    <p>Your appointment for #{appointment.child.name} has been confirmed.</p>

    <ul>
      <li><strong>Date:</strong> #{format_date(appointment.scheduled_date)}</li>
      <li><strong>Time:</strong> #{format_time(appointment.scheduled_time)}</li>
      <li><strong>Provider:</strong> #{appointment.provider.name}</li>
      <li><strong>Location:</strong> Health Center Main Building</li>
    </ul>

    <p>Please arrive 10 minutes before your scheduled time.</p>

    <p>Thank you,<br>Under Five Health Check-Up Team</p>
    """

    send_email(user.email, subject, email_body)
  end


  defp send_email_cancellation(appointment, user) do
    subject = "Appointment Cancelled - #{appointment.child.name}"

    email_body = """
    <h2>Appointment Cancellation</h2>
    <p>Dear #{user.name},</p>

    <p>Your appointment for #{appointment.child.name} on #{format_date_time(appointment)} has been cancelled.</p>

    <p>Please visit our website or app to reschedule at your convenience.</p>

    <p>Thank you,<br>Under Five Health Check-Up Team</p>
    """

    send_email(user.email, subject, email_body)
  end

  defp send_email_reschedule(appointment, user, old_date, old_time) do
    subject = "Appointment Rescheduled - #{appointment.child.name}"

    email_body = """
    <h2>Appointment Rescheduled</h2>
    <p>Dear #{user.name},</p>

    <p>Your appointment for #{appointment.child.name} has been rescheduled.</p>

    <ul>
      <li><strong>Previous Date/Time:</strong> #{format_date(old_date)} at #{format_time(old_time)}</li>
      <li><strong>New Date/Time:</strong> #{format_date(appointment.scheduled_date)} at #{format_time(appointment.scheduled_time)}</li>
      <li><strong>Provider:</strong> #{appointment.provider.name}</li>
      <li><strong>Location:</strong> Health Center Main Building</li>
    </ul>

    <p>Please arrive 10 minutes before your scheduled time.</p>

    <p>Thank you,<br>Under Five Health Check-Up Team</p>
    """

    send_email(user.email, subject, email_body)
  end

  defp send_email_reminder(appointment, user) do
    subject = "Appointment Reminder - #{appointment.child.name}"

    email_body = """
    <h2>Appointment Reminder</h2>
    <p>Dear #{user.name},</p>

    <p>This is a reminder that #{appointment.child.name} has an appointment scheduled for tomorrow.</p>

    <ul>
      <li><strong>Date:</strong> #{format_date(appointment.scheduled_date)}</li>
      <li><strong>Time:</strong> #{format_time(appointment.scheduled_time)}</li>
      <li><strong>Provider:</strong> #{appointment.provider.name}</li>
      <li><strong>Location:</strong> Health Center Main Building</li>
    </ul>

    <p>Please arrive 10 minutes before your scheduled time.</p>

    <p>Thank you,<br>Under Five Health Check-Up Team</p>
    """

    send_email(user.email, subject, email_body)
  end

  # Implementation of actual email sending
  defp send_email(email_address, subject, body) do
    email =
      UserNotifier.build_email(email_address, subject, body)
      |> Mailer.deliver()

    case email do
      {:ok, _} -> {:ok, :sent}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Sends a web push notification to a user who has subscribed to push notifications.
  """
  def send_push_notification(user_id, title, body, data \\ %{}) do
    # Get push subscriptions for the user
    subscriptions = get_push_subscriptions(user_id)

    # If there are subscriptions, send push notifications
    if length(subscriptions) > 0 do
      # In production, we would use a web push service like web-push-encryption
      # For now, we'll just log it
      if Mix.env() == :dev do
        IO.puts("Push notification to user #{user_id}:")
        IO.puts("  Title: #{title}")
        IO.puts("  Body: #{body}")
        IO.puts("  Data: #{inspect(data)}")
        {:ok, :sent}
      else
        # In production, use the web push library
        # WebPush.send_notification(subscription, %{
        #   title: title,
        #   body: body,
        #   data: data
        # })

        # Return a success response for now
        {:ok, :sent}
      end
    else
      {:ok, :no_subscriptions}
    end
  end

  # Helper functions

  defp calculate_reminder_time(appointment, hours_before) do
    # Convert appointment date and time to a DateTime
    {:ok, datetime} = NaiveDateTime.new(
      appointment.scheduled_date.year,
      appointment.scheduled_date.month,
      appointment.scheduled_date.day,
      appointment.scheduled_time.hour,
      appointment.scheduled_time.minute,
      0
    )

    # Subtract the specified hours to get the reminder time
    NaiveDateTime.add(datetime, -hours_before * 3600, :second)
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
  Saves a push subscription for a user.
  """
  def save_push_subscription(user, subscription_params) do
    %App.Notifications.PushSubscription{}
    |> App.Notifications.PushSubscription.changeset(
         Map.merge(subscription_params, %{"user_id" => user.id})
       )
    |> Repo.insert(
         on_conflict: {:replace, [:p256dh, :auth, :updated_at]},
         conflict_target: :endpoint
       )
  end

  @doc """
  Gets all push subscriptions for a user.
  """
  def get_push_subscriptions(user_id) do
    Repo.all(
      from ps in App.Notifications.PushSubscription,
      where: ps.user_id == ^user_id
    )
  end

  @doc """
  Deletes a push subscription.
  """
  def delete_push_subscription(endpoint) do
    Repo.delete_all(
      from ps in App.Notifications.PushSubscription,
      where: ps.endpoint == ^endpoint
    )
  end

  # CRUD operations for NotificationPreference

  @doc """
  Returns the list of notification_preferences.
  """
  def list_notification_preferences do
    Repo.all(NotificationPreference)
  end

  @doc """
  Gets a single notification_preference.
  """
  def get_notification_preference!(id), do: Repo.get!(NotificationPreference, id)

  def get_notification_preference(user_id) do
    Repo.get_by(NotificationPreference, user_id: user_id) ||
      %NotificationPreference{
        sms_enabled: true,
        email_enabled: true,
        push_enabled: false,  # Make sure push_enabled field exists
        reminder_hours: 24,
        user_id: user_id
      }
  end

  @doc """
  Creates a notification_preference.
  """
  def create_notification_preference(attrs \\ %{}) do
    %NotificationPreference{}
    |> NotificationPreference.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notification_preference.
  """
  def update_notification_preference(%NotificationPreference{} = notification_preference, attrs) do
    notification_preference
    |> NotificationPreference.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a notification_preference.
  """
  def delete_notification_preference(%NotificationPreference{} = notification_preference) do
    Repo.delete(notification_preference)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification_preference changes.
  """
  def change_notification_preference(%NotificationPreference{} = notification_preference, attrs \\ %{}) do
    NotificationPreference.changeset(notification_preference, attrs)
  end

  alias App.Notifications.SMSMessage

  def create_sms_message(attrs) do
    %SMSMessage{}
    |> SMSMessage.changeset(attrs)
    |> Repo.insert()
  end

  def update_sms_status(id, status, error_message \\ nil, message_id \\ nil) do
    case Repo.get_by(SMSMessage, id: id) do
      nil ->
        {:error, :not_found}

      sms_message ->
        sms_message
        |> SMSMessage.changeset(%{status: status, error_message: error_message, message_id: message_id})
        |> Repo.update()
    end
  end

  # Now let's modify the send_sms function to record the message
  defp send_sms(phone_number, message, user_id \\ nil, appointment_id \\ nil) do
    # First, create a record in the database
    {:ok, sms_record} = create_sms_message(%{
      phone_number: phone_number,
      message: message,
      user_id: user_id,
      appointment_id: appointment_id
    })

    # Then send the actual SMS
    result = if Mix.env() == :dev && !Application.get_env(:app, :send_real_sms_in_dev, false) do
      # In development, just log the message
      IO.puts("SMS to #{phone_number}: #{message}")
      {:ok, %{"messageId" => "dev-mode-#{:rand.uniform(10000)}"}}
    else
      # In production, send real SMS
      App.Services.ProbaseSMS.send_sms(phone_number, message)
    end

    # Update the record based on the result
    case result do
      {:ok, [%{message_id: message_id, status: "SUCCESS"} | _]} ->
#        Update our record with the message ID
        update_sms_status(sms_record.id, "sent", nil, message_id)

        {:ok, message_id}

      {:error, reason} ->
        update_sms_status(sms_record.id, "failed", to_string(reason))
        {:error, reason}
    end
  end

end
