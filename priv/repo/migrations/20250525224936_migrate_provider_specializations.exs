defmodule App.Repo.Migrations.MigrateProviderSpecializations do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # Update existing providers to reference the new specialization records
    execute """
    UPDATE providers
    SET specialization_id = (
      SELECT s.id
      FROM specializations s
      WHERE s.code = providers.specialization
    )
    WHERE providers.specialization IS NOT NULL
    """

    # Verify migration was successful
    execute """
    DO $$
    DECLARE
        unmigrated_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO unmigrated_count
        FROM providers
        WHERE specialization IS NOT NULL
        AND specialization_id IS NULL;

        IF unmigrated_count > 0 THEN
            RAISE EXCEPTION 'Migration incomplete: % providers have unmigrated specializations', unmigrated_count;
        END IF;
    END $$;
    """

    # After successful migration, we can make specialization_id required
    # and potentially remove the old specialization field in a future migration
    alter table(:providers) do
      modify :specialization_id, :integer, null: true  # Keep nullable for now during transition
    end

    # Add index for better performance
    create index(:providers, [:specialization_id], where: "specialization_id IS NOT NULL")
  end

  def down do
    # Remove the specialization_id values
    execute "UPDATE providers SET specialization_id = NULL"

    # Remove the index
    drop index(:providers, [:specialization_id])
  end
end
