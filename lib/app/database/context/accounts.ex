defmodule App.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias App.Repo

  alias App.Accounts.{User, UserToken, UserNotifier, Child}
  alias App.Notifications.NotificationPreference
  alias App.Accounts.PasswordResetOTP

  ## Database getters

  def list_users do
    User
    |> Repo.all()
  end

  @doc """
  Updates a user's profile information.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification preference changes.

  ## Examples

      iex> change_notification_preference(notification_preference)
      %Ecto.Changeset{data: %NotificationPreference{}}

  """
  def change_notification_preference(
        %NotificationPreference{} = notification_preference,
        attrs \\ %{}
      ) do
    NotificationPreference.changeset(notification_preference, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Returns the list of users with a specific role.

  ## Examples

      iex> list_users_by_role("admin")
      [%User{}, ...]

  """
  def list_users_by_role(role) when is_binary(role) do
    import Ecto.Query

    User
    |> where(role: ^role)
    |> Repo.all()
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_phone("foo@example.com")
      %User{}

      iex> get_user_by_phone("unknown@example.com")
      nil

  """
  def get_user_by_phone(phone) when is_binary(phone) do
    User
    |> where([a], a.phone == ^phone)
    |> Repo.one()
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user && User.valid_password?(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_credentials}

      true ->
        # Prevents timing attacks
        User.valid_password?(nil, password)
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        create_notification_preference(user)
        {:ok, user}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Returns the list of children.

  ## Examples

      iex> list_children()
      [%Child{}, ...]

  """
  def list_children do
    Repo.all(Child)
  end

  def list_children(user_id) do
    Child
    |> where([a], a.user_id == ^user_id and a.status in ["active"])
    |> order_by(asc: :name)
    |> Repo.all()
  end

  @doc """
  Gets a single child.

  Raises `Ecto.NoResultsError` if the Child does not exist.

  ## Examples

      iex> get_child!(123)
      %Child{}

      iex> get_child!(456)
      ** (Ecto.NoResultsError)

  """
  def get_child!(id), do: Repo.get!(Child, id)

  def get_child(id), do: Repo.get(Child, id)

  @doc """
  Creates a child.

  ## Examples

      iex> create_child(%{field: value})
      {:ok, %Child{}}

      iex> create_child(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_child(user, attrs \\ %{}) do
    %Child{}
    |> Child.changeset(Map.put(attrs, "user_id", user.id))
    |> Repo.insert()
  end

  @doc """
  Updates a child.

  ## Examples

      iex> update_child(child, %{field: new_value})
      {:ok, %Child{}}

      iex> update_child(child, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_child(%Child{} = child, attrs) do
    child
    |> Child.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a child.

  ## Examples

      iex> delete_child(child)
      {:ok, %Child{}}

      iex> delete_child(child)
      {:error, %Ecto.Changeset{}}

  """
  def delete_child(%Child{} = child) do
    Repo.delete(child)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking child changes.

  ## Examples

      iex> change_child(child)
      %Ecto.Changeset{data: %Child{}}

  """
  def change_child(%Child{} = child, attrs \\ %{}) do
    Child.changeset(child, attrs)
  end

  # Notification preferences

  defp create_notification_preference(user) do
    %NotificationPreference{}
    |> NotificationPreference.changeset(%{user_id: user.id})
    |> Repo.insert()
  end

  def get_notification_preference(user_id) do
    Repo.get_by(NotificationPreference, user_id: user_id)
  end

  def update_notification_preference(%NotificationPreference{} = preference, attrs) do
    preference
    |> NotificationPreference.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  # User roles

  def is_admin?(%User{role: "admin"}), do: true
  def is_admin?(_), do: false

  def is_provider?(%User{role: "provider"}), do: true
  def is_provider?(_), do: false

  def is_parent?(%User{role: "parent"}), do: true
  def is_parent?(_), do: false

  @doc """
  Initiates password reset by sending OTP to user's phone.
  """
  def initiate_password_reset_by_email(email) do
    case get_user_by_email(email) do
      nil ->
        # Return success even if user not found to prevent phone number enumeration
        {:ok, :otp_sent}

      user ->
        # Invalidate any existing OTP for this user
        invalidate_existing_otps(user.id)

        # Create new OTP
        otp_changeset = PasswordResetOTP.create_otp(user, user.phone)

        case Repo.insert(otp_changeset) do
          {:ok, otp} ->
            # Send SMS with OTP
            send_password_reset_otp(user.phone, otp.otp_code, user.name)
            {:ok, :otp_sent}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Verifies the OTP code for password reset.
  """
  def verify_password_reset_otp(phone_number, otp_code) do
    case get_active_password_reset_otp(phone_number) do
      nil ->
        {:error, :invalid_otp}

      otp ->
        cond do
          PasswordResetOTP.expired?(otp) ->
            {:error, :expired}

          PasswordResetOTP.verified?(otp) ->
            {:error, :already_used}

          PasswordResetOTP.max_attempts_reached?(otp) ->
            {:error, :max_attempts}

          otp.otp_code == otp_code ->
            # Mark as verified
            case Repo.update(PasswordResetOTP.verify_changeset(otp)) do
              {:ok, verified_otp} ->
                {:ok, verified_otp}

              {:error, changeset} ->
                {:error, changeset}
            end

          true ->
            # Increment attempts
            Repo.update(PasswordResetOTP.increment_attempts_changeset(otp))
            {:error, :invalid_otp}
        end
    end
  end

  @doc """
  Resets password using verified OTP.
  """
  def reset_password_with_otp(email, otp_code, new_password) do
    with {:ok, otp} <- verify_otp_for_reset(email, otp_code),
         user <- get_user!(otp.user_id),
         {:ok, updated_user} <- update_user_password_direct(user, new_password) do

      # Invalidate the OTP after successful password reset
      Repo.delete(otp)

      {:ok, updated_user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resends OTP for password reset.
  """
  def resend_password_reset_otp(phone_number) do
    case get_user_by_phone(phone_number) do
      nil ->
        {:ok, :otp_sent}

      user ->
        # Check if there's a recent OTP (within last 2 minutes)
        if has_recent_otp?(user.id) do
          {:error, :too_soon}
        else
          # Invalidate existing OTPs and create new one
          invalidate_existing_otps(user.id)

          otp_changeset = PasswordResetOTP.create_otp(user, phone_number)

          case Repo.insert(otp_changeset) do
            {:ok, otp} ->
              send_password_reset_otp(user.phone, otp.otp_code, user.name)
              {:ok, :otp_sent}

            {:error, changeset} ->
              {:error, changeset}
          end
        end
    end
  end

  # Private helper functions

  defp get_active_password_reset_otp(email) do
    from(otp in PasswordResetOTP,
      where: otp.email == ^email and
             is_nil(otp.verified_at) and
             otp.expires_at > ^DateTime.utc_now(),
      order_by: [desc: otp.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp verify_otp_for_reset(email, otp_code) do
    case get_active_password_reset_otp(email) do
      nil ->
        {:error, :invalid_otp}

      otp ->
        if otp.otp_code == otp_code and !PasswordResetOTP.verified?(otp) do
          {:ok, otp}
        else
          {:error, :invalid_otp}
        end
    end
  end

  defp invalidate_existing_otps(user_id) do
    from(otp in PasswordResetOTP,
      where: otp.user_id == ^user_id and is_nil(otp.verified_at)
    )
    |> Repo.delete_all()
  end

  defp has_recent_otp?(user_id) do
    two_minutes_ago = DateTime.add(DateTime.utc_now(), -120, :second)

    from(otp in PasswordResetOTP,
      where: otp.user_id == ^user_id and otp.inserted_at > ^two_minutes_ago
    )
    |> Repo.exists?()
  end

  defp update_user_password_direct(user, password) do
    changeset =
      user
      |> User.password_changeset(%{password: password})

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
         {:ok, %{user: user}} -> {:ok, user}
         {:error, :user, changeset, _} -> {:error, changeset}
       end
  end

  defp send_password_reset_otp(phone_number, otp_code, user_name) do
    message = """
    Hello #{user_name},
    Your password reset code for Under Five Health Check-Up is: #{otp_code}
    This code will expire in 10 minutes. Do not share this code with anyone.
    If you did not request this reset, please ignore this message.
    """

    App.Services.ProbaseSMS.send_sms(phone_number, message)
  end
end
