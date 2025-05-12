defmodule App.Config do
  @moduledoc """
  Helper functions for accessing application configuration.
  """

  def get_probase_username do
    Application.get_env(:app, :probase_sms, [])
    |> Keyword.get(:username)
    |> validate_or_get_env("PROBASE_SMS_USERNAME")
  end

  def get_probase_password do
    Application.get_env(:app, :probase_sms, [])
    |> Keyword.get(:password)
    |> validate_or_get_env("PROBASE_SMS_PASSWORD")
  end

  def get_sms_sender_id do
    Application.get_env(:app, :probase_sms, [])
    |> Keyword.get(:sender_id)
    |> validate_or_get_env("PROBASE_SMS_SENDER_ID")
  end

  defp validate_or_get_env(nil, env_var), do: System.get_env(env_var)
  defp validate_or_get_env(value, _), do: value
end