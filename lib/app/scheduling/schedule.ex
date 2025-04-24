defmodule App.Scheduling.Schedule do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Scheduling.Provider

  @days_of_week 0..6  # 0 = Sunday, 6 = Saturday

  schema "schedules" do
    field :day_of_week, :integer
    field :end_time, :time
    field :start_time, :time

    belongs_to :provider, Provider

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, [:day_of_week, :start_time, :end_time, :provider_id])
    |> validate_required([:day_of_week, :start_time, :end_time, :provider_id])
    |> validate_inclusion(:day_of_week, @days_of_week)
    |> validate_time_range()
    |> unique_constraint([:provider_id, :day_of_week], name: :schedules_provider_id_day_of_week_index)
    |> foreign_key_constraint(:provider_id)
  end

  defp validate_time_range(changeset) do
    case {get_change(changeset, :start_time), get_change(changeset, :end_time)} do
      {nil, _} -> changeset
      {_, nil} -> changeset
      {start_time, end_time} ->
        if Time.compare(start_time, end_time) == :gt do
          add_error(changeset, :end_time, "must be after start time")
        else
          changeset
        end
    end
  end

  def day_name(day_of_week) do
    case day_of_week do
      0 -> "Sunday"
      1 -> "Monday"
      2 -> "Tuesday"
      3 -> "Wednesday"
      4 -> "Thursday"
      5 -> "Friday"
      6 -> "Saturday"
    end
  end
end
