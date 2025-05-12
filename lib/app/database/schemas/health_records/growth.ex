defmodule App.HealthRecords.Growth do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.Child

  schema "growth_records" do
    field :weight, :decimal  # Weight in kg
    field :height, :decimal  # Height in cm
    field :head_circumference, :decimal  # Head circumference in cm
    field :measurement_date, :date
    field :notes, :string

    belongs_to :child, Child

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(growth, attrs) do
    growth
    |> cast(attrs, [:weight, :height, :head_circumference, :measurement_date, :notes, :child_id])
    |> validate_required([:weight, :height, :measurement_date, :child_id])
    |> validate_number(:weight, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:head_circumference, greater_than: 0)
    |> foreign_key_constraint(:child_id)
  end
end
