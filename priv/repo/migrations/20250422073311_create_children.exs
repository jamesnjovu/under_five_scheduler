defmodule App.Repo.Migrations.CreateChildren do
  use Ecto.Migration

  def change do
    create table(:children) do
      add :name, :string
      add :date_of_birth, :date
      add :medical_record_number, :string
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:children, [:medical_record_number])
    create index(:children, [:user_id])
  end
end
