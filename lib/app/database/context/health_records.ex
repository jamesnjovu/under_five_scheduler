defmodule App.HealthRecords do
  @moduledoc """
  The HealthRecords context.
  """

  import Ecto.Query, warn: false
  alias App.Repo

  alias App.HealthRecords.Growth
  alias App.HealthRecords.Immunization
  alias App.HealthRecords.VaccineSchedule
  alias App.Accounts.Child

  # Growth record functions

  @doc """
  Returns the list of growth records for a specific child, ordered by date.
  """
  def list_growth_records(child_id) do
    Growth
    |> where([g], g.child_id == ^child_id)
    |> order_by([g], desc: g.measurement_date)
    |> Repo.all()
  end

  @doc """
  Gets a single growth record.
  Raises `Ecto.NoResultsError` if the Growth record does not exist.
  """
  def get_growth_record!(id), do: Repo.get!(Growth, id)

  @doc """
  Creates a growth record.
  """
  def create_growth_record(attrs \\ %{}) do
    %Growth{}
    |> Growth.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a growth record.
  """
  def update_growth_record(%Growth{} = growth, attrs) do
    growth
    |> Growth.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a growth record.
  """
  def delete_growth_record(%Growth{} = growth) do
    Repo.delete(growth)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking growth record changes.
  """
  def change_growth_record(%Growth{} = growth, attrs \\ %{}) do
    Growth.changeset(growth, attrs)
  end

  @doc """
  Gets the latest growth record for a child.
  """
  def get_latest_growth_record(child_id) do
    Growth
    |> where([g], g.child_id == ^child_id)
    |> order_by([g], desc: g.measurement_date)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Calculate growth percentiles based on WHO growth standards.
  This is a simplified implementation - in a real application, you would use
  standardized growth charts and more sophisticated calculations.
  """
  def calculate_growth_percentiles(child_id) do
    child = App.Accounts.get_child!(child_id)
    latest_growth = get_latest_growth_record(child_id)

    if latest_growth do
      age_months = calculate_age_in_months(child.date_of_birth, latest_growth.measurement_date)

      # This would normally use WHO growth charts - this is simplified
      weight_percentile = calculate_weight_percentile(latest_growth.weight, age_months, child)
      height_percentile = calculate_height_percentile(latest_growth.height, age_months, child)

      %{
        weight_percentile: weight_percentile,
        height_percentile: height_percentile,
        bmi: calculate_bmi(latest_growth.weight, latest_growth.height),
        age_in_months: age_months
      }
    else
      nil
    end
  end

  # Simplified percentile calculations - in reality you would use standard growth charts
  defp calculate_weight_percentile(weight, age_months, child) do
    # Simplified calculation - in a real app, reference WHO growth charts
    # This returns a random value for demonstration purposes
    :rand.uniform(100)
  end

  defp calculate_height_percentile(height, age_months, child) do
    # Simplified calculation - in a real app, reference WHO growth charts
    # This returns a random value for demonstration purposes
    :rand.uniform(100)
  end

  defp calculate_bmi(weight, height) do
    # BMI = weight(kg) / (height(m))²
    height_in_meters = Decimal.div(height, Decimal.new(100))
    weight_in_kg = weight

    height_squared = Decimal.mult(height_in_meters, height_in_meters)

    Decimal.div(weight_in_kg, height_squared)
    |> Decimal.round(1)
  end

  defp calculate_age_in_months(birth_date, measurement_date) do
    # Calculate months between dates
    years = measurement_date.year - birth_date.year
    months = measurement_date.month - birth_date.month

    total_months = years * 12 + months

    # Adjust if measurement date is before the day of birth in the final month
    if measurement_date.day < birth_date.day and total_months > 0 do
      total_months - 1
    else
      total_months
    end
  end

  # Immunization functions

  @doc """
  Returns the list of immunization records for a specific child.
  """
  def list_immunization_records(child_id) do
    Immunization
    |> where([i], i.child_id == ^child_id)
    |> order_by([i], desc: i.administered_date, desc: i.due_date)
    |> Repo.all()
  end

  @doc """
  Gets a single immunization record.
  """
  def get_immunization_record!(id), do: Repo.get!(Immunization, id)

  @doc """
  Creates an immunization record.
  """
  def create_immunization_record(attrs \\ %{}) do
    %Immunization{}
    |> Immunization.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an immunization record.
  """
  def update_immunization_record(%Immunization{} = immunization, attrs) do
    immunization
    |> Immunization.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an immunization record.
  """
  def delete_immunization_record(%Immunization{} = immunization) do
    Repo.delete(immunization)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking immunization record changes.
  """
  def change_immunization_record(%Immunization{} = immunization, attrs \\ %{}) do
    Immunization.changeset(immunization, attrs)
  end

  @doc """
  Gets upcoming immunizations for a child.
  """
  def get_upcoming_immunizations(child_id) do
    today = Date.utc_today()

    Immunization
    |> where([i], i.child_id == ^child_id and i.status == "scheduled" and i.due_date >= ^today)
    |> order_by([i], asc: i.due_date)
    |> Repo.all()
  end

  @doc """
  Gets missed immunizations for a child.
  """
  def get_missed_immunizations(child_id) do
    today = Date.utc_today()

    Immunization
    |> where(
      [i],
      i.child_id == ^child_id and
        ((i.status == "scheduled" and i.due_date < ^today) or
           i.status == "missed")
    )
    |> order_by([i], asc: i.due_date)
    |> Repo.all()
  end

  @doc """
  Generate immunization schedule for a child based on their age.
  This creates scheduled immunization records based on vaccine_schedules.
  """
  def generate_immunization_schedule(child_id) do
    child = App.Accounts.get_child!(child_id)
    birth_date = child.date_of_birth

    # Get all vaccine schedules
    vaccine_schedules = list_vaccine_schedules()

    # For each vaccine in the schedule, create a scheduled immunization record
    Enum.map(vaccine_schedules, fn schedule ->
      # Calculate the due date based on birth date and recommended age
      due_date = calculate_due_date(birth_date, schedule.recommended_age_months)

      # Check if this vaccine already exists for the child
      existing = get_existing_vaccine_record(child_id, schedule.vaccine_name)

      if existing do
        # If it exists, don't create a new one
        {:ok, existing}
      else
        # Create a new scheduled immunization record
        create_immunization_record(%{
          child_id: child_id,
          vaccine_name: schedule.vaccine_name,
          due_date: due_date,
          status: "scheduled"
        })
      end
    end)
  end

  defp calculate_due_date(birth_date, months_to_add) do
    # Add the specified number of months to the birth date
    years_to_add = div(months_to_add, 12)
    remaining_months = rem(months_to_add, 12)

    # Add years first
    date_with_years = %{birth_date | year: birth_date.year + years_to_add}

    # Then add months, handling overflow
    new_month = date_with_years.month + remaining_months

    if new_month > 12 do
      %{
        date_with_years
        | year: date_with_years.year + div(new_month - 1, 12),
          month: rem(new_month - 1, 12) + 1
      }
    else
      %{date_with_years | month: new_month}
    end
  end

  defp get_existing_vaccine_record(child_id, vaccine_name) do
    Immunization
    |> where([i], i.child_id == ^child_id and i.vaccine_name == ^vaccine_name)
    |> Repo.one()
  end

  # Vaccine schedule functions

  @doc """
  Returns the list of vaccine schedules.
  """
  def list_vaccine_schedules do
    VaccineSchedule
    |> order_by([v], asc: v.recommended_age_months)
    |> Repo.all()
  end

  @doc """
  Gets a single vaccine_schedule.
  """
  def get_vaccine_schedule!(id), do: Repo.get!(VaccineSchedule, id)

  @doc """
  Creates a vaccine_schedule.
  """
  def create_vaccine_schedule(attrs \\ %{}) do
    %VaccineSchedule{}
    |> VaccineSchedule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a vaccine_schedule.
  """
  def update_vaccine_schedule(%VaccineSchedule{} = vaccine_schedule, attrs) do
    vaccine_schedule
    |> VaccineSchedule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a vaccine_schedule.
  """
  def delete_vaccine_schedule(%VaccineSchedule{} = vaccine_schedule) do
    Repo.delete(vaccine_schedule)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vaccine_schedule changes.
  """
  def change_vaccine_schedule(%VaccineSchedule{} = vaccine_schedule, attrs \\ %{}) do
    VaccineSchedule.changeset(vaccine_schedule, attrs)
  end

  @doc """
  Initialize standard vaccine schedules according to WHO recommendations.
  This can be called during system setup or migration.
  """
  def initialize_standard_vaccine_schedules do
    standard_vaccines = [
      %{
        vaccine_name: "BCG",
        description: "Bacillus Calmette-Guérin vaccine",
        recommended_age_months: 0,
        is_mandatory: true
      },
      %{
        vaccine_name: "HepB Birth",
        description: "Hepatitis B vaccine (Birth dose)",
        recommended_age_months: 0,
        is_mandatory: true
      },
      %{
        vaccine_name: "OPV0",
        description: "Oral Polio Vaccine (Birth dose)",
        recommended_age_months: 0,
        is_mandatory: true
      },
      %{
        vaccine_name: "OPV1",
        description: "Oral Polio Vaccine (First dose)",
        recommended_age_months: 2,
        is_mandatory: true
      },
      %{
        vaccine_name: "OPV2",
        description: "Oral Polio Vaccine (Second dose)",
        recommended_age_months: 4,
        is_mandatory: true
      },
      %{
        vaccine_name: "OPV3",
        description: "Oral Polio Vaccine (Third dose)",
        recommended_age_months: 6,
        is_mandatory: true
      },
      %{
        vaccine_name: "DTP1",
        description: "Diphtheria, Tetanus, Pertussis (First dose)",
        recommended_age_months: 2,
        is_mandatory: true
      },
      %{
        vaccine_name: "DTP2",
        description: "Diphtheria, Tetanus, Pertussis (Second dose)",
        recommended_age_months: 4,
        is_mandatory: true
      },
      %{
        vaccine_name: "DTP3",
        description: "Diphtheria, Tetanus, Pertussis (Third dose)",
        recommended_age_months: 6,
        is_mandatory: true
      },
      %{
        vaccine_name: "Hib1",
        description: "Haemophilus influenzae type b (First dose)",
        recommended_age_months: 2,
        is_mandatory: true
      },
      %{
        vaccine_name: "Hib2",
        description: "Haemophilus influenzae type b (Second dose)",
        recommended_age_months: 4,
        is_mandatory: true
      },
      %{
        vaccine_name: "Hib3",
        description: "Haemophilus influenzae type b (Third dose)",
        recommended_age_months: 6,
        is_mandatory: true
      },
      %{
        vaccine_name: "PCV1",
        description: "Pneumococcal conjugate vaccine (First dose)",
        recommended_age_months: 2,
        is_mandatory: true
      },
      %{
        vaccine_name: "PCV2",
        description: "Pneumococcal conjugate vaccine (Second dose)",
        recommended_age_months: 4,
        is_mandatory: true
      },
      %{
        vaccine_name: "PCV3",
        description: "Pneumococcal conjugate vaccine (Third dose)",
        recommended_age_months: 6,
        is_mandatory: true
      },
      %{
        vaccine_name: "RV1",
        description: "Rotavirus vaccine (First dose)",
        recommended_age_months: 2,
        is_mandatory: true
      },
      %{
        vaccine_name: "RV2",
        description: "Rotavirus vaccine (Second dose)",
        recommended_age_months: 4,
        is_mandatory: true
      },
      %{
        vaccine_name: "Measles1",
        description: "Measles vaccine (First dose)",
        recommended_age_months: 9,
        is_mandatory: true
      },
      %{
        vaccine_name: "Measles2",
        description: "Measles vaccine (Second dose)",
        recommended_age_months: 15,
        is_mandatory: true
      },
      %{
        vaccine_name: "YF",
        description: "Yellow Fever vaccine",
        recommended_age_months: 9,
        is_mandatory: true
      }
    ]

    # Insert each standard vaccine
    Enum.each(standard_vaccines, fn vaccine_attrs ->
      # Only insert if doesn't already exist
      case Repo.get_by(VaccineSchedule, vaccine_name: vaccine_attrs.vaccine_name) do
        nil -> create_vaccine_schedule(vaccine_attrs)
        _ -> :already_exists
      end
    end)
  end

  @doc """
  Calculate immunization coverage percentage for a child.
  """
  def calculate_immunization_coverage(child_id) do
    all_records = list_immunization_records(child_id)
    total_count = length(all_records)

    if total_count > 0 do
      administered_count =
        Enum.count(all_records, fn record -> record.status == "administered" end)

      coverage_percentage = administered_count / total_count * 100

      %{
        total_vaccines: total_count,
        administered_vaccines: administered_count,
        coverage_percentage: coverage_percentage,
        missed_vaccines: Enum.count(all_records, fn record -> record.status == "missed" end),
        scheduled_vaccines: Enum.count(all_records, fn record -> record.status == "scheduled" end)
      }
    else
      %{
        total_vaccines: 0,
        administered_vaccines: 0,
        coverage_percentage: 0,
        missed_vaccines: 0,
        scheduled_vaccines: 0
      }
    end
  end
end
