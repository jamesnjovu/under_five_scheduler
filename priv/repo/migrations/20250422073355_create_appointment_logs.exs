defmodule App.Repo.Migrations.CreateAppointmentLogs do
  use Ecto.Migration

  def change do
    create table(:appointment_logs) do
      add :action, :string
      add :timestamp, :utc_datetime
      add :appointment_id, references(:appointments, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:appointment_logs, [:appointment_id])
  end
end
