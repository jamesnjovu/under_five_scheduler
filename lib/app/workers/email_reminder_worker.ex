defmodule App.Workers.EmailReminderWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias App.Repo
  alias App.Scheduling
  alias App.Accounts.UserNotifier
  alias App.Mailer

  @impl Oban.Worker

  def perform(%Oban.Job{args: %{"appointment_id" => appointment_id, "recipient_email" => email}}) do
    # Fetch the appointment with all needed associations
    appointment =
      Scheduling.get_appointment!(appointment_id)
      |> Repo.preload([:child, :provider])

    # Only send reminder if appointment is still active
    if appointment.status in ["scheduled", "confirmed"] do
      # Get child's parent (user)
      child = appointment.child
      user = Repo.get!(App.Accounts.User, child.user_id)

      # Prepare email content
      subject = "Appointment Reminder - #{child.name}"

      email_body = """
      <h2>Appointment Reminder</h2>
      <p>Dear #{user.name},</p>

      <p>This is a reminder that #{child.name} has an appointment scheduled for tomorrow.</p>

      <ul>
        <li><strong>Date:</strong> #{format_date(appointment.scheduled_date)}</li>
        <li><strong>Time:</strong> #{format_time(appointment.scheduled_time)}</li>
        <li><strong>Provider:</strong> #{appointment.provider.name}</li>
        <li><strong>Location:</strong> Health Center Main Building</li>
      </ul>

      <p>Please arrive 10 minutes before your scheduled time.</p>

      <p>Thank you,<br>Under Five Health Check-Up Team</p>
      """

      # Build and send the email
      UserNotifier.build_email(email, subject, email_body)
      |> Mailer.deliver()
    end

    :ok
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
end
