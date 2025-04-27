defmodule App.Accounts.Child do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.User
  alias App.Scheduling.Appointment

  schema "children" do
    field :date_of_birth, :date
    field :medical_record_number, :string
    field :name, :string

    belongs_to :user, User
    has_many :appointments, Appointment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(child, attrs) do
    child
    |> cast(attrs, [:name, :date_of_birth, :medical_record_number, :user_id])
    |> validate_required([:name, :date_of_birth, :user_id])
    |> validate_date_of_birth()
    |> generate_medical_record_number()
    |> unique_constraint(:medical_record_number)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_date_of_birth(changeset) do
    case get_change(changeset, :date_of_birth) do
      nil -> changeset
      date ->
        today = Date.utc_today()
        years_ago = Date.add(today, -5 * 365)

        if Date.compare(date, years_ago) == :lt do
          add_error(changeset, :date_of_birth, "child must be under 5 years old")
        else
          if Date.compare(date, today) == :gt do
            add_error(changeset, :date_of_birth, "cannot be in the future")
          else
            changeset
          end
        end
    end
  end

  defp generate_medical_record_number(changeset) do
    if get_change(changeset, :medical_record_number) do
      changeset
    else
      put_change(changeset, :medical_record_number, generate_mrn())
    end
  end

  defp generate_mrn do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :rand.uniform(9999)
    "MRN#{timestamp}#{random}"
  end

  def age(%__MODULE__{date_of_birth: dob}) do
    today = Date.utc_today()

    years = today.year - dob.year

    if today.month < dob.month || (today.month == dob.month && today.day < dob.day) do
      years - 1
    else
      years
    end
  end

  def next_checkup_age(%__MODULE__{} = child) do
    age = age(child)

    cond do
      age < 1 -> "#{(age + 1) * 2} months"
      age < 2 -> "#{age + 1} year"
      true -> "#{age + 1} years"
    end
  end
end
