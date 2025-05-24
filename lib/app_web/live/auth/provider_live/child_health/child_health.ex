defmodule AppWeb.ProviderLive.ChildHealth do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.HealthRecords
  alias App.HealthRecords.Growth
  alias App.HealthRecords.Immunization

  @impl true
  def mount(%{"id" => child_id}, session, socket) do
    user = get_user_from_session(session)

    # Ensure the user is a provider
    if Accounts.is_provider?(user) do
      provider = App.Scheduling.get_provider_by_user_id(user.id)
      child = Accounts.get_child!(child_id)

      # Get parent information
      parent = Accounts.get_user!(child.user_id)

      # Fetch health records
      growth_records = HealthRecords.list_growth_records(child_id)
      immunization_records = HealthRecords.list_immunization_records(child_id)

      # Calculate age and percentiles
      age_years = App.Accounts.Child.age(child)
      percentiles = HealthRecords.calculate_growth_percentiles(child_id)

      # Get immunization coverage
      coverage = HealthRecords.calculate_immunization_coverage(child_id)

      # Create changeset for new growth record
      growth_changeset =
        HealthRecords.change_growth_record(%Growth{
          child_id: child_id,
          measurement_date: Date.utc_today()
        })

      # Create changeset for new immunization record
      immunization_changeset =
        HealthRecords.change_immunization_record(%Immunization{
          child_id: child_id,
          status: "scheduled",
          due_date: Date.utc_today()
        })

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:child, child)
        |> assign(:parent, parent)
        |> assign(:page_title, "Health Records: #{child.name}")
        |> assign(:active_tab, "growth")
        |> assign(:growth_records, growth_records)
        |> assign(:immunization_records, immunization_records)
        |> assign(:percentiles, percentiles)
        |> assign(:coverage, coverage)
        |> assign(:age_years, age_years)
        |> assign(:growth_form, to_form(growth_changeset))
        |> assign(:immunization_form, to_form(immunization_changeset))
        |> assign(:vaccine_schedules, HealthRecords.list_vaccine_schedules())
        |> assign(:show_growth_form, false)
        |> assign(:show_immunization_form, false)
        |> assign(:show_sidebar, false)

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
  def handle_event("show_growth_form", _, socket) do
    {:noreply, assign(socket, :show_growth_form, true)}
  end

  @impl true
  def handle_event("hide_growth_form", _, socket) do
    {:noreply, assign(socket, :show_growth_form, false)}
  end

  @impl true
  def handle_event("save_growth", %{"growth" => growth_params}, socket) do
    child_id = socket.assigns.child.id
    growth_params = Map.put(growth_params, "child_id", child_id)

    case HealthRecords.create_growth_record(growth_params) do
      {:ok, _growth} ->
        # Refresh growth records and percentiles
        growth_records = HealthRecords.list_growth_records(child_id)
        percentiles = HealthRecords.calculate_growth_percentiles(child_id)

        # Create new changeset for the form
        growth_changeset =
          HealthRecords.change_growth_record(%Growth{
            child_id: child_id,
            measurement_date: Date.utc_today()
          })

        {:noreply,
          socket
          |> put_flash(:info, "Growth record created successfully.")
          |> assign(:growth_records, growth_records)
          |> assign(:percentiles, percentiles)
          |> assign(:growth_form, to_form(growth_changeset))
          |> assign(:show_growth_form, false)}

      {:error, changeset} ->
        {:noreply, assign(socket, :growth_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("show_immunization_form", _, socket) do
    {:noreply, assign(socket, :show_immunization_form, true)}
  end

  @impl true
  def handle_event("hide_immunization_form", _, socket) do
    {:noreply, assign(socket, :show_immunization_form, false)}
  end

  @impl true
  def handle_event("save_immunization", %{"immunization" => immunization_params}, socket) do
    child_id = socket.assigns.child.id
    immunization_params = Map.put(immunization_params, "child_id", child_id)

    case HealthRecords.create_immunization_record(immunization_params) do
      {:ok, _immunization} ->
        # Refresh immunization records and coverage
        immunization_records = HealthRecords.list_immunization_records(child_id)
        coverage = HealthRecords.calculate_immunization_coverage(child_id)

        # Create new changeset for the form
        immunization_changeset =
          HealthRecords.change_immunization_record(%Immunization{
            child_id: child_id,
            status: "scheduled",
            due_date: Date.utc_today()
          })

        {:noreply,
          socket
          |> put_flash(:info, "Immunization record created successfully.")
          |> assign(:immunization_records, immunization_records)
          |> assign(:coverage, coverage)
          |> assign(:immunization_form, to_form(immunization_changeset))
          |> assign(:show_immunization_form, false)}

      {:error, changeset} ->
        {:noreply, assign(socket, :immunization_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("update_immunization_status", %{"id" => id, "status" => status}, socket) do
    immunization = HealthRecords.get_immunization_record!(id)
    child_id = socket.assigns.child.id

    attrs = %{
      "status" => status,
      "administered_date" => if(status == "administered", do: Date.utc_today(), else: nil),
      "administered_by" =>
        if(status == "administered", do: socket.assigns.provider.name, else: nil)
    }

    case HealthRecords.update_immunization_record(immunization, attrs) do
      {:ok, _updated} ->
        # Refresh immunization records and coverage
        immunization_records = HealthRecords.list_immunization_records(child_id)
        coverage = HealthRecords.calculate_immunization_coverage(child_id)

        {:noreply,
          socket
          |> put_flash(:info, "Immunization status updated successfully.")
          |> assign(:immunization_records, immunization_records)
          |> assign(:coverage, coverage)}

      {:error, _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Failed to update immunization status.")}
    end
  end

  @impl true
  def handle_event("generate_immunization_schedule", _, socket) do
    child_id = socket.assigns.child.id

    # Generate the schedule
    HealthRecords.generate_immunization_schedule(child_id)

    # Refresh immunization records and coverage
    immunization_records = HealthRecords.list_immunization_records(child_id)
    coverage = HealthRecords.calculate_immunization_coverage(child_id)

    {:noreply,
      socket
      |> put_flash(:info, "Immunization schedule generated successfully.")
      |> assign(:immunization_records, immunization_records)
      |> assign(:coverage, coverage)}
  end

  @impl true
  def handle_event("delete_growth_record", %{"id" => id}, socket) do
    growth_record = HealthRecords.get_growth_record!(id)
    child_id = socket.assigns.child.id

    case HealthRecords.delete_growth_record(growth_record) do
      {:ok, _} ->
        # Refresh growth records and percentiles
        growth_records = HealthRecords.list_growth_records(child_id)
        percentiles = HealthRecords.calculate_growth_percentiles(child_id)

        {:noreply,
          socket
          |> put_flash(:info, "Growth record deleted successfully.")
          |> assign(:growth_records, growth_records)
          |> assign(:percentiles, percentiles)}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Failed to delete growth record.")}
    end
  end

  @impl true
  def handle_event("delete_immunization_record", %{"id" => id}, socket) do
    immunization_record = HealthRecords.get_immunization_record!(id)
    child_id = socket.assigns.child.id

    case HealthRecords.delete_immunization_record(immunization_record) do
      {:ok, _} ->
        # Refresh immunization records and coverage
        immunization_records = HealthRecords.list_immunization_records(child_id)
        coverage = HealthRecords.calculate_immunization_coverage(child_id)

        {:noreply,
          socket
          |> put_flash(:info, "Immunization record deleted successfully.")
          |> assign(:immunization_records, immunization_records)
          |> assign(:coverage, coverage)}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Failed to delete immunization record.")}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_status_class(status) do
    case status do
      "administered" -> "bg-green-100 text-green-800"
      "scheduled" -> "bg-blue-100 text-blue-800"
      "missed" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
