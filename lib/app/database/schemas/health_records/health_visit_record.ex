defmodule App.HealthRecords.HealthVisitRecord do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Scheduling.{Appointment, Provider}
  alias App.Accounts.Child

  @visit_types ~w(routine_checkup sick_visit follow_up emergency vaccination_only)

  schema "health_visit_records" do
    field :visit_date, :date
    field :visit_type, :string, default: "routine_checkup"
    field :chief_complaint, :string
    field :physical_examination, :string
    field :assessment, :string
    field :plan, :string
    field :growth_recorded, :boolean, default: false
    field :immunizations_given, {:array, :string}, default: []
    field :next_visit_recommended, :date
    field :provider_notes, :string

    belongs_to :appointment, Appointment
    belongs_to :provider, Provider
    belongs_to :child, Child

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(health_visit_record, attrs) do
    health_visit_record
    |> cast(attrs, [
      :visit_date, :visit_type, :chief_complaint, :physical_examination,
      :assessment, :plan, :growth_recorded, :immunizations_given,
      :next_visit_recommended, :provider_notes, :appointment_id,
      :provider_id, :child_id
    ])
    |> validate_required([:visit_date, :visit_type, :appointment_id, :provider_id, :child_id])
    |> validate_inclusion(:visit_type, @visit_types)
    |> foreign_key_constraint(:appointment_id)
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:child_id)
  end
end