defmodule App.Workers.SMSReminderWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias App.Repo
  alias App.Scheduling
  alias App.Notifications

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"appointment_id" => appointment_id, "recipient_phone" => phone}}) do
    # Fetch the appointment with all needed associations
    appointment =
      Scheduling.get_appointment!(appointment_id)
      |> Repo.preload([:child, :provider])

    # Only send reminder if appointment is still active
    if appointment.status in ["scheduled", "confirmed"] do
      # Get child's parent (user)
      child = appointment.child
      user = Repo.get!(App.Accounts.User, child.user_id)

      # Send SMS reminder
      message = """
      Reminder: #{child.name} has an appointment tomorrow at #{format_time(appointment.scheduled_time)}.
      Provider: #{appointment.provider.name}
      Location: Health Center Main Building
      Thank you for using Under Five Health Check-Up.
      """

      # Send the SMS
      send_sms(phone, message)
    end

    :ok
  end

  defp send_sms(phone_number, message) do
    # In development, just log the message

      IO.puts("SMS Reminder to #{phone_number}: #{message}")
      # In production or when explicitly configured, send real SMS
      App.Services.ProbaseSMS.send_sms(phone_number, message)
      {:ok, :sent}
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end
end