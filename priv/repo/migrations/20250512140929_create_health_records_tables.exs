defmodule App.Repo.Migrations.CreateHealthRecordsTables do
  use Ecto.Migration

  def change do
    # Growth records table
    create table(:growth_records) do
      add :weight, :decimal, null: false
      add :height, :decimal
      add :head_circumference, :decimal
      add :measurement_date, :date, null: false
      add :notes, :text
      add :child_id, references(:children, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:growth_records, [:child_id])
    create index(:growth_records, [:measurement_date])

    # Immunization records table
    create table(:immunization_records) do
      add :vaccine_name, :string, null: false
      add :administered_date, :date
      add :due_date, :date
      add :status, :string, null: false
      add :notes, :text
      add :administered_by, :string
      add :child_id, references(:children, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:immunization_records, [:child_id])
    create index(:immunization_records, [:status])
    create index(:immunization_records, [:vaccine_name])

    # Vaccine schedule table (lookup table for standard vaccines)
    create table(:vaccine_schedules) do
      add :vaccine_name, :string, null: false
      add :description, :string
      add :recommended_age_months, :integer, null: false
      add :is_mandatory, :boolean, default: true

      timestamps()
    end

    create unique_index(:vaccine_schedules, [:vaccine_name])
  end
end
