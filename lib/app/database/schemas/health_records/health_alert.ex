defmodule App.HealthRecords.HealthAlert do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.{Child, User}

  @alert_types ~w(immunization_overdue growth_concern missed_appointment
                  development_delay nutrition_issue follow_up_required)
  @severity_levels ~w(low medium high critical)

  schema "health_alerts" do
    field :alert_type, :string
    field :severity, :string
    field :message, :string
    field :action_required, :string
    field :is_resolved, :boolean, default: false
    field :resolved_at, :utc_datetime
    field :auto_generated, :boolean, default: true

    belongs_to :child, Child
    belongs_to :resolved_by, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(health_alert, attrs) do
    health_alert
    |> cast(attrs, [
      :alert_type, :severity, :message, :action_required,
      :is_resolved, :resolved_at, :auto_generated, :child_id, :resolved_by_id
    ])
    |> validate_required([:alert_type, :severity, :message, :child_id])
    |> validate_inclusion(:alert_type, @alert_types)
    |> validate_inclusion(:severity, @severity_levels)
    |> foreign_key_constraint(:child_id)
    |> foreign_key_constraint(:resolved_by_id)
  end

  def resolve_alert(alert, user_id) do
    change(alert, %{
      is_resolved: true,
      resolved_at: DateTime.utc_now(),
      resolved_by_id: user_id
    })
  end
end