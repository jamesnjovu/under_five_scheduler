defmodule App.Repo.Migrations.CreateAppointments do
  use Ecto.Migration

  def change do
    create table(:appointments) do
      add :scheduled_date, :date
      add :scheduled_time, :time
      add :status, :string
      add :notes, :text
      add :child_id, references(:children, on_delete: :nothing)
      add :provider_id, references(:providers, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:appointments, [:child_id])
    create index(:appointments, [:provider_id])
  end
end
