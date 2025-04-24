defmodule App.Repo.Migrations.CreateSchedules do
  use Ecto.Migration

  def change do
    create table(:schedules) do
      add :day_of_week, :integer
      add :start_time, :time
      add :end_time, :time
      add :provider_id, references(:providers, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:schedules, [:provider_id])
  end
end
