defmodule AppWeb.AdminLive.VaccineSchedules do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.HealthRecords
  alias App.HealthRecords.VaccineSchedule

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "vaccine_schedules:update")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:vaccine_schedules, list_vaccine_schedules())
        |> assign(:page_title, "Vaccine Schedule Management")
        |> assign(:filter, "all")
        |> assign(:search, "")
        |> assign(:show_form, false)
        |> assign(:editing_schedule, nil)
        |> assign(:changeset, HealthRecords.change_vaccine_schedule(%VaccineSchedule{}))
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
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("new_schedule", _, socket) do
    changeset = HealthRecords.change_vaccine_schedule(%VaccineSchedule{})

    {:noreply,
      socket
      |> assign(:show_form, true)
      |> assign(:editing_schedule, nil)
      |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("edit_schedule", %{"id" => id}, socket) do
    schedule = HealthRecords.get_vaccine_schedule!(id)
    changeset = HealthRecords.change_vaccine_schedule(schedule)

    {:noreply,
      socket
      |> assign(:show_form, true)
      |> assign(:editing_schedule, schedule)
      |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("cancel_form", _, socket) do
    {:noreply,
      socket
      |> assign(:show_form, false)
      |> assign(:editing_schedule, nil)
      |> assign(:changeset, HealthRecords.change_vaccine_schedule(%VaccineSchedule{}))}
  end

  @impl true
  def handle_event("save", %{"vaccine_schedule" => vaccine_params}, socket) do
    case socket.assigns.editing_schedule do
      nil ->
        case HealthRecords.create_vaccine_schedule(vaccine_params) do
          {:ok, _schedule} ->
            {:noreply,
              socket
              |> put_flash(:info, "Vaccine schedule created successfully.")
              |> assign(:vaccine_schedules, list_vaccine_schedules())
              |> assign(:show_form, false)
              |> assign(:changeset, HealthRecords.change_vaccine_schedule(%VaccineSchedule{}))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end

      schedule ->
        case HealthRecords.update_vaccine_schedule(schedule, vaccine_params) do
          {:ok, _schedule} ->
            {:noreply,
              socket
              |> put_flash(:info, "Vaccine schedule updated successfully.")
              |> assign(:vaccine_schedules, list_vaccine_schedules())
              |> assign(:show_form, false)
              |> assign(:editing_schedule, nil)
              |> assign(:changeset, HealthRecords.change_vaccine_schedule(%VaccineSchedule{}))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    schedule = HealthRecords.get_vaccine_schedule!(id)

    case HealthRecords.delete_vaccine_schedule(schedule) do
      {:ok, _} ->
        {:noreply,
          socket
          |> put_flash(:info, "Vaccine schedule deleted successfully.")
          |> assign(:vaccine_schedules, list_vaccine_schedules())}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not delete vaccine schedule. It may be referenced by existing immunization records.")
          |> assign(:vaccine_schedules, list_vaccine_schedules())}
    end
  end

  @impl true
  def handle_event("initialize_standard", _, socket) do
    HealthRecords.initialize_standard_vaccine_schedules()

    {:noreply,
      socket
      |> put_flash(:info, "Standard vaccine schedules initialized successfully.")
      |> assign(:vaccine_schedules, list_vaccine_schedules())}
  end

  @impl true
  def handle_event("validate", %{"vaccine_schedule" => vaccine_params}, socket) do
    schedule = socket.assigns.editing_schedule || %VaccineSchedule{}
    changeset =
      schedule
      |> HealthRecords.change_vaccine_schedule(vaccine_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp list_vaccine_schedules do
    HealthRecords.list_vaccine_schedules()
  end

  defp filtered_schedules(schedules, filter, search) do
    schedules
    |> filter_by_criteria(filter)
    |> search_schedules(search)
  end

  defp filter_by_criteria(schedules, "all"), do: schedules

  defp filter_by_criteria(schedules, "mandatory") do
    Enum.filter(schedules, fn s -> s.is_mandatory end)
  end

  defp filter_by_criteria(schedules, "optional") do
    Enum.filter(schedules, fn s -> not s.is_mandatory end)
  end

  defp filter_by_criteria(schedules, "birth") do
    Enum.filter(schedules, fn s -> s.recommended_age_months == 0 end)
  end

  defp filter_by_criteria(schedules, "infant") do
    Enum.filter(schedules, fn s -> s.recommended_age_months > 0 and s.recommended_age_months <= 12 end)
  end

  defp filter_by_criteria(schedules, "toddler") do
    Enum.filter(schedules, fn s -> s.recommended_age_months > 12 and s.recommended_age_months <= 36 end)
  end

  defp filter_by_criteria(schedules, "preschool") do
    Enum.filter(schedules, fn s -> s.recommended_age_months > 36 end)
  end

  defp search_schedules(schedules, ""), do: schedules

  defp search_schedules(schedules, search) do
    search = String.downcase(search)

    Enum.filter(schedules, fn s ->
      String.contains?(String.downcase(s.vaccine_name), search) ||
        String.contains?(String.downcase(s.description || ""), search)
    end)
  end

  defp format_age_description(months) do
    cond do
      months == 0 -> "At birth"
      months < 12 -> "#{months} month#{if months == 1, do: "", else: "s"}"
      months == 12 -> "1 year"
      months < 24 -> "#{months} months (#{Float.round(months / 12, 1)} years)"
      months == 24 -> "2 years"
      months < 60 -> "#{months} months (#{Float.round(months / 12, 1)} years)"
      true -> "#{Float.round(months / 12, 1)} years"
    end
  end

  defp format_age_description(months) do
    cond do
      months == 0 -> "At birth"
      months < 12 -> "#{months} month#{if months == 1, do: "", else: "s"}"
      months == 12 -> "1 year"
      months < 24 -> "#{months} months (#{Float.round(months / 12, 1)} years)"
      months == 24 -> "2 years"
      months < 60 -> "#{months} months (#{Float.round(months / 12, 1)} years)"
      true -> "#{Float.round(months / 12, 1)} years"
    end
  end

  defp get_age_category(months) do
    cond do
      months == 0 -> "Birth"
      months <= 12 -> "Infant"
      months <= 36 -> "Toddler"
      true -> "Preschool"
    end
  end

  # Helper function to safely get input values from changeset
  defp input_value(changeset, field) do
    case changeset do
      %Ecto.Changeset{} ->
        case Ecto.Changeset.fetch_change(changeset, field) do
          {:ok, value} -> value
          :error ->
            case Ecto.Changeset.fetch_field(changeset, field) do
              {:ok, value} -> value
              {:data, value} -> value || get_default_value(field)
              :error -> get_default_value(field)
            end
        end
      _ -> get_default_value(field)
    end
  end

  # Helper function to provide default values for form fields
  defp get_default_value(field) do
    case field do
      :is_mandatory -> true
      :recommended_age_months -> nil
      _ -> ""
    end
  end
end