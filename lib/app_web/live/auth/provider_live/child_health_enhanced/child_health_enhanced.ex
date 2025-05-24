defmodule AppWeb.ProviderLive.ChildHealthEnhanced do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.HealthRecords
  alias App.Scheduling
  alias App.HealthRecords.{Growth, Immunization}

  @impl true
  def mount(%{"appointment_id" => appointment_id}, session, socket) do
    user = get_user_from_session(session)

    # Ensure the user is a provider
    if Accounts.is_provider?(user) do
      provider = Scheduling.get_provider_by_user_id(user.id)
      appointment = Scheduling.get_appointment!(appointment_id)

      # Verify this appointment belongs to this provider
      if appointment.provider_id != provider.id do
        {
          :ok,
          socket
          |> put_flash(:error, "You don't have access to this appointment.")
          |> redirect(to: ~p"/provider/appointments")
        }
      else
        child = Accounts.get_child!(appointment.child_id)
        parent = Accounts.get_user!(child.user_id)

        # Check if appointment is active (scheduled, confirmed, or in progress)
        appointment_active = appointment.status in ["scheduled", "confirmed", "in_progress"]

        # Check if appointment is today
        appointment_today = appointment.scheduled_date == Date.utc_today()

        # Fetch comprehensive health records
        growth_records = HealthRecords.list_growth_records(child.id)
        immunization_records = HealthRecords.list_immunization_records(child.id)
        vaccine_schedules = HealthRecords.list_vaccine_schedules()

        # Get upcoming and missed immunizations
        upcoming_immunizations = HealthRecords.get_upcoming_immunizations(child.id)
        missed_immunizations = HealthRecords.get_missed_immunizations(child.id)

        # Calculate age and percentiles
        age_years = App.Accounts.Child.age(child)
        age_months = App.Accounts.Child.age_in_months(child)
        percentiles = HealthRecords.calculate_growth_percentiles(child.id)
        coverage = HealthRecords.calculate_immunization_coverage(child.id)

        # Create changesets for new records
        growth_changeset = HealthRecords.change_growth_record(
          %Growth{
            child_id: child.id,
            measurement_date: Date.utc_today()
          }
        )

        immunization_changeset = HealthRecords.change_immunization_record(
          %Immunization{
            child_id: child.id,
            status: "administered",
            administered_date: Date.utc_today(),
            administered_by: provider.name
          }
        )

        socket =
          socket
          |> assign(:user, user)
          |> assign(:provider, provider)
          |> assign(:appointment, appointment)
          |> assign(:child, child)
          |> assign(:parent, parent)
          |> assign(:page_title, "Health Check-up: #{child.name}")
          |> assign(:active_tab, "overview")
          |> assign(:appointment_active, appointment_active)
          |> assign(:appointment_today, appointment_today)
          |> assign(:can_edit, appointment_active && appointment_today)
          |> assign(:growth_records, growth_records)
          |> assign(:immunization_records, immunization_records)
          |> assign(:vaccine_schedules, vaccine_schedules)
          |> assign(:upcoming_immunizations, upcoming_immunizations)
          |> assign(:missed_immunizations, missed_immunizations)
          |> assign(:percentiles, percentiles)
          |> assign(:coverage, coverage)
          |> assign(:age_years, age_years)
          |> assign(:age_months, age_months)
          |> assign(:growth_form, to_form(growth_changeset))
          |> assign(:immunization_form, to_form(immunization_changeset))
          |> assign(:show_growth_form, false)
          |> assign(:show_immunization_form, false)
          |> assign(:show_appointment_notes, false)
          |> assign(:appointment_notes, appointment.notes || "")
          |> assign(:show_sidebar, false)

        {:ok, socket}
      end
    else
      {
        :ok,
        socket
        |> put_flash(:error, "You don't have access to this page.")
        |> redirect(to: ~p"/dashboard")
      }
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
  def handle_event("start_appointment", _, socket) do
    appointment = socket.assigns.appointment

    case Scheduling.update_appointment(appointment, %{status: "in_progress"}) |> IO.inspect do
      {:ok, updated_appointment} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Appointment started. You can now update health records.")
          |> assign(:appointment, updated_appointment)
          |> assign(:can_edit, true)
        }

      {:error, _} ->
        {
          :noreply,
          socket
          |> put_flash(:error, "Could not start appointment.")
        }
    end
  end

  @impl true
  def handle_event("complete_appointment", _, socket) do
    appointment = socket.assigns.appointment
    notes = socket.assigns.appointment_notes

    case Scheduling.update_appointment(appointment, %{status: "completed", notes: notes}) do
      {:ok, updated_appointment} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Appointment completed successfully.")
          |> assign(:appointment, updated_appointment)
          |> assign(:can_edit, false)
          |> redirect(to: ~p"/provider/appointments")
        }

      {:error, _} ->
        {
          :noreply,
          socket
          |> put_flash(:error, "Could not complete appointment.")
        }
    end
  end

  @impl true
  def handle_event("show_growth_form", _, socket) do
    {:noreply, assign(socket, :show_growth_form, true)}
  end

  @impl true
  def handle_event("hide_growth_form", _, socket) do
    growth_changeset = HealthRecords.change_growth_record(
      %Growth{
        child_id: socket.assigns.child.id,
        measurement_date: Date.utc_today()
      }
    )

    {
      :noreply,
      socket
      |> assign(:show_growth_form, false)
      |> assign(:growth_form, to_form(growth_changeset))
    }
  end

  @impl true
  def handle_event("save_growth", %{"growth" => growth_params}, socket) do
    if socket.assigns.can_edit do
      child_id = socket.assigns.child.id
      growth_params = Map.put(growth_params, "child_id", child_id)

      case HealthRecords.create_growth_record(growth_params) do
        {:ok, _growth} ->
          # Refresh data
          growth_records = HealthRecords.list_growth_records(child_id)
          percentiles = HealthRecords.calculate_growth_percentiles(child_id)

          growth_changeset = HealthRecords.change_growth_record(
            %Growth{
              child_id: child_id,
              measurement_date: Date.utc_today()
            }
          )

          {
            :noreply,
            socket
            |> put_flash(:info, "Growth record added successfully.")
            |> assign(:growth_records, growth_records)
            |> assign(:percentiles, percentiles)
            |> assign(:growth_form, to_form(growth_changeset))
            |> assign(:show_growth_form, false)
          }

        {:error, changeset} ->
          {:noreply, assign(socket, :growth_form, to_form(changeset))}
      end
    else
      {
        :noreply,
        socket
        |> put_flash(:error, "You can only add records during an active appointment.")
      }
    end
  end

  @impl true
  def handle_event("show_immunization_form", _, socket) do
    {:noreply, assign(socket, :show_immunization_form, true)}
  end

  @impl true
  def handle_event("hide_immunization_form", _, socket) do
    immunization_changeset = HealthRecords.change_immunization_record(
      %Immunization{
        child_id: socket.assigns.child.id,
        status: "administered",
        administered_date: Date.utc_today(),
        administered_by: socket.assigns.provider.name
      }
    )

    {
      :noreply,
      socket
      |> assign(:show_immunization_form, false)
      |> assign(:immunization_form, to_form(immunization_changeset))
    }
  end

  @impl true
  def handle_event("save_immunization", %{"immunization" => immunization_params}, socket) do
    if socket.assigns.can_edit do
      child_id = socket.assigns.child.id
      immunization_params =
        immunization_params
        |> Map.put("child_id", child_id)
        |> Map.put("administered_by", socket.assigns.provider.name)

      case HealthRecords.create_immunization_record(immunization_params) do
        {:ok, _immunization} ->
          # Refresh data
          immunization_records = HealthRecords.list_immunization_records(child_id)
          upcoming_immunizations = HealthRecords.get_upcoming_immunizations(child_id)
          missed_immunizations = HealthRecords.get_missed_immunizations(child_id)
          coverage = HealthRecords.calculate_immunization_coverage(child_id)

          immunization_changeset = HealthRecords.change_immunization_record(
            %Immunization{
              child_id: child_id,
              status: "administered",
              administered_date: Date.utc_today(),
              administered_by: socket.assigns.provider.name
            }
          )

          {
            :noreply,
            socket
            |> put_flash(:info, "Immunization record added successfully.")
            |> assign(:immunization_records, immunization_records)
            |> assign(:upcoming_immunizations, upcoming_immunizations)
            |> assign(:missed_immunizations, missed_immunizations)
            |> assign(:coverage, coverage)
            |> assign(:immunization_form, to_form(immunization_changeset))
            |> assign(:show_immunization_form, false)
          }

        {:error, changeset} ->
          {:noreply, assign(socket, :immunization_form, to_form(changeset))}
      end
    else
      {
        :noreply,
        socket
        |> put_flash(:error, "You can only add records during an active appointment.")
      }
    end
  end

  @impl true
  def handle_event("administer_vaccine", %{"id" => id}, socket) do
    if socket.assigns.can_edit do
      immunization = HealthRecords.get_immunization_record!(id)
      child_id = socket.assigns.child.id

      attrs = %{
        "status" => "administered",
        "administered_date" => Date.utc_today(),
        "administered_by" => socket.assigns.provider.name
      }

      case HealthRecords.update_immunization_record(immunization, attrs) do
        {:ok, _updated} ->
          # Refresh data
          immunization_records = HealthRecords.list_immunization_records(child_id)
          upcoming_immunizations = HealthRecords.get_upcoming_immunizations(child_id)
          missed_immunizations = HealthRecords.get_missed_immunizations(child_id)
          coverage = HealthRecords.calculate_immunization_coverage(child_id)

          {
            :noreply,
            socket
            |> put_flash(:info, "Vaccine administered successfully.")
            |> assign(:immunization_records, immunization_records)
            |> assign(:upcoming_immunizations, upcoming_immunizations)
            |> assign(:missed_immunizations, missed_immunizations)
            |> assign(:coverage, coverage)
          }

        {:error, _changeset} ->
          {
            :noreply,
            socket
            |> put_flash(:error, "Failed to update immunization record.")
          }
      end
    else
      {
        :noreply,
        socket
        |> put_flash(:error, "You can only administer vaccines during an active appointment.")
      }
    end
  end

  @impl true
  def handle_event("mark_vaccine_missed", %{"id" => id}, socket) do
    if socket.assigns.can_edit do
      immunization = HealthRecords.get_immunization_record!(id)
      child_id = socket.assigns.child.id

      attrs = %{
        "status" => "missed"
      }

      case HealthRecords.update_immunization_record(immunization, attrs) do
        {:ok, _updated} ->
          # Refresh data
          immunization_records = HealthRecords.list_immunization_records(child_id)
          upcoming_immunizations = HealthRecords.get_upcoming_immunizations(child_id)
          missed_immunizations = HealthRecords.get_missed_immunizations(child_id)
          coverage = HealthRecords.calculate_immunization_coverage(child_id)

          {
            :noreply,
            socket
            |> put_flash(:info, "Vaccine marked as missed.")
            |> assign(:immunization_records, immunization_records)
            |> assign(:upcoming_immunizations, upcoming_immunizations)
            |> assign(:missed_immunizations, missed_immunizations)
            |> assign(:coverage, coverage)
          }

        {:error, _changeset} ->
          {
            :noreply,
            socket
            |> put_flash(:error, "Failed to update immunization record.")
          }
      end
    else
      {
        :noreply,
        socket
        |> put_flash(:error, "You can only update records during an active appointment.")
      }
    end
  end

  @impl true
  def handle_event("generate_immunization_schedule", _, socket) do
    if socket.assigns.can_edit do
      child_id = socket.assigns.child.id

      # Generate the schedule
      HealthRecords.generate_immunization_schedule(child_id)

      # Refresh data
      immunization_records = HealthRecords.list_immunization_records(child_id)
      upcoming_immunizations = HealthRecords.get_upcoming_immunizations(child_id)
      missed_immunizations = HealthRecords.get_missed_immunizations(child_id)
      coverage = HealthRecords.calculate_immunization_coverage(child_id)

      {
        :noreply,
        socket
        |> put_flash(:info, "Immunization schedule generated successfully.")
        |> assign(:immunization_records, immunization_records)
        |> assign(:upcoming_immunizations, upcoming_immunizations)
        |> assign(:missed_immunizations, missed_immunizations)
        |> assign(:coverage, coverage)
      }
    else
      {
        :noreply,
        socket
        |> put_flash(:error, "You can only generate schedules during an active appointment.")
      }
    end
  end

  @impl true
  def handle_event("show_appointment_notes", _, socket) do
    {:noreply, assign(socket, :show_appointment_notes, true)}
  end

  @impl true
  def handle_event("hide_appointment_notes", _, socket) do
    {:noreply, assign(socket, :show_appointment_notes, false)}
  end

  @impl true
  def handle_event("update_appointment_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :appointment_notes, notes)}
  end

  @impl true
  def handle_event("save_appointment_notes", _, socket) do
    appointment = socket.assigns.appointment
    notes = socket.assigns.appointment_notes

    case Scheduling.update_appointment(appointment, %{notes: notes}) do
      {:ok, updated_appointment} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Appointment notes saved.")
          |> assign(:appointment, updated_appointment)
          |> assign(:show_appointment_notes, false)
        }

      {:error, _} ->
        {
          :noreply,
          socket
          |> put_flash(:error, "Could not save appointment notes.")
        }
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp format_date(nil), do: "Not set"
  defp format_date(date), do: Calendar.strftime(date, "%B %d, %Y")

  defp format_time(time), do: Calendar.strftime(time, "%I:%M %p")

  defp format_status_class(status) do
    case status do
      "administered" -> "bg-green-100 text-green-800"
      "scheduled" -> "bg-blue-100 text-blue-800"
      "missed" -> "bg-red-100 text-red-800"
      "in_progress" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp format_appointment_status_class(status) do
    case status do
      "scheduled" -> "bg-blue-100 text-blue-800"
      "confirmed" -> "bg-green-100 text-green-800"
      "in_progress" -> "bg-yellow-100 text-yellow-800"
      "completed" -> "bg-indigo-100 text-indigo-800"
      "cancelled" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp next_checkup_age(child) do
    App.Accounts.Child.next_checkup_age(child)
  end

  defp safe_percentage(value) when is_number(value) do
    Float.round(value * 1.0, 1)
  end

  defp safe_percentage(_), do: 0.0
end
