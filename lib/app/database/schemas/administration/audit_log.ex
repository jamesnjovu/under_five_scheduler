defmodule App.Administration.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    field :action, :string
    field :details, :map
    field :entity_id, :string
    field :entity_type, :string
    field :ip_address, :string
    belongs_to :user, App.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:action, :entity_type, :entity_id, :details, :user_id, :ip_address])
    |> validate_required([:action, :entity_type, :entity_id, :user_id])
  end
end
