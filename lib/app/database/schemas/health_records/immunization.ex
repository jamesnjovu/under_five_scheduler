defmodule App.HealthRecords.Immunization do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.Child

  schema "immunization_records" do
    field :vaccine_name, :string
    field :administered_date, :date
    field :due_date, :date
    field :status, :string  # "scheduled", "administered", "missed"
    field :notes, :string
    field :administered_by, :string  # Name of the healthcare provider who administered the vaccine

    belongs_to :child, Child

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(immunization, attrs) do
    immunization
    |> cast(attrs, [:vaccine_name, :administered_date, :due_date, :status, :notes, :administered_by, :child_id])
    |> validate_required([:vaccine_name, :status, :child_id])
    |> validate_inclusion(:status, ["scheduled", "administered", "missed"])
    |> foreign_key_constraint(:child_id)
  end
end
