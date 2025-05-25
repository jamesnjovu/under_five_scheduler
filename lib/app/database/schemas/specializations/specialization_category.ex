defmodule App.Config.SpecializationCategory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "specialization_categories" do
    field :code, :string
    field :name, :string
    field :description, :string
    field :display_order, :integer, default: 0
    field :is_active, :boolean, default: true

    has_many :specializations, App.Config.Specialization, foreign_key: :category_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:code, :name, :description, :display_order, :is_active])
    |> validate_required([:code, :name])
    |> validate_format(:code, ~r/^[a-z_]+$/, message: "must contain only lowercase letters and underscores")
    |> unique_constraint(:code)
  end
end