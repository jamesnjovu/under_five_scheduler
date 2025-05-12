defmodule App.Workers.ReminderSchedulerWorker do
  use Oban.Worker,
      queue: :default,
      max_attempts: 3

  alias App.Repo
  alias App.Scheduling
  alias App.Notifications
  alias App.Accounts

  @impl Oban.Worker
  def perform(_job) do
    # Find all appointments in the next 48 hours that need reminders
    tomorrow = Date.utc_today() |> Date.add(1)
    day_after = Date.utc_today() |> Date.add(2)

    # Get all active appointments for the next two days
    appointments =
      Scheduling.list_appointments()
      |> Enum.filter(fn appt ->
        appt.status in ["scheduled", "confirmed"] &&
          (appt.scheduled_date == tomorrow || appt.scheduled_date == day_after)
      end)
      |> Repo.preload([child: :user])

    # Schedule reminders for each appointment
    Enum.each(appointments, fn appointment ->
      user = appointment.child.user
      Notifications.schedule_appointment_reminders(appointment, user)
    end)

    # Return success
    :ok
  end
end