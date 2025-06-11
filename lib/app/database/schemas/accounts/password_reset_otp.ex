defmodule App.Accounts.PasswordResetOTP do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.User

  @otp_expiry_minutes 10

  schema "password_reset_otps" do
    field :phone_number, :string
    field :email, :string
    field :otp_code, :string
    field :verified_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :attempts, :integer, default: 0

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(password_reset_otp, attrs) do
    password_reset_otp
    |> cast(attrs, [:phone_number, :email, :otp_code, :verified_at, :expires_at, :attempts, :user_id])
    |> validate_required([:phone_number, :otp_code, :expires_at, :user_id])
    |> validate_format(:phone_number, ~r/^\+?[0-9]{10,14}$/)
    |> validate_length(:otp_code, is: 6)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Generates a new OTP record for password reset.
  """
  def create_otp(user, phone_number) do
    otp_code = generate_otp_code()
    expires_at = DateTime.add(DateTime.utc_now(), @otp_expiry_minutes * 60, :second)

    %__MODULE__{}
    |> changeset(%{
      user_id: user.id,
      email: user.email,
      phone_number: phone_number,
      otp_code: otp_code,
      expires_at: expires_at,
      attempts: 0
    })
  end

  @doc """
  Generates a 6-digit OTP code.
  """
  def generate_otp_code do
    100_000..999_999
    |> Enum.random()
    |> to_string()
  end

  @doc """
  Checks if the OTP is expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if the OTP has been verified.
  """
  def verified?(%__MODULE__{verified_at: verified_at}) do
    not is_nil(verified_at)
  end

  @doc """
  Checks if the OTP has reached maximum attempts.
  """
  def max_attempts_reached?(%__MODULE__{attempts: attempts}) do
    attempts >= 3
  end

  @doc """
  Marks the OTP as verified.
  """
  def verify_changeset(otp) do
    change(otp, verified_at: DateTime.utc_now())
  end

  @doc """
  Increments the attempt count.
  """
  def increment_attempts_changeset(otp) do
    change(otp, attempts: otp.attempts + 1)
  end
end