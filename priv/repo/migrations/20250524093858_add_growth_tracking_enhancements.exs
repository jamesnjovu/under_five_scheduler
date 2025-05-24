defmodule App.Repo.Migrations.AddGrowthTrackingEnhancements do
  use Ecto.Migration

  def change do
    alter table(:growth_records) do
      add :weight_percentile, :float
      add :height_percentile, :float
      add :head_circumference_percentile, :float
      add :bmi, :decimal, precision: 5, scale: 2
      add :bmi_percentile, :float
      add :growth_concerns, :text
      add :provider_id, references(:providers, on_delete: :nilify_all)
    end

    # Add indexes for better performance
    create index(:growth_records, [:child_id, :measurement_date])
    create index(:growth_records, [:provider_id])
  end
end
