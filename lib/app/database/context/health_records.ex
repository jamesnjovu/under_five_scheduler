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

      # Ensure we always return a float
      coverage_percentage = (administered_count / total_count * 100) |> Float.round(1)

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
        coverage_percentage: 0.0, # Explicitly return float
        missed_vaccines: 0,
        scheduled_vaccines: 0
      }
    end
  end

  @doc """
  Creates a comprehensive health summary for a child during an appointment.
  This includes growth trends, immunization status, and recommendations.
  """
  def create_appointment_health_summary(child_id, appointment_date \\ nil) do
    appointment_date = appointment_date || Date.utc_today()
    child = App.Accounts.get_child!(child_id)

    # Get all health records
    growth_records = list_growth_records(child_id)
    immunization_records = list_immunization_records(child_id)

    # Calculate current metrics
    percentiles = calculate_growth_percentiles(child_id)
    coverage = calculate_immunization_coverage(child_id)

    # Get upcoming and overdue items
    upcoming_immunizations = get_upcoming_immunizations(child_id)
    missed_immunizations = get_missed_immunizations(child_id)

    # Calculate health trends
    growth_trends = calculate_growth_trends(growth_records)

    # Generate recommendations
    recommendations = generate_health_recommendations(child, growth_records, immunization_records, appointment_date)

    %{
      child: child,
      appointment_date: appointment_date,
      growth: %{
        records: growth_records,
        percentiles: percentiles,
        trends: growth_trends
      },
      immunizations: %{
        records: immunization_records,
        coverage: coverage,
        upcoming: upcoming_immunizations,
        missed: missed_immunizations
      },
      recommendations: recommendations,
      next_checkup: calculate_next_checkup_date(child, appointment_date)
    }
  end

  @doc """
  Calculates growth trends over time for better health monitoring.
  """
  def calculate_growth_trends(growth_records) when length(growth_records) >= 2 do
    sorted_records = Enum.sort_by(growth_records, & &1.measurement_date, :asc)

    weight_trend = calculate_metric_trend(sorted_records, :weight)
    height_trend = calculate_metric_trend(sorted_records, :height)
    head_circumference_trend = calculate_metric_trend(sorted_records, :head_circumference)

    %{
      weight: weight_trend,
      height: height_trend,
      head_circumference: head_circumference_trend,
      total_measurements: length(sorted_records),
      date_range: {
        List.first(sorted_records).measurement_date,
        List.last(sorted_records).measurement_date
      }
    }
  end

  def calculate_growth_trends(_), do: %{insufficient_data: true}

  defp calculate_metric_trend(records, metric) do
    values =
      records
      |> Enum.map(fn record -> {record.measurement_date, Map.get(record, metric)} end)
      |> Enum.filter(fn {_, value} -> value != nil end)

    if length(values) >= 2 do
      [{first_date, first_value} | _] = values
      {last_date, last_value} = List.last(values)

      # Calculate rate of change per month
      days_diff = Date.diff(last_date, first_date)
      months_diff = max(days_diff / 30.0, 1.0)  # Ensure it's a float

      rate_of_change =
        Decimal.sub(last_value, first_value)
        |> Decimal.div(Decimal.from_float(months_diff))  # Now it's guaranteed to be a float
        |> Decimal.round(2)

      %{
        current_value: last_value,
        previous_value: first_value,
        rate_per_month: rate_of_change,
        trend_direction: determine_trend_direction(rate_of_change),
        data_points: length(values)
      }
    else
      %{insufficient_data: true}
    end
  end

  defp determine_trend_direction(rate) do
    cond do
      Decimal.compare(rate, Decimal.new("0.1")) == :gt -> :increasing
      Decimal.compare(rate, Decimal.new("-0.1")) == :lt -> :decreasing
      true -> :stable
    end
  end

  @doc """
  Generates personalized health recommendations based on child's records.
  """
  def generate_health_recommendations(child, growth_records, immunization_records, appointment_date) do
    age_months = App.Accounts.Child.age_in_months(child)
    recommendations = []

    # Growth-based recommendations
    recommendations =
      if length(growth_records) >= 2 do
        growth_trends = calculate_growth_trends(growth_records)
        recommendations ++ generate_growth_recommendations(growth_trends, age_months)
      else
        recommendations ++ [%{
          type: :growth,
          priority: :medium,
          message: "Establish baseline growth measurements with regular monitoring"
        }]
      end

    # Immunization recommendations
    missed_count = Enum.count(immunization_records, &(&1.status == "missed"))
    upcoming_count = Enum.count(get_upcoming_immunizations(child.id))

    recommendations =
      cond do
        missed_count > 0 ->
          recommendations ++ [%{
            type: :immunization,
            priority: :high,
            message: "#{missed_count} missed vaccination(s) need immediate attention"
          }]

        upcoming_count > 0 ->
          recommendations ++ [%{
            type: :immunization,
            priority: :medium,
            message: "#{upcoming_count} vaccination(s) due soon"
          }]

        true ->
          recommendations ++ [%{
            type: :immunization,
            priority: :low,
            message: "Immunization schedule is up to date"
          }]
      end

    # Age-specific recommendations
    recommendations = recommendations ++ generate_age_specific_recommendations(age_months)

    recommendations
  end

  defp generate_growth_recommendations(trends, age_months) do
    recommendations = []

    # Weight trend analysis
    recommendations =
      case trends.weight.trend_direction do
        :decreasing when age_months < 24 ->
          recommendations ++ [%{
            type: :growth,
            priority: :high,
            message: "Weight loss detected in infant - requires immediate evaluation"
          }]

        :decreasing ->
          recommendations ++ [%{
            type: :growth,
            priority: :medium,
            message: "Declining weight trend - monitor nutrition and feeding patterns"
          }]

        _ -> recommendations
      end

    # Height trend analysis
    recommendations =
      case trends.height.trend_direction do
        :decreasing ->
          recommendations ++ [%{
            type: :growth,
            priority: :medium,
            message: "Height growth appears to be slowing - consider nutritional assessment"
          }]

        _ -> recommendations
      end

    recommendations
  end

  defp generate_age_specific_recommendations(age_months) do
    cond do
      age_months < 6 ->
        [%{
          type: :developmental,
          priority: :medium,
          message: "Monitor feeding patterns, sleep schedule, and developmental milestones"
        }]

      age_months < 12 ->
        [%{
          type: :developmental,
          priority: :medium,
          message: "Introduce solid foods if not started, continue breastfeeding"
        }]

      age_months < 24 ->
        [%{
          type: :developmental,
          priority: :medium,
          message: "Monitor speech development, mobility, and social interactions"
        }]

      age_months < 60 ->
        [%{
          type: :developmental,
          priority: :medium,
          message: "Assess school readiness, social skills, and physical coordination"
        }]

      true ->
        [%{
          type: :general,
          priority: :low,
          message: "Continue regular health monitoring and preventive care"
        }]
    end
  end

  @doc """
  Calculates the recommended date for next checkup based on WHO guidelines.
  """
  def calculate_next_checkup_date(child, current_date \\ nil) do
    current_date = current_date || Date.utc_today()
    age_months = App.Accounts.Child.age_in_months(child)

    months_until_next = case age_months do
      months when months < 2 -> 2 - months
      months when months < 4 -> 4 - months
      months when months < 6 -> 6 - months
      months when months < 9 -> 9 - months
      months when months < 12 -> 12 - months
      months when months < 15 -> 15 - months
      months when months < 18 -> 18 - months
      months when months < 24 -> 24 - months
      months when months < 36 -> 36 - months
      months when months < 48 -> 48 - months
      months when months < 60 -> 60 - months
      _ -> 12 # Annual checkups after age 5
    end

    Date.add(current_date, trunc(months_until_next * 30))
  end

  @doc """
  Creates a health record entry for the appointment visit.
  This can be used to track what was done during each visit.
  """
  def create_visit_record(appointment_id, provider_id, child_id, visit_data) do
    # This would create a comprehensive visit record
    # Including all health activities performed during the appointment

    visit_record = %{
      appointment_id: appointment_id,
      provider_id: provider_id,
      child_id: child_id,
      visit_date: Date.utc_today(),
      activities: visit_data.activities || [],
      assessments: visit_data.assessments || [],
      growth_recorded: visit_data.growth_recorded || false,
      immunizations_given: visit_data.immunizations_given || [],
      recommendations: visit_data.recommendations || [],
      next_visit_due: calculate_next_checkup_date(App.Accounts.get_child!(child_id))
    }

    # In a real implementation, you might want to store this in a separate table
    # For now, we'll return the structured data
    {:ok, visit_record}
  end

  @doc """
  Gets health alerts for a child that need provider attention.
  """
  def get_health_alerts(child_id) do
    child = App.Accounts.get_child!(child_id)
    age_months = App.Accounts.Child.age_in_months(child)

    alerts = []

    # Check for overdue immunizations
    missed_immunizations = get_missed_immunizations(child_id)
    alerts =
      if length(missed_immunizations) > 0 do
        alerts ++ [%{
          type: :immunization,
          severity: :high,
          message: "#{length(missed_immunizations)} overdue immunization(s)",
          action_required: "Schedule immediate catch-up vaccinations"
        }]
      else
        alerts
      end

    # Check for growth concerns
    latest_growth = get_latest_growth_record(child_id)
    if latest_growth do
      days_since_measurement = Date.diff(Date.utc_today(), latest_growth.measurement_date)
      expected_interval = if age_months < 12, do: 90, else: 180  # 3 or 6 months

      alerts =
        if days_since_measurement > expected_interval do
          alerts ++ [%{
            type: :growth,
            severity: :medium,
            message: "Growth measurements overdue",
            action_required: "Record current weight and height measurements"
          }]
        else
          alerts
        end
    else
      alerts = alerts ++ [%{
        type: :growth,
        severity: :medium,
        message: "No growth records available",
        action_required: "Establish baseline growth measurements"
      }]
    end

    alerts
  end

  # Add these functions to your existing lib/app/database/context/health_records.ex

  @doc """
  Enhanced function to get the next recommended checkup date with detailed information.
  """
  def get_next_checkup_recommendation(child_id) do
    child = App.Accounts.get_child!(child_id)
    last_appointment = get_last_completed_appointment(child_id)

    checkup_info = App.Accounts.Child.next_checkup_age(child)

    # Get health context
    growth_records = list_growth_records(child_id) |> Enum.take(3)
    immunization_coverage = calculate_immunization_coverage(child_id)
    pending_immunizations = get_upcoming_immunizations(child_id)

    %{
      child: child,
      checkup_info: checkup_info,
      last_appointment: last_appointment,
      health_context: %{
        recent_growth: growth_records,
        immunization_coverage: immunization_coverage,
        pending_immunizations: pending_immunizations,
        health_alerts: get_health_alerts(child_id)
      },
      recommendation_priority: determine_checkup_priority(checkup_info, last_appointment, immunization_coverage)
    }
  end

  @doc """
  Get comprehensive child health dashboard data.
  """
  def get_child_health_dashboard(child_id) do
    child = App.Accounts.get_child!(child_id)

    # Get all health data
    growth_records = list_growth_records(child_id)
    immunization_records = list_immunization_records(child_id)

    # Calculate health metrics
    growth_trends = if length(growth_records) >= 2, do: calculate_growth_trends(growth_records), else: nil
    immunization_coverage = calculate_immunization_coverage(child_id)
    next_checkup = get_next_checkup_recommendation(child_id)

    # Get milestone tracking
    milestones = get_developmental_milestones_status(child)

    %{
      child: child,
      health_summary: %{
        total_visits: count_completed_appointments(child_id),
        growth_records_count: length(growth_records),
        immunizations_completed: immunization_coverage.administered_vaccines,
        immunization_coverage_percent: immunization_coverage.coverage_percentage
      },
      growth: %{
        records: growth_records,
        trends: growth_trends,
        latest: List.first(growth_records)
      },
      immunizations: %{
        records: immunization_records,
        coverage: immunization_coverage,
        upcoming: get_upcoming_immunizations(child_id),
        overdue: get_missed_immunizations(child_id)
      },
      next_checkup: next_checkup,
      milestones: milestones,
      alerts: get_health_alerts(child_id)
    }
  end

  @doc """
  Get developmental milestones status based on child's age.
  """
  def get_developmental_milestones_status(child) do
    age_months = App.Accounts.Child.age_in_months(child)

    milestones = [
      %{age: 2, milestone: "Lifts head when on tummy", category: "physical"},
      %{age: 4, milestone: "Holds head steady", category: "physical"},
      %{age: 6, milestone: "Sits with support", category: "physical"},
      %{age: 9, milestone: "Sits without support", category: "physical"},
      %{age: 12, milestone: "Pulls to stand", category: "physical"},
      %{age: 15, milestone: "Walks independently", category: "physical"},
      %{age: 18, milestone: "Runs steadily", category: "physical"},
      %{age: 24, milestone: "Jumps with both feet", category: "physical"},

      %{age: 4, milestone: "Smiles responsively", category: "social"},
      %{age: 6, milestone: "Recognizes familiar faces", category: "social"},
      %{age: 9, milestone: "Shows stranger anxiety", category: "social"},
      %{age: 12, milestone: "Waves bye-bye", category: "social"},
      %{age: 18, milestone: "Shows affection", category: "social"},
      %{age: 24, milestone: "Plays alongside others", category: "social"},

      %{age: 6, milestone: "Responds to name", category: "language"},
      %{age: 9, milestone: "Says 'mama' or 'dada'", category: "language"},
      %{age: 12, milestone: "Says first words", category: "language"},
      %{age: 18, milestone: "Says 10+ words", category: "language"},
      %{age: 24, milestone: "Combines words", category: "language"},
      %{age: 36, milestone: "Speaks in sentences", category: "language"}
    ]

    # Filter milestones for current age and categorize
    current_milestones = Enum.filter(milestones, &(&1.age <= age_months + 2))
    upcoming_milestones = Enum.filter(milestones, &(&1.age > age_months and &1.age <= age_months + 6))

    %{
      age_months: age_months,
      current: Enum.group_by(current_milestones, & &1.category),
      upcoming: Enum.group_by(upcoming_milestones, & &1.category),
      total_expected: length(current_milestones)
    }
  end

  @doc """
  Enhanced vaccine schedule management with WHO compliance checking.
  """
  def validate_vaccine_schedule_compliance(child_id) do
    child = App.Accounts.get_child!(child_id)
    age_months = App.Accounts.Child.age_in_months(child)

    # Get all vaccines that should have been administered by now
    expected_vaccines = list_vaccine_schedules()
                        |> Enum.filter(&(&1.recommended_age_months <= age_months))

    # Get actual immunization records
    actual_records = list_immunization_records(child_id)

    # Calculate compliance
    compliance_report = Enum.map(expected_vaccines, fn vaccine ->
      actual_record = Enum.find(actual_records, &(&1.vaccine_name == vaccine.vaccine_name))

      status = case actual_record do
        nil -> "missing"
        %{status: "administered"} -> "completed"
        %{status: "scheduled"} -> "scheduled"
        %{status: "missed"} -> "missed"
        _ -> "unknown"
      end

      delay_months = if actual_record && actual_record.administered_date do
        administered_age = calculate_age_at_date(child.date_of_birth, actual_record.administered_date)
        max(0, administered_age - vaccine.recommended_age_months)
      else
        if status == "missing", do: age_months - vaccine.recommended_age_months, else: 0
      end

      %{
        vaccine: vaccine,
        status: status,
        actual_record: actual_record,
        delay_months: delay_months,
        is_overdue: status in ["missing", "missed"] and delay_months > 2,
        priority: determine_vaccine_priority(vaccine, status, delay_months)
      }
    end)

    # Calculate overall compliance metrics
    total_expected = length(expected_vaccines)
    completed = Enum.count(compliance_report, &(&1.status == "completed"))
    overdue = Enum.count(compliance_report, &(&1.is_overdue))
    scheduled = Enum.count(compliance_report, &(&1.status == "scheduled"))

    compliance_percentage = if total_expected > 0, do: completed / total_expected * 100, else: 100.0

    %{
      child: child,
      age_months: age_months,
      vaccines: compliance_report,
      summary: %{
        total_expected: total_expected,
        completed: completed,
        overdue: overdue,
        scheduled: scheduled,
        compliance_percentage: Float.round(compliance_percentage, 1)
      },
      recommendations: generate_vaccination_recommendations(compliance_report),
      next_due: get_next_due_vaccines(child, compliance_report)
    }
  end

  @doc """
  Generate age-appropriate immunization schedule for a new child.
  """
  def generate_personalized_immunization_schedule(child_id) do
    child = App.Accounts.get_child!(child_id)
    current_age_months = App.Accounts.Child.age_in_months(child)

    # Get all vaccine schedules
    all_vaccines = list_vaccine_schedules()

    # Generate schedule based on current age
    schedule = Enum.map(all_vaccines, fn vaccine ->
      # Calculate when this vaccine should be given
      due_date = if vaccine.recommended_age_months <= current_age_months do
        # Already due - schedule ASAP
        Date.add(Date.utc_today(), 7) # Next week
      else
        # Calculate future date
        App.Accounts.Child.calculate_target_date(child.date_of_birth, vaccine.recommended_age_months)
      end

      # Determine urgency
      urgency = cond do
        vaccine.recommended_age_months < current_age_months - 2 -> "overdue"
        vaccine.recommended_age_months <= current_age_months -> "due_now"
        vaccine.recommended_age_months <= current_age_months + 2 -> "due_soon"
        true -> "future"
      end

      %{
        vaccine: vaccine,
        due_date: due_date,
        age_at_vaccination: vaccine.recommended_age_months,
        urgency: urgency,
        can_combine: can_combine_with_other_vaccines?(vaccine),
        special_instructions: get_vaccine_instructions(vaccine)
      }
    end)
               |> Enum.sort_by(&{&1.urgency == "overdue", &1.due_date})

    %{
      child: child,
      current_age_months: current_age_months,
      schedule: schedule,
      overdue_count: Enum.count(schedule, &(&1.urgency == "overdue")),
      due_now_count: Enum.count(schedule, &(&1.urgency == "due_now")),
      next_appointment_recommended: get_earliest_due_date(schedule)
    }
  end

  @doc """
  Create comprehensive vaccination catch-up plan for children behind schedule.
  """
  def create_catch_up_vaccination_plan(child_id) do
    compliance = validate_vaccine_schedule_compliance(child_id)
    overdue_vaccines = Enum.filter(compliance.vaccines, &(&1.is_overdue))

    if length(overdue_vaccines) == 0 do
      %{message: "Child is up to date with vaccinations", plan: []}
    else
      # Group vaccines by visit possibility
      catch_up_visits = plan_catch_up_visits(overdue_vaccines, compliance.child)

      %{
        child: compliance.child,
        overdue_vaccines: overdue_vaccines,
        catch_up_visits: catch_up_visits,
        total_visits_needed: length(catch_up_visits),
        estimated_completion: estimate_catch_up_completion(catch_up_visits),
        priority_vaccines: Enum.filter(overdue_vaccines, &(&1.vaccine.is_mandatory)),
        safety_considerations: get_catch_up_safety_notes(overdue_vaccines)
      }
    end
  end

  # Private helper functions

  defp get_last_completed_appointment(child_id) do
    App.Scheduling.list_appointments(child_id: child_id)
    |> Enum.filter(&(&1.status == "completed"))
    |> Enum.sort_by(& &1.scheduled_date, :desc)
    |> List.first()
  end

  defp count_completed_appointments(child_id) do
    App.Scheduling.list_appointments(child_id: child_id)
    |> Enum.count(&(&1.status == "completed"))
  end

  defp determine_checkup_priority(checkup_info, last_appointment, immunization_coverage) do
    base_priority = case checkup_info.priority do
      "high" -> 5
      "medium" -> 3
      "low" -> 1
    end

    # Increase priority based on various factors
    priority_score = base_priority

    # Add points for overdue checkup
    priority_score = if checkup_info.is_overdue, do: priority_score + 3, else: priority_score

    # Add points for low immunization coverage
    priority_score = if immunization_coverage.coverage_percentage < 80, do: priority_score + 2, else: priority_score

    # Add points if no recent appointments
    priority_score = if last_appointment == nil or
                        Date.diff(Date.utc_today(), last_appointment.scheduled_date) > 180,
                        do: priority_score + 2, else: priority_score

    case priority_score do
      score when score >= 8 -> "critical"
      score when score >= 5 -> "high"
      score when score >= 3 -> "medium"
      _ -> "low"
    end
  end

  defp calculate_age_at_date(birth_date, target_date) do
    years_diff = target_date.year - birth_date.year
    months_diff = target_date.month - birth_date.month

    months_diff = if target_date.day < birth_date.day, do: months_diff - 1, else: months_diff

    max(0, years_diff * 12 + months_diff)
  end

  defp determine_vaccine_priority(vaccine, status, delay_months) do
    case {vaccine.is_mandatory, status, delay_months} do
      {true, "missing", delay} when delay > 6 -> "critical"
      {true, "missing", delay} when delay > 2 -> "high"
      {true, "missed", _} -> "high"
      {false, "missing", delay} when delay > 12 -> "medium"
      {_, "scheduled", _} -> "low"
      {_, "completed", _} -> "none"
      _ -> "medium"
    end
  end

  defp generate_vaccination_recommendations(compliance_report) do
    overdue = Enum.filter(compliance_report, &(&1.is_overdue))
    due_soon = Enum.filter(compliance_report, &(&1.status == "missing" and &1.delay_months <= 2))

    recommendations = []

    recommendations = if length(overdue) > 0 do
      recommendations ++ ["Schedule catch-up vaccinations immediately for #{length(overdue)} overdue vaccines"]
    else
      recommendations
    end

    recommendations = if length(due_soon) > 0 do
      recommendations ++ ["Schedule appointment for #{length(due_soon)} vaccines due soon"]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["Vaccination schedule is up to date - continue with routine checkups"]
    else
      recommendations
    end
  end

  defp get_next_due_vaccines(child, compliance_report) do
    all_vaccines = list_vaccine_schedules()
    current_age = App.Accounts.Child.age_in_months(child)

    # Find next vaccines due in the next 3 months
    upcoming = Enum.filter(all_vaccines, fn vaccine ->
      vaccine.recommended_age_months > current_age and
      vaccine.recommended_age_months <= current_age + 3 and
      not Enum.any?(compliance_report, &(&1.vaccine.vaccine_name == vaccine.vaccine_name))
    end)
               |> Enum.sort_by(& &1.recommended_age_months)
               |> Enum.take(3)

    Enum.map(upcoming, fn vaccine ->
      due_date = calculate_target_date(child.date_of_birth, vaccine.recommended_age_months)

      %{
        vaccine: vaccine,
        due_date: due_date,
        months_until: vaccine.recommended_age_months - current_age,
        age_at_vaccination: format_age_at_vaccination(vaccine.recommended_age_months)
      }
    end)
  end

  defp can_combine_with_other_vaccines?(vaccine) do
    # Most vaccines can be given simultaneously, but some have restrictions
    case vaccine.vaccine_name do
      "BCG" -> false  # Usually given alone
      "YF" -> false   # Yellow fever often given separately
      _ -> true
    end
  end

  defp get_vaccine_instructions(vaccine) do
    case vaccine.vaccine_name do
      "BCG" -> "Give in left arm, observe for 15 minutes"
      "OPV" <> _ -> "Oral vaccine, no feeding 1 hour before/after"
      "Rotavirus" <> _ -> "Oral vaccine, complete series before 8 months"
      _ -> "Standard intramuscular injection"
    end
  end

  defp get_earliest_due_date(schedule) do
    schedule
    |> Enum.filter(&(&1.urgency in ["overdue", "due_now", "due_soon"]))
    |> Enum.map(& &1.due_date)
    |> Enum.min(Date, fn -> Date.add(Date.utc_today(), 30) end)
  end

  defp plan_catch_up_visits(overdue_vaccines, child) do
    # Group vaccines that can be given together
    # Most vaccines can be given simultaneously, but some require spacing

    grouped_vaccines = overdue_vaccines
                       |> Enum.group_by(fn vaccine_info ->
      # Group by urgency and spacing requirements
      case vaccine_info.vaccine.vaccine_name do
        "BCG" -> :separate_visit  # BCG usually given alone
        "YF" -> :separate_visit   # Yellow fever often separate
        _ -> :standard_visit
      end
    end)

    visits = []

    # Plan separate visits for special vaccines
    separate_vaccines = Map.get(grouped_vaccines, :separate_visit, [])
    visits = visits ++ Enum.map(separate_vaccines, fn vaccine_info ->
      %{
        visit_number: length(visits) + 1,
        recommended_date: Date.add(Date.utc_today(), length(visits) * 14), # 2 weeks apart
        vaccines: [vaccine_info],
        visit_type: "catch_up_individual",
        notes: "Special vaccine requiring separate visit"
      }
    end)

    # Plan combined visit for standard vaccines (max 4-5 per visit)
    standard_vaccines = Map.get(grouped_vaccines, :standard_visit, [])
    standard_visits = Enum.chunk_every(standard_vaccines, 4) # Max 4 vaccines per visit

    visits = visits ++ Enum.with_index(standard_visits, fn vaccine_group, index ->
      %{
        visit_number: length(visits) + index + 1,
        recommended_date: Date.add(Date.utc_today(), (length(visits) + index) * 14),
        vaccines: vaccine_group,
        visit_type: "catch_up_combined",
        notes: "Multiple catch-up vaccines - monitor for reactions"
      }
    end)

    visits
  end

  defp estimate_catch_up_completion(catch_up_visits) do
    if length(catch_up_visits) > 0 do
      last_visit = List.last(catch_up_visits)
      Date.add(last_visit.recommended_date, 14) # 2 weeks after last visit
    else
      Date.utc_today()
    end
  end

  defp get_catch_up_safety_notes(overdue_vaccines) do
    notes = ["Monitor child for 15 minutes after each vaccination"]

    # Add specific notes based on vaccines
    if Enum.any?(overdue_vaccines, &(String.contains?(&1.vaccine.vaccine_name, "DTP"))) do
      notes = notes ++ ["DTP vaccines may cause fever - paracetamol may be needed"]
    end

    if Enum.any?(overdue_vaccines, &(&1.vaccine.vaccine_name == "BCG")) do
      notes = notes ++ ["BCG may cause local reaction - this is normal"]
    end

    if length(overdue_vaccines) > 3 do
      notes = notes ++ ["Multiple vaccines - consider spacing visits to reduce reactions"]
    end

    notes
  end

  defp format_age_at_vaccination(months) do
    cond do
      months == 0 -> "At birth"
      months < 12 -> "#{months} month#{if months == 1, do: "", else: "s"}"
      months == 12 -> "1 year"
      months < 24 -> "#{months} months"
      true -> "#{Float.round(months / 12, 1)} years"
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
end
