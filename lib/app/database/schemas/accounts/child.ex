defmodule App.Accounts.Child do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Accounts.User
  alias App.Scheduling.Appointment

  @statuses ~w(deleted active grown)

  schema "children" do
    field :date_of_birth, :date
    field :medical_record_number, :string
    field :name, :string
    field :status, :string

    belongs_to :user, User
    has_many :appointments, Appointment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(child, attrs) do
    child
    |> cast(attrs, [:name, :date_of_birth, :medical_record_number, :user_id])
    |> validate_required([:name, :date_of_birth, :user_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_date_of_birth()
    |> generate_medical_record_number()
    |> unique_constraint(:medical_record_number)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_date_of_birth(changeset) do
    case get_change(changeset, :date_of_birth) do
      nil ->
        changeset

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
    age_months = age_in_months(child)

    cond do
      # Under 12 months: checkups at 2, 4, 6, 9, 12 months
      age_months < 2 -> "2 months"
      age_months < 4 -> "4 months"
      age_months < 6 -> "6 months"
      age_months < 9 -> "9 months"
      age_months < 12 -> "12 months"
      # 12-24 months: checkups at 15, 18, 24 months
      age_months < 15 -> "15 months"
      age_months < 18 -> "18 months"
      age_months < 24 -> "24 months"
      # 2-5 years: annual checkups
      age_months < 36 -> "3 years"
      age_months < 48 -> "4 years"
      age_months < 60 -> "5 years"
      true -> "yearly checkup"
    end
  end

  # Helper function to calculate age in months
  def age_in_months(%__MODULE__{date_of_birth: dob}) do
    today = Date.utc_today()

    # Calculate years and months difference
    years_diff = today.year - dob.year
    months_diff = today.month - dob.month

    # Adjust for day of month
    months_diff = if today.day < dob.day, do: months_diff - 1, else: months_diff

    # Convert years to months and add remaining months
    total_months = years_diff * 12 + months_diff

    # Ensure we don't return negative months
    max(0, total_months)
  end
end
