defmodule App.Repo.Migrations.CreateSmsMessages do
  use Ecto.Migration

  def change do
    create table(:sms_messages) do
      add :phone_number, :string, null: false
      add :message, :text, null: false
      add :status, :string, default: "pending"
      add :message_id, :string
      add :error_message, :string
      add :user_id, references(:users, on_delete: :nilify_all)
      add :appointment_id, references(:appointments, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:sms_messages, [:user_id])
    create index(:sms_messages, [:appointment_id])
    create index(:sms_messages, [:message_id])
    create index(:sms_messages, [:status])
  end
end
