defmodule App.Workers.OTPCleanupWorker do
  @moduledoc """
  Background worker that cleans up expired OTP records.
  Runs periodically to keep the database clean.
  """
  import Ecto.Query, warn: false

  use Oban.Worker,
      queue: :default,
      max_attempts: 3

  alias App.Repo
  alias App.Accounts.PasswordResetOTP

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Delete expired OTPs
    expired_count =
      from(otp in PasswordResetOTP,
        where: otp.expires_at < ^DateTime.utc_now()
      )
      |> Repo.delete_all()

    # Delete old verified OTPs (older than 24 hours)
    old_verified_cutoff = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)

    old_verified_count =
      from(otp in PasswordResetOTP,
        where: not is_nil(otp.verified_at) and otp.verified_at < ^old_verified_cutoff
      )
      |> Repo.delete_all()

    require Logger
    Logger.info("OTP Cleanup: Removed #{expired_count} expired OTPs and #{old_verified_count} old verified OTPs")

    :ok
  end

  @doc """
  Schedules the OTP cleanup job to run every hour.
  """
  def schedule_cleanup do
    # Schedule to run every hour
    %{}
    |> __MODULE__.new(scheduled_at: next_run_time())
    |> Oban.insert()
  end

  defp next_run_time do
    DateTime.add(DateTime.utc_now(), 3600, :second) # 1 hour from now
  end
end