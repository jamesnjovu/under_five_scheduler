defmodule App.Repo.Migrations.CreateSpecializationTables do
  use Ecto.Migration

  def change do
    # Create categories table first
    create table(:specialization_categories) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :display_order, :integer, default: 0
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:specialization_categories, [:code])
    create index(:specialization_categories, [:is_active])
    create index(:specialization_categories, [:display_order])

    # Create specializations table
    create table(:specializations) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :requires_license, :boolean, default: true
      add :can_prescribe, :boolean, default: false
      add :icon, :string, default: "user-md"
      add :display_order, :integer, default: 0
      add :is_active, :boolean, default: true

      add :category_id, references(:specialization_categories, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:specializations, [:code])
    create index(:specializations, [:category_id])
    create index(:specializations, [:is_active])
    create index(:specializations, [:display_order])
    create index(:specializations, [:can_prescribe])
    create index(:specializations, [:requires_license])

    # Update providers table to reference specializations
    alter table(:providers) do
      add :specialization_id, references(:specializations, on_delete: :restrict)
    end

    # Seed initial data
    flush()

    # Insert categories
    categories = [
      %{code: "medical_doctor", name: "Medical Doctors", description: "Licensed physicians", display_order: 1},
      %{code: "nursing", name: "Nursing Professionals", description: "Registered nurses and nurse practitioners", display_order: 2},
      %{code: "mid_level", name: "Mid-level Providers", description: "Clinical officers and similar roles", display_order: 3},
      %{code: "community", name: "Community Health", description: "Community-based health workers", display_order: 4},
      %{code: "allied_health", name: "Allied Health", description: "Specialized health professionals", display_order: 5},
      %{code: "mental_health", name: "Mental Health", description: "Psychological and psychiatric professionals", display_order: 6}
    ]

    for category <- categories do
      execute """
      INSERT INTO specialization_categories (code, name, description, display_order, is_active, inserted_at, updated_at)
      VALUES ('#{category.code}', '#{category.name}', '#{category.description}', #{category.display_order}, true, NOW(), NOW())
      """
    end

    # Insert specializations
    specializations = [
      %{code: "pediatrician", name: "Pediatrician", description: "Specialized in medical care of infants, children, and adolescents", category: "medical_doctor", requires_license: true, can_prescribe: true, icon: "stethoscope", order: 1},
      %{code: "general_practitioner", name: "General Practitioner", description: "Primary care physician providing comprehensive healthcare", category: "medical_doctor", requires_license: true, can_prescribe: true, icon: "medical-bag", order: 2},
      %{code: "nurse", name: "Registered Nurse", description: "Registered nurse specializing in child healthcare", category: "nursing", requires_license: true, can_prescribe: false, icon: "heart", order: 3},
      %{code: "nurse_practitioner", name: "Nurse Practitioner", description: "Advanced practice nurse with prescriptive authority", category: "nursing", requires_license: true, can_prescribe: true, icon: "heart", order: 4},
      %{code: "clinical_officer", name: "Clinical Officer", description: "Mid-level healthcare provider trained in clinical medicine", category: "mid_level", requires_license: true, can_prescribe: true, icon: "clipboard-list", order: 5},
      %{code: "community_health_worker", name: "Community Health Worker", description: "Community-based healthcare provider focused on health promotion", category: "community", requires_license: false, can_prescribe: false, icon: "users", order: 6},
      %{code: "nutritionist", name: "Nutritionist", description: "Specialist in nutrition and dietary counseling for children", category: "allied_health", requires_license: true, can_prescribe: false, icon: "apple-alt", order: 7},
      %{code: "psychologist", name: "Child Psychologist", description: "Specialist in child mental health and development", category: "mental_health", requires_license: true, can_prescribe: false, icon: "brain", order: 8}
    ]

    for spec <- specializations do
      execute """
      INSERT INTO specializations (code, name, description, requires_license, can_prescribe, icon, display_order, is_active, category_id, inserted_at, updated_at)
      VALUES (
        '#{spec.code}',
        '#{spec.name}',
        '#{spec.description}',
        #{spec.requires_license},
        #{spec.can_prescribe},
        '#{spec.icon}',
        #{spec.order},
        true,
        (SELECT id FROM specialization_categories WHERE code = '#{spec.category}'),
        NOW(),
        NOW()
      )
      """
    end
  end

  def down do
    alter table(:providers) do
      remove :specialization_id
    end

    drop table(:specializations)
    drop table(:specialization_categories)
  end
end
