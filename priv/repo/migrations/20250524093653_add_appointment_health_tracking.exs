defmodule App.Repo.Migrations.AddAppointmentHealthTracking do
  use Ecto.Migration

  def change do
    # Add fields to appointments table for better health tracking
    alter table(:appointments) do
      add :health_check_started_at, :utc_datetime
      add :health_check_completed_at, :utc_datetime
      add :health_summary, :text
      add :recommendations, :text
      add :follow_up_required, :boolean, default: false
      add :follow_up_date, :date
    end

    # Create health visit records table
    create table(:health_visit_records) do
      add :appointment_id, references(:appointments, on_delete: :delete_all), null: false
      add :provider_id, references(:providers, on_delete: :delete_all), null: false
      add :child_id, references(:children, on_delete: :delete_all), null: false
      add :visit_date, :date, null: false
      add :visit_type, :string, default: "routine_checkup"
      add :chief_complaint, :text
      add :physical_examination, :text
      add :assessment, :text
      add :plan, :text
      add :growth_recorded, :boolean, default: false
      add :immunizations_given, {:array, :string}, default: []
      add :next_visit_recommended, :date
      add :provider_notes, :text

      timestamps(type: :utc_datetime)
    end

    # Create health alerts table
    create table(:health_alerts) do
      add :child_id, references(:children, on_delete: :delete_all), null: false
      add :alert_type, :string, null: false
      add :severity, :string, null: false
      add :message, :text, null: false
      add :action_required, :text
      add :is_resolved, :boolean, default: false
      add :resolved_at, :utc_datetime
      add :resolved_by, references(:users, on_delete: :nilify_all)
      add :auto_generated, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    # Create indexes
    create index(:health_visit_records, [:appointment_id])
    create index(:health_visit_records, [:provider_id])
    create index(:health_visit_records, [:child_id])
    create index(:health_visit_records, [:visit_date])

    create index(:health_alerts, [:child_id])
    create index(:health_alerts, [:alert_type])
    create index(:health_alerts, [:severity])
    create index(:health_alerts, [:is_resolved])

    create index(:appointments, [:health_check_started_at])
    create index(:appointments, [:health_check_completed_at])
    create index(:appointments, [:follow_up_required])
  end
end
