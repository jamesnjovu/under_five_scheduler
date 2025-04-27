defmodule App.Repo.Migrations.CreateAppointmentLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :action, :string
      add :entity_id, :string
      add :entity_type, :string
      add :ip_address, :string
      add :details, :map
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:audit_logs, [:user_id])
  end
end
