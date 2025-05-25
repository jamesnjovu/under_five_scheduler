defmodule App.Scheduling.Provider do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.User
  alias App.Scheduling.{Schedule, Appointment}
  alias App.Config.Specializations

  schema "providers" do
    field :name, :string
    field :specialization, :string
    field :license_number, :string
    field :is_active, :boolean, default: true

    belongs_to :user, User
    has_many :schedules, Schedule
    has_many :appointments, Appointment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [:name, :specialization, :license_number, :is_active, :user_id])
    |> validate_required([:name, :specialization, :user_id])
    |> validate_specialization()
    |> validate_license_if_required()
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_specialization(changeset) do
    validate_inclusion(changeset, :specialization, Specializations.valid_codes(),
      message: "must be a valid specialization"
    )
  end

  defp validate_license_if_required(changeset) do
    case get_change(changeset, :specialization) do
      nil -> changeset
      specialization ->
        spec_config = Specializations.get_by_code(specialization)
        if spec_config && spec_config.requires_license do
          validate_required(changeset, [:license_number])
        else
          changeset
        end
    end
  end

  @doc """
  Returns the display name for the provider's specialization.
  """
  def specialization_display_name(%__MODULE__{specialization: specialization}) do
    Specializations.display_name(specialization)
  end

  @doc """
  Returns the description for the provider's specialization.
  """
  def specialization_description(%__MODULE__{specialization: specialization}) do
    Specializations.description(specialization)
  end

  @doc """
  Returns true if the provider can prescribe medications.
  """
  def can_prescribe?(%__MODULE__{specialization: specialization}) do
    spec_config = Specializations.get_by_code(specialization)
    spec_config && spec_config.can_prescribe
  end

  @doc """
  Returns true if the provider's specialization requires a license.
  """
  def requires_license?(%__MODULE__{specialization: specialization}) do
    spec_config = Specializations.get_by_code(specialization)
    spec_config && spec_config.requires_license
  end

  @doc """
  Returns the icon for the provider's specialization.
  """
  def specialization_icon(%__MODULE__{specialization: specialization}) do
    Specializations.icon(specialization)
  end

  def available_slots(_provider, _date) do
    # This would be implemented to return available time slots for a given date
    # based on the provider's schedule and existing appointments
    []
  end
end