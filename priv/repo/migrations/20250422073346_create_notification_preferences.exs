defmodule App.Repo.Migrations.CreateNotificationPreferences do
  use Ecto.Migration

  def change do
    create table(:notification_preferences) do
      add :sms_enabled, :boolean, default: true, null: false
      add :email_enabled, :boolean, default: false, null: false
      add :reminder_hours, :integer, default: 24
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:notification_preferences, [:user_id])
  end
end
