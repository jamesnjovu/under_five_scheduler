defmodule App.Repo.Migrations.CreatePasswordResetOtps do
  use Ecto.Migration

  def change do
    create table(:password_reset_otps) do
      add :phone_number, :string, null: false
      add :email, :citext, null: false
      add :otp_code, :string, null: false
      add :verified_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, default: 0, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:password_reset_otps, [:user_id])
    create index(:password_reset_otps, [:phone_number])
    create index(:password_reset_otps, [:phone_number, :otp_code])
    create index(:password_reset_otps, [:expires_at])
  end
end
