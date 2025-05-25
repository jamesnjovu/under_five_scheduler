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

  @doc """
  Enhanced function to calculate the next recommended checkup age and details.
  Returns a map with comprehensive information about when the next checkup should occur.
  """
  def next_checkup_age(%__MODULE__{} = child) do
    age_months = age_in_months(child)
    current_age_years = age(child)

    # Define WHO recommended checkup schedule
    checkup_schedule = [
      %{months: 0, description: "Birth", type: "immediate"},
      %{months: 2, description: "2 months", type: "routine"},
      %{months: 4, description: "4 months", type: "routine"},
      %{months: 6, description: "6 months", type: "routine"},
      %{months: 9, description: "9 months", type: "routine"},
      %{months: 12, description: "12 months (1 year)", type: "milestone"},
      %{months: 15, description: "15 months", type: "routine"},
      %{months: 18, description: "18 months", type: "routine"},
      %{months: 24, description: "24 months (2 years)", type: "milestone"},
      %{months: 30, description: "30 months", type: "routine"},
      %{months: 36, description: "36 months (3 years)", type: "milestone"},
      %{months: 48, description: "48 months (4 years)", type: "milestone"},
      %{months: 60, description: "60 months (5 years)", type: "milestone"}
    ]

    # Find the next checkup
    next_checkup = Enum.find(checkup_schedule, fn schedule ->
      schedule.months > age_months
    end)

    case next_checkup do
      nil ->
        # Child is over 5 years old - recommend annual checkups
        %{
          description: "Annual checkup recommended",
          type: "annual",
          months_until: 12 - rem(age_months, 12),
          age_at_checkup: "#{current_age_years + 1} years",
          is_overdue: false,
          priority: "low",
          recommendations: ["General health assessment", "Growth monitoring", "Developmental screening"]
        }

      checkup ->
        months_until = checkup.months - age_months
        is_overdue = months_until < 0

        # Calculate priority based on type and timing
        priority = cond do
          is_overdue -> "high"
          checkup.type == "milestone" -> "high"
          months_until <= 1 -> "medium"
          true -> "low"
        end

        # Generate age-specific recommendations
        recommendations = get_checkup_recommendations(checkup.months)

        %{
          description: checkup.description,
          type: checkup.type,
          months_until: abs(months_until),
          age_at_checkup: format_age_at_checkup(checkup.months),
          is_overdue: is_overdue,
          priority: priority,
          recommendations: recommendations,
          target_date: calculate_target_date(child.date_of_birth, checkup.months)
        }
    end
  end

  @doc """
  Legacy function maintained for backwards compatibility.
  """
  def next_checkup_age_simple(%__MODULE__{} = child) do
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

  @doc """
  Calculate age in months with enhanced precision.
  """
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

  @doc """
  Calculate age in days for more precise calculations.
  """
  def age_in_days(%__MODULE__{date_of_birth: dob}) do
    today = Date.utc_today()
    Date.diff(today, dob)
  end

  @doc """
  Calculate age in weeks.
  """
  def age_in_weeks(%__MODULE__{date_of_birth: dob}) do
    age_in_days(%__MODULE__{date_of_birth: dob}) |> div(7)
  end

  @doc """
  Get a formatted age string that's human-readable.
  """
  def formatted_age(%__MODULE__{} = child) do
    age_months = age_in_months(child)
    age_years = age(child)

    cond do
      age_months < 1 ->
        weeks = age_in_weeks(child)
        days = age_in_days(child)

        cond do
          weeks < 1 -> "#{days} day#{if days == 1, do: "", else: "s"} old"
          weeks < 4 -> "#{weeks} week#{if weeks == 1, do: "", else: "s"} old"
          true -> "#{age_months} month#{if age_months == 1, do: "", else: "s"} old"
        end

      age_months < 24 ->
        "#{age_months} month#{if age_months == 1, do: "", else: "s"} old"

      age_years < 5 ->
        months_remainder = rem(age_months, 12)
        if months_remainder == 0 do
          "#{age_years} year#{if age_years == 1, do: "", else: "s"} old"
        else
          "#{age_years} year#{if age_years == 1, do: "", else: "s"}, #{months_remainder} month#{if months_remainder == 1, do: "", else: "s"} old"
        end

      true ->
        "#{age_years} years old"
    end
  end

  @doc """
  Check if the child is due for a checkup based on their age and last appointment.
  """
  def due_for_checkup?(%__MODULE__{} = child, last_appointment_date \\ nil) do
    checkup_info = next_checkup_age(child)

    case last_appointment_date do
      nil ->
        # No previous appointment, check if overdue or due soon
        checkup_info.is_overdue or checkup_info.months_until <= 1

      last_date ->
        # Calculate days since last appointment
        days_since = Date.diff(Date.utc_today(), last_date)

        # If it's been more than the expected interval, they're due
        expected_interval_days = case checkup_info.type do
          "immediate" -> 0
          "routine" -> 90  # ~3 months
          "milestone" -> 180  # ~6 months
          "annual" -> 365
          _ -> 90
        end

        days_since >= expected_interval_days
    end
  end

  # Private helper functions

  defp format_age_at_checkup(months) do
    cond do
      months == 0 -> "At birth"
      months < 12 -> "#{months} month#{if months == 1, do: "", else: "s"}"
      months == 12 -> "1 year"
      months < 24 -> "#{months} months"
      months == 24 -> "2 years"
      months < 36 -> "#{Float.round(months / 12, 1)} years"
      true -> "#{div(months, 12)} year#{if div(months, 12) == 1, do: "", else: "s"}"
    end
  end

  defp calculate_target_date(birth_date, target_months) do
    # Add months to birth date
    target_year = birth_date.year + div(target_months, 12)
    target_month = birth_date.month + rem(target_months, 12)

    # Handle month overflow
    {final_year, final_month} = if target_month > 12 do
      {target_year + 1, target_month - 12}
    else
      {target_year, target_month}
    end

    # Create the target date, handling invalid dates (like Feb 30)
    case Date.new(final_year, final_month, birth_date.day) do
      {:ok, date} -> date
      {:error, :invalid_date} ->
        # If day doesn't exist in target month, use last day of month
        last_day = Date.days_in_month(Date.new!(final_year, final_month, 1))
        Date.new!(final_year, final_month, last_day)
    end
  end

  defp get_checkup_recommendations(age_months) do
    base_recommendations = ["Physical examination", "Growth measurements", "Developmental assessment"]

    age_specific = case age_months do
      0 -> ["Newborn screening", "Feeding assessment", "Vitamin K administration"]

      months when months in [2, 4, 6] ->
        ["Immunizations", "Feeding guidance", "Sleep patterns", "Safety counseling"]

      9 -> ["Lead screening", "Immunizations", "Nutrition guidance", "Injury prevention"]

      12 -> ["Lead screening", "Immunizations", "Transition to whole milk", "Developmental milestones"]

      months when months in [15, 18] ->
        ["Immunizations", "Language development", "Behavior guidance", "Dental care"]

      24 -> ["Vision screening", "Autism screening", "Dental care", "Potty training readiness"]

      36 -> ["Vision screening", "Hearing screening", "School readiness", "Behavioral assessment"]

      48 -> ["Vision screening", "School readiness assessment", "Behavioral evaluation"]

      60 -> ["School physical", "Vision and hearing screening", "Immunization update"]

      _ -> ["Age-appropriate screening", "Preventive care"]
    end

    base_recommendations ++ age_specific
  end
end
