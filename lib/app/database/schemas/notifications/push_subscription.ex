defmodule App.Notifications.PushSubscription do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.User

  schema "push_subscriptions" do
    field :endpoint, :string
    field :p256dh, :string
    field :auth, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(push_subscription, attrs) do
    push_subscription
    |> cast(attrs, [:endpoint, :p256dh, :auth, :user_id])
    |> validate_required([:endpoint, :p256dh, :auth, :user_id])
    |> unique_constraint(:endpoint)
    |> foreign_key_constraint(:user_id)
  end
end