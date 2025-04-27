defmodule App.Scheduling.Provider do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.User
  alias App.Scheduling.{Schedule, Appointment}

  @specializations ~w(pediatrician nurse general_practitioner)

  schema "providers" do
    field :name, :string
    field :specialization, :string

    belongs_to :user, User
    has_many :schedules, Schedule
    has_many :appointments, Appointment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [:name, :specialization, :user_id])
    |> validate_required([:name, :specialization, :user_id])
    |> validate_inclusion(:specialization, @specializations)
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  def available_slots(_provider, _date) do
    # This would be implemented to return available time slots for a given date
    # based on the provider's schedule and existing appointments
    []
  end
end
