defmodule App.Config.Specialization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "specializations" do
    field :code, :string
    field :name, :string
    field :description, :string
    field :requires_license, :boolean, default: true
    field :can_prescribe, :boolean, default: false
    field :icon, :string, default: "user-md"
    field :display_order, :integer, default: 0
    field :is_active, :boolean, default: true

    belongs_to :category, App.Config.SpecializationCategory
    has_many :providers, App.Scheduling.Provider, foreign_key: :specialization_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(specialization, attrs) do
    specialization
    |> cast(attrs, [:code, :name, :description, :requires_license, :can_prescribe, :icon, :display_order, :is_active, :category_id])
    |> validate_required([:code, :name, :category_id])
    |> validate_format(:code, ~r/^[a-z_]+$/, message: "must contain only lowercase letters and underscores")
    |> unique_constraint(:code)
    |> foreign_key_constraint(:category_id)
  end

  @doc """
  Returns the display name for the specialization.
  """
  def display_name(%__MODULE__{name: name}), do: name

  @doc """
  Returns the description for the specialization.
  """
  def description(%__MODULE__{description: description}), do: description

  @doc """
  Returns true if the specialization can prescribe medications.
  """
  def can_prescribe?(%__MODULE__{can_prescribe: can_prescribe}), do: can_prescribe

  @doc """
  Returns true if the specialization requires a license.
  """
  def requires_license?(%__MODULE__{requires_license: requires_license}), do: requires_license

  @doc """
  Returns the icon for the specialization.
  """
  def icon(%__MODULE__{icon: icon}), do: icon || "user-md"
end
