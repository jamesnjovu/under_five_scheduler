defmodule App.Accounts.UserNotifier do
  import Swoosh.Email

  alias App.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Under Five Health Check-Up", "notifications@underfive.example.com"})
      |> subject(subject)
      |> html_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Build an email with the given recipient, subject, and body.
  """
  def build_email(recipient, subject, body) do
    new()
    |> to(recipient)
    |> from({"Under Five Health Check-Up", "notifications@underfive.example.com"})
    |> subject(subject)
    |> html_body(body)
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    body = """
    <h1>Account Confirmation</h1>
    <p>Hi #{user.name},</p>
    <p>You can confirm your account by visiting the URL below:</p>
    <p><a href="#{url}">#{url}</a></p>
    <p>If you didn't create an account with us, please ignore this.</p>
    <p>Thank you,<br>Under Five Health Check-Up Team</p>
    """

    deliver(user.email, "Confirmation instructions", body)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    body = """
    <h1>Reset Password Instructions</h1>
    <p>Hi #{user.name},</p>
    <p>You can reset your password by visiting the URL below:</p>
    <p><a href="#{url}">#{url}</a></p>
    <p>If you didn't request this change, please ignore this.</p>
    <p>Thank you,<br>Under Five Health Check-Up Team</p>
    """

    deliver(user.email, "Reset password instructions", body)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    body = """
    <h1>Update Email Instructions</h1>
    <p>Hi #{user.name},</p>
    <p>You can change your email by visiting the URL below:</p>
    <p><a href="#{url}">#{url}</a></p>
    <p>If you didn't request this change, please ignore this.</p>
    <p>Thank you,<br>Under Five Health Check-Up Team</p>
    """

    deliver(user.email, "Update email instructions", body)
  end
end
