defmodule App.HealthRecords.VaccineSchedule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "vaccine_schedules" do
    field :vaccine_name, :string
    field :description, :string
    field :recommended_age_months, :integer  # Age in months when the vaccine is recommended
    field :is_mandatory, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(vaccine_schedule, attrs) do
    vaccine_schedule
    |> cast(attrs, [:vaccine_name, :description, :recommended_age_months, :is_mandatory])
    |> validate_required([:vaccine_name, :recommended_age_months])
    |> validate_number(:recommended_age_months, greater_than_or_equal_to: 0)
    |> unique_constraint(:vaccine_name)
  end
end
