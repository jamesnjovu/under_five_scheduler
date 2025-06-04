defmodule App.Workers.PushNotificationWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias App.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"subscription_id" => subscription_id, "payload" => payload}}) do
    # Get the subscription
    subscription = Repo.get!(App.Notifications.PushSubscription, subscription_id)

    # Send the push notification
    # In a real application, you would use a web push library here
    # For now, we'll just log it
      IO.puts("Push notification to endpoint: #{subscription.endpoint}")
      IO.puts("Payload: #{inspect(payload)}")

      # In production, use the web push library
      # WebPush.send_notification(subscription, payload)
      :ok
  end
end