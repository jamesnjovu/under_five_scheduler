defmodule App.Scheduling.Appointment do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.Child
  alias App.Scheduling.Provider
  alias App.Analytics.AppointmentLog

  @statuses ~w(scheduled confirmed cancelled completed no_show rescheduled)

  schema "appointments" do
    field :notes, :string
    field :scheduled_date, :date
    field :scheduled_time, :time
    field :status, :string

    belongs_to :child, Child
    belongs_to :provider, Provider
    has_many :appointment_logs, AppointmentLog

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(appointment, attrs) do
    appointment
    |> cast(attrs, [:scheduled_date, :scheduled_time, :status, :notes, :child_id, :provider_id])
    |> validate_required([:scheduled_date, :scheduled_time, :status, :notes, :child_id, :provider_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_appointment_time()
    |> validate_no_double_booking()
    |> foreign_key_constraint(:child_id)
    |> foreign_key_constraint(:provider_id)
  end

  defp validate_appointment_time(changeset) do
    case {get_change(changeset, :scheduled_date), get_change(changeset, :scheduled_time)} do
      {nil, _} ->
        changeset

      {_, nil} ->
        changeset

      {date, time} ->
        now = DateTime.utc_now()
        appointment_datetime = DateTime.new!(date, time)

        if DateTime.compare(appointment_datetime, now) == :lt do
          add_error(changeset, :scheduled_date, "appointment cannot be in the past")
        else
          changeset
        end
    end
  end

  defp validate_no_double_booking(changeset) do
    case {get_change(changeset, :scheduled_date), get_change(changeset, :scheduled_time),
          get_field(changeset, :provider_id)} do
      {nil, _, _} ->
        changeset

      {_, nil, _} ->
        changeset

      {_, _, nil} ->
        changeset

      {_date, _time, _provider_id} ->
        # This would need to be implemented with a custom validation query
        # to check for existing appointments at the same time
        changeset
    end
  end

  def is_upcoming?(%__MODULE__{scheduled_date: date, scheduled_time: time}) do
    now = DateTime.utc_now()
    appointment_datetime = DateTime.new!(date, time)
    DateTime.compare(appointment_datetime, now) == :gt
  end

  def is_past?(%__MODULE__{} = appointment) do
    !is_upcoming?(appointment)
  end

  def formatted_datetime(%__MODULE__{scheduled_date: date, scheduled_time: time}) do
    "#{Date.to_string(date)} at #{Time.to_string(time)}"
  end
end
