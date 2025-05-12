defmodule App.Notifications.SMSMessage do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.User
  alias App.Scheduling.Appointment

  schema "sms_messages" do
    field :phone_number, :string
    field :message, :string
    field :status, :string, default: "pending" # pending, sent, delivered, failed
    field :message_id, :string
    field :error_message, :string

    belongs_to :user, User
    belongs_to :appointment, Appointment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sms_message, attrs) do
    sms_message
    |> cast(attrs, [:phone_number, :message, :status, :message_id, :error_message, :user_id, :appointment_id])
    |> validate_required([:phone_number, :message])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:appointment_id)
  end
end