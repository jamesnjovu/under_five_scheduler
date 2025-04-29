defmodule AppWeb.AdminLive.Providers do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.Scheduling.Provider

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "providers:update")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:providers, list_providers_with_details())
        |> assign(:page_title, "Provider Management")
        |> assign(:filter, "all")
        |> assign(:search, "")
        |> assign(:show_form, false)
        |> assign(:provider_changeset, new_provider_changeset())
        # For responsive sidebar toggle
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
  def handle_event("toggle-form", _, socket) do
    {:noreply, assign(socket, :show_form, !socket.assigns.show_form)}
  end

  @impl true
  def handle_event("save", %{"provider" => provider_params}, socket) do
    # Create a provider and a user in a single transaction
    case create_provider_with_user(provider_params) do
      {:ok, provider} ->
        socket =
          socket
          |> put_flash(:info, "Provider created successfully.")
          |> assign(:providers, list_providers_with_details())
          |> assign(:show_form, false)
          |> assign(:provider_changeset, new_provider_changeset())

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, provider_changeset: changeset)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    provider = Scheduling.get_provider!(id)
    user = Accounts.get_user!(provider.user_id)

    # In a real app, consider soft-deletion or checking for dependencies
    with {:ok, _} <- Scheduling.delete_provider(provider),
         {:ok, _} <- Accounts.delete_user(user) do
      App.Administration.Auditing.log_action(%{
        action: "delete",
        entity_type: "provider",
        entity_id: id,
        user_id: user.id,
        ip_address: socket.assigns.client_ip,
        details: %{
          provider_name: provider.name,
          specialization: provider.specialization
        }
      })

      {:noreply,
       socket
       |> put_flash(:info, "Provider deleted successfully.")
       |> assign(:providers, list_providers_with_details())}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not delete provider.")
         |> assign(:providers, list_providers_with_details())}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp list_providers_with_details do
    providers = Scheduling.list_providers()

    Enum.map(providers, fn provider ->
      # Get counts of appointments
      appointments = Scheduling.list_appointments(provider_id: provider.id)
      total_appointments = length(appointments)

      upcoming_appointments =
        appointments
        |> Enum.filter(fn a ->
          Date.compare(a.scheduled_date, Date.utc_today()) in [:eq, :gt] &&
            a.status in ["scheduled", "confirmed"]
        end)
        |> length()

      # Get user details
      user = Accounts.get_user!(provider.user_id)

      # Return map with all details
      %{
        id: provider.id,
        name: provider.name,
        specialization: provider.specialization,
        user: user,
        total_appointments: total_appointments,
        upcoming_appointments: upcoming_appointments
      }
    end)
  end

  defp new_provider_changeset do
    # Create changesets for both provider and associated user
    provider_changeset = Scheduling.change_provider(%Provider{})

    # Return a map with both changesets
    %{
      provider: provider_changeset,
      user: Accounts.change_user_registration(%App.Accounts.User{})
    }
  end

  defp create_provider_with_user(params) do
    # In a real app, this would be a transaction to ensure both are created or neither
    # This is simplified for the example
    with {:ok, user} <-
           Accounts.register_user(Map.put(params["user"] || %{}, "role", "provider")),
         {:ok, provider} <-
           Scheduling.create_provider(Map.put(params["provider"] || %{}, "user_id", user.id)) do
      {:ok, provider}
    else
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp filtered_providers(providers, filter, search) do
    providers
    |> filter_by_criteria(filter)
    |> search_providers(search)
  end

  defp filter_by_criteria(providers, "all"), do: providers

  defp filter_by_criteria(providers, "pediatrician") do
    Enum.filter(providers, fn p -> p.specialization == "pediatrician" end)
  end

  defp filter_by_criteria(providers, "nurse") do
    Enum.filter(providers, fn p -> p.specialization == "nurse" end)
  end

  defp filter_by_criteria(providers, "general_practitioner") do
    Enum.filter(providers, fn p -> p.specialization == "general_practitioner" end)
  end

  defp search_providers(providers, ""), do: providers

  defp search_providers(providers, search) do
    search = String.downcase(search)

    Enum.filter(providers, fn p ->
      String.contains?(String.downcase(p.name), search) ||
        String.contains?(String.downcase(p.user.email), search)
    end)
  end
end
