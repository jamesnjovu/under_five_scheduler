defmodule App.Notifications.NotificationPreference do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.User

  schema "notification_preferences" do
    field :email_enabled, :boolean, default: false
    field :reminder_hours, :integer
    field :sms_enabled, :boolean, default: false

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification_preference, attrs) do
    notification_preference
    |> cast(attrs, [:sms_enabled, :email_enabled, :reminder_hours, :user_id])
    |> validate_required([:sms_enabled, :email_enabled, :reminder_hours, :user_id])
    |> validate_number(:reminder_hours, greater_than: 0, less_than_or_equal_to: 72)
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end
end
