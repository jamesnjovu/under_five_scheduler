defmodule App.Repo.Migrations.AddIsActiveToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :is_active, :boolean, default: true, null: false
      add :deactivated_at, :utc_datetime
      add :deactivated_by, references(:users, on_delete: :nilify_all)
      add :deactivation_reason, :string
    end

    create index(:users, [:is_active])
    create index(:users, [:role, :is_active])
    create index(:users, [:deactivated_at])
    create index(:users, [:deactivated_by])
  end

  def down do
    alter table(:users) do
      remove :is_active
      remove :deactivated_at
      remove :deactivated_by
      remove :deactivation_reason
    end
  end
end
