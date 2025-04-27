defmodule AppWeb.ProviderLive.Patients do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    # Ensure the user is a provider
    if Accounts.is_provider?(user) do
      provider = Scheduling.get_provider_by_user_id(user.id)

      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "patients:updates")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:page_title, "My Patients")
        |> assign(:patients, get_provider_patients(provider.id))
        |> assign(:search, "")
        |> assign(:selected_patient, nil)
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

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("view_patient", %{"id" => id}, socket) do
    patient = Enum.find(socket.assigns.patients, fn p -> p.id == String.to_integer(id) end)
    {:noreply, assign(socket, :selected_patient, patient)}
  end

  @impl true
  def handle_event("clear_selection", _, socket) do
    {:noreply, assign(socket, :selected_patient, nil)}
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp get_provider_patients(provider_id) do
    # Get all unique patients (children) that have had appointments with this provider
    appointments = Scheduling.list_appointments(provider_id: provider_id)
    child_ids = appointments |> Enum.map(& &1.child_id) |> Enum.uniq()

    # Get each child's details
    children =
      Enum.map(child_ids, fn id ->
        child = Accounts.get_child!(id)
        parent = Accounts.get_user!(child.user_id)

        # Get the child's appointment history with this provider
        child_appointments =
          Enum.filter(appointments, fn appt -> appt.child_id == id end)
          |> Enum.sort_by(fn appt -> {appt.scheduled_date, appt.scheduled_time} end, :desc)

        most_recent_appt = List.first(child_appointments)

        %{
          id: child.id,
          name: child.name,
          age: App.Accounts.Child.age(child),
          medical_record_number: child.medical_record_number,
          date_of_birth: child.date_of_birth,
          parent: parent,
          appointments_count: length(child_appointments),
          most_recent_visit: most_recent_appt && most_recent_appt.scheduled_date,
          appointment_history: child_appointments
        }
      end)

    # Sort by most recent visit
    Enum.sort_by(
      children,
      fn child ->
        case child.most_recent_visit do
          # Put patients with no visits at the end
          nil -> ~D[1900-01-01]
          date -> date
        end
      end,
      :desc
    )
  end

  defp filtered_patients(patients, search) do
    if search == "" do
      patients
    else
      search = String.downcase(search)

      Enum.filter(patients, fn patient ->
        String.contains?(String.downcase(patient.name), search) ||
          String.contains?(String.downcase(patient.medical_record_number), search)
      end)
    end
  end

  defp format_date(nil), do: "Never"
  defp format_date(date), do: Calendar.strftime(date, "%b %d, %Y")
end
