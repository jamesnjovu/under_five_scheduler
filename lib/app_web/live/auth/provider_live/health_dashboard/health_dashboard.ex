# lib/app_web/live/auth/provider_live/health_dashboard/health_dashboard.ex

defmodule AppWeb.ProviderLive.HealthDashboard do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.HealthRecords
  alias App.HealthAlerts

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if Accounts.is_provider?(user) do
      provider = Scheduling.get_provider_by_user_id(user.id)

      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "health_alerts:updates")
        Phoenix.PubSub.subscribe(App.PubSub, "appointments:updates")
        Phoenix.PubSub.subscribe(App.PubSub, "health_records:updates")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:page_title, "Health Dashboard")
        |> assign(:active_tab, "overview")
        |> assign(:date_range, get_default_date_range())
        |> assign(:show_sidebar, false)
        |> load_dashboard_data()

      {:ok, socket}
    else
      {:ok,
        socket
        |> put_flash(:error, "You don't have access to this page.")
        |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("change_date_range", %{"range" => range}, socket) do
    date_range = case range do
      "7_days" -> {Date.add(Date.utc_today(), -7), Date.utc_today()}
      "30_days" -> {Date.add(Date.utc_today(), -30), Date.utc_today()}
      "90_days" -> {Date.add(Date.utc_today(), -90), Date.utc_today()}
      "6_months" -> {Date.add(Date.utc_today(), -180), Date.utc_today()}
      _ -> get_default_date_range()
    end

    {:noreply,
      socket
      |> assign(:date_range, date_range)
      |> load_dashboard_data()}
  end

  @impl true
  def handle_event("resolve_alert", %{"alert_id" => alert_id}, socket) do
    case HealthAlerts.resolve_alert(alert_id, socket.assigns.user.id) do
      {:ok, _} ->
        {:noreply,
          socket
          |> put_flash(:info, "Alert resolved successfully.")
          |> load_dashboard_data()}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not resolve alert.")}
    end
  end

  @impl true
  def handle_event("refresh_data", _, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  # Handle real-time updates
  @impl true
  def handle_info({:health_alert_created, _alert}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl true
  def handle_info({:health_alert_resolved, _alert}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl true
  def handle_info({:appointment_completed, appointment}, socket) do
    if appointment.provider_id == socket.assigns.provider.id do
      {:noreply, load_dashboard_data(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:health_record_updated, _record}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  # Private functions

  defp get_user_from_session(session) do
    token = session["user_token"]
    Accounts.get_user_by_session_token(token)
  end

  defp get_default_date_range do
    {Date.add(Date.utc_today(), -30), Date.utc_today()}
  end

  defp load_dashboard_data(socket) do
    provider_id = socket.assigns.provider.id
    {start_date, end_date} = socket.assigns.date_range

    socket
    |> assign(:health_metrics, get_health_metrics(provider_id, start_date, end_date))
    |> assign(:active_alerts, HealthAlerts.get_provider_alerts(provider_id))
    |> assign(:alert_statistics, HealthAlerts.get_alert_statistics(provider_id))
    |> assign(:recent_activities, get_recent_health_activities(provider_id, 10))
    |> assign(:immunization_coverage, get_immunization_coverage_stats(provider_id))
    |> assign(:growth_trends, get_growth_trend_summary(provider_id, start_date, end_date))
    |> assign(:upcoming_checkups, get_upcoming_checkups(provider_id))
  end

  defp get_health_metrics(provider_id, start_date, end_date) do
    # Get all children seen by this provider
    patient_ids = get_provider_patient_ids(provider_id)

    # Health records created in date range
    growth_records_count = count_growth_records_in_range(patient_ids, start_date, end_date)
    immunizations_given = count_immunizations_in_range(patient_ids, start_date, end_date)
    health_visits = count_health_visits_in_range(provider_id, start_date, end_date)

    # Calculate percentages and trends
    previous_period_start = Date.add(start_date, -(Date.diff(end_date, start_date)))

    previous_growth = count_growth_records_in_range(patient_ids, previous_period_start, start_date)
    previous_immunizations = count_immunizations_in_range(patient_ids, previous_period_start, start_date)

    %{
      total_patients: length(patient_ids),
      growth_records: growth_records_count,
      immunizations_administered: immunizations_given,
      health_visits: health_visits,
      growth_trend: calculate_trend_percentage(previous_growth, growth_records_count),
      immunization_trend: calculate_trend_percentage(previous_immunizations, immunizations_given),
      period: {start_date, end_date}
    }
  end

  defp get_recent_health_activities(provider_id, limit) do
    # Get recent health-related activities for this provider
    patient_ids = get_provider_patient_ids(provider_id)

    activities = []

    # Recent growth records - get all for patients, then filter
    recent_growth = patient_ids
                    |> Enum.flat_map(&HealthRecords.list_growth_records/1)
                    |> Enum.sort_by(& &1.inserted_at, :desc)
                    |> Enum.take(limit)
                    |> Enum.map(fn record ->
      child = Accounts.get_child!(record.child_id)
      %{
        type: "growth_recorded",
        message: "Growth recorded for #{child.name}",
        timestamp: record.inserted_at,
        child_name: child.name,
        details: "Weight: #{record.weight}kg, Height: #{record.height}cm"
      }
    end)

    # Recent immunizations - get all for patients, then filter
    recent_immunizations = patient_ids
                           |> Enum.flat_map(&HealthRecords.list_immunization_records/1)
                           |> Enum.filter(&(&1.status == "administered"))
                           |> Enum.sort_by(& &1.inserted_at, :desc)
                           |> Enum.take(limit)
                           |> Enum.map(fn record ->
      child = Accounts.get_child!(record.child_id)
      %{
        type: "immunization_given",
        message: "#{record.vaccine_name} administered to #{child.name}",
        timestamp: record.inserted_at,
        child_name: child.name,
        details: "Administered by #{record.administered_by}"
      }
    end)

    # Combine and sort by timestamp
    (activities ++ recent_growth ++ recent_immunizations)
    |> Enum.sort_by(& &1.timestamp, :desc)
    |> Enum.take(limit)
  end

  defp get_immunization_coverage_stats(provider_id) do
    patient_ids = get_provider_patient_ids(provider_id)

    coverage_data = Enum.map(patient_ids, fn child_id ->
      HealthRecords.calculate_immunization_coverage(child_id)
    end)

    total_patients = length(coverage_data)

    if total_patients > 0 do
      avg_coverage = coverage_data
                     |> Enum.map(& &1.coverage_percentage)
                     |> Enum.sum()
                     |> Kernel./(total_patients)
                     |> Float.round(1)

      fully_covered = Enum.count(coverage_data, &(&1.coverage_percentage >= 100.0))
      needs_attention = Enum.count(coverage_data, &(&1.coverage_percentage < 80.0))

      %{
        average_coverage: avg_coverage,
        fully_covered_patients: fully_covered,
        patients_needing_attention: needs_attention,
        total_patients: total_patients,
        coverage_distribution: calculate_coverage_distribution(coverage_data)
      }
    else
      %{
        average_coverage: 0.0,
        fully_covered_patients: 0,
        patients_needing_attention: 0,
        total_patients: 0,
        coverage_distribution: %{}
      }
    end
  end

  defp get_growth_trend_summary(provider_id, start_date, end_date) do
    patient_ids = get_provider_patient_ids(provider_id)

    # Get children with concerning growth trends
    concerning_trends = Enum.reduce(patient_ids, [], fn child_id, acc ->
      growth_records = HealthRecords.list_growth_records(child_id)

      if length(growth_records) >= 2 do
        trends = HealthRecords.calculate_growth_trends(growth_records)
        child = Accounts.get_child!(child_id)

        case trends.weight.trend_direction do
          :decreasing ->
            acc ++ [%{
              child_name: child.name,
              child_id: child_id,
              concern: "Weight declining",
              trend: trends.weight.rate_per_month
            }]
          _ -> acc
        end
      else
        acc
      end
    end)

    # Count children with no recent growth data
    children_needing_measurement = Enum.count(patient_ids, fn child_id ->
      latest_growth = HealthRecords.get_latest_growth_record(child_id)

      if latest_growth do
        Date.diff(Date.utc_today(), latest_growth.measurement_date) > 180
      else
        true
      end
    end)

    %{
      concerning_trends: concerning_trends,
      children_needing_measurement: children_needing_measurement,
      total_monitored: length(patient_ids)
    }
  end

  defp get_upcoming_checkups(provider_id) do
    # Get children who are due for checkups soon
    patient_ids = get_provider_patient_ids(provider_id)

    Enum.reduce(patient_ids, [], fn child_id, acc ->
      child = Accounts.get_child!(child_id)
      next_checkup = HealthRecords.calculate_next_checkup_date(child)
      days_until = Date.diff(next_checkup, Date.utc_today())

      if days_until <= 30 and days_until >= -7 do  # Due within 30 days or up to 7 days overdue
        status = cond do
          days_until < 0 -> :overdue
          days_until <= 7 -> :due_soon
          true -> :upcoming
        end

        acc ++ [%{
          child_name: child.name,
          child_id: child_id,
          due_date: next_checkup,
          days_until: days_until,
          status: status
        }]
      else
        acc
      end
    end)
    |> Enum.sort_by(& &1.days_until)
  end

  # Helper functions

  defp get_provider_patient_ids(provider_id) do
    Scheduling.list_appointments(provider_id: provider_id)
    |> Enum.map(& &1.child_id)
    |> Enum.uniq()
  end

  defp count_growth_records_in_range(child_ids, start_date, end_date) do
    child_ids
    |> Enum.flat_map(&HealthRecords.list_growth_records/1)
    |> Enum.filter(fn record ->
      Date.compare(record.measurement_date, start_date) != :lt and
      Date.compare(record.measurement_date, end_date) != :gt
    end)
    |> length()
  end

  defp count_immunizations_in_range(child_ids, start_date, end_date) do
    child_ids
    |> Enum.flat_map(&HealthRecords.list_immunization_records/1)
    |> Enum.filter(fn record ->
      record.status == "administered" and
      record.administered_date != nil and
      Date.compare(record.administered_date, start_date) != :lt and
      Date.compare(record.administered_date, end_date) != :gt
    end)
    |> length()
  end

  defp count_health_visits_in_range(provider_id, start_date, end_date) do
    Scheduling.list_appointments(provider_id: provider_id)
    |> Enum.filter(fn appt ->
      appt.status == "completed" and
      Date.compare(appt.scheduled_date, start_date) != :lt and
      Date.compare(appt.scheduled_date, end_date) != :gt
    end)
    |> length()
  end

  defp calculate_trend_percentage(previous, current) do
    cond do
      previous == 0 and current > 0 -> 100.0
      previous == 0 -> 0.0
      true -> Float.round((current - previous) / previous * 100, 1)
    end
  end

  defp calculate_coverage_distribution(coverage_data) do
    coverage_data
    |> Enum.group_by(fn data ->
      cond do
        data.coverage_percentage >= 100 -> "100%"
        data.coverage_percentage >= 80 -> "80-99%"
        data.coverage_percentage >= 60 -> "60-79%"
        data.coverage_percentage >= 40 -> "40-59%"
        true -> "<40%"
      end
    end)
    |> Enum.map(fn {range, data_list} -> {range, length(data_list)} end)
    |> Enum.into(%{})
  end

  defp format_trend(trend) when trend > 0, do: "+#{trend}%"
  defp format_trend(trend) when trend < 0, do: "#{trend}%"
  defp format_trend(_), do: "0%"

  defp trend_color(trend) when trend > 0, do: "text-green-600"
  defp trend_color(trend) when trend < 0, do: "text-red-600"
  defp trend_color(_), do: "text-gray-600"

  defp format_date(date), do: Calendar.strftime(date, "%B %d, %Y")
  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")

  defp alert_severity_color(severity) do
    case severity do
      "critical" -> "bg-red-100 text-red-800 border-red-200"
      "high" -> "bg-orange-100 text-orange-800 border-orange-200"
      "medium" -> "bg-yellow-100 text-yellow-800 border-yellow-200"
      "low" -> "bg-blue-100 text-blue-800 border-blue-200"
      _ -> "bg-gray-100 text-gray-800 border-gray-200"
    end
  end

  defp checkup_status_color(status) do
    case status do
      :overdue -> "bg-red-100 text-red-800"
      :due_soon -> "bg-yellow-100 text-yellow-800"
      :upcoming -> "bg-blue-100 text-blue-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end