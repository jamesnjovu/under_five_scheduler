defmodule App.Repo.Migrations.AddProviderStatusIndexes do
  use Ecto.Migration

  def up do
    # Add composite indexes for better query performance
    create index(:providers, [:is_active, :specialization])
    create index(:providers, [:is_active, :inserted_at])

    # Add index for appointments with provider status for efficient queries
    create index(:appointments, [:provider_id, :scheduled_date],
             where: "status IN ('scheduled', 'confirmed')")

    # Add partial index for active providers only
    create index(:providers, [:name], where: "is_active = true")
  end

  def down do
    drop index(:providers, [:is_active, :specialization])
    drop index(:providers, [:is_active, :inserted_at])
    drop index(:appointments, [:provider_id, :scheduled_date])
    drop index(:providers, [:name], where: "is_active = true")
  end
end
