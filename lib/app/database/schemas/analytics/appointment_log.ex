defmodule App.Analytics.AppointmentLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appointment_logs" do
    field :action, :string
    field :timestamp, :utc_datetime
    field :appointment_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(appointment_log, attrs) do
    appointment_log
    |> cast(attrs, [:action, :timestamp])
    |> validate_required([:action, :timestamp])
  end
end
