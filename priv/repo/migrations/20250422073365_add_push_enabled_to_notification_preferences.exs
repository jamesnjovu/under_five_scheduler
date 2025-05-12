defmodule App.Repo.Migrations.AddPushEnabledToNotificationPreferences do
  use Ecto.Migration

  def change do
    alter table(:notification_preferences) do
      add :push_enabled, :boolean, default: false, null: false
    end
  end
end
