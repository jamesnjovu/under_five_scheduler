defmodule App.Repo.Migrations.AddLicenseToProviders do
  use Ecto.Migration

  def change do
    alter table(:providers) do
      add :license_number, :string
      add :is_active, :boolean, default: true, null: false
    end

    create index(:providers, [:license_number])
    create index(:providers, [:specialization])
    create index(:providers, [:is_active])
  end
end
