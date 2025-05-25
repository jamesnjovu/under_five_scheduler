defmodule AppWeb.AdminLive.Providers do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.Scheduling.Provider
  alias App.Repo

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
        |> assign(:changeset, new_provider_changeset())
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
    {:noreply,
      socket
      |> assign(:show_form, !socket.assigns.show_form)
      |> assign(:changeset, new_provider_changeset())}
  end

  @impl true
  def handle_event("save", %{"provider" => provider_params}, socket) do
    # Generate a random password
    password = generate_random_password()

    # Get specialization_id from the specialization code
    specialization = App.Config.Specializations.get_specialization_by_code(provider_params["specialization"])

    if specialization do
      # Prepare user params with auto-generated password
      user_params = %{
        "name" => provider_params["name"],
        "email" => provider_params["email"],
        "phone" => provider_params["phone"],
        "password" => password,
        "role" => "provider"
      }

      # Add specialization_id to provider params
      provider_params = Map.put(provider_params, "specialization_id", specialization.id)

      # Create provider and user in a transaction
      case create_provider_with_user(provider_params, user_params, password) do
        {:ok, {provider, user}} ->
          socket =
            socket
            |> put_flash(:info, "Provider created successfully. Login credentials have been sent via email and SMS.")
            |> assign(:providers, list_providers_with_details())
            |> assign(:show_form, false)
            |> assign(:changeset, new_provider_changeset())

          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    else
      changeset = new_provider_changeset()
      changeset = %{changeset | errors: [specialization: {"is invalid", []}], valid?: false}
      {:noreply, assign(socket, :changeset, changeset)}
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

  # Private functions

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp list_providers_with_details do
    providers = Scheduling.list_providers()

    Enum.map(providers, fn provider ->
      # Preload specialization_record if it exists
      provider = App.Repo.preload(provider, :specialization_record)

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
        specialization: provider.specialization, # Legacy field
        specialization_record: provider.specialization_record, # New field
        user: user,
        total_appointments: total_appointments,
        upcoming_appointments: upcoming_appointments
      }
    end)
  end

  defp new_provider_changeset do
    # Create a simple changeset structure that the form expects
    %{
      provider: Scheduling.change_provider(%Provider{}),
      user: Accounts.change_user_registration(%App.Accounts.User{})
    }
  end

  defp generate_random_password do
    # Generate a secure random password
    :crypto.strong_rand_bytes(12)
    |> Base.encode64()
    |> String.replace(~r/[^A-Za-z0-9]/, "")
    |> String.slice(0, 12)
  end

  defp create_provider_with_user(provider_params, user_params, password) do
    # Use a database transaction to ensure both are created or neither
    Repo.transaction(fn ->
      with {:ok, user} <- Accounts.register_user(user_params),
           {:ok, provider} <- Scheduling.create_provider(Map.put(provider_params, "user_id", user.id)) do

        # Send credentials via email and SMS
        send_credentials_notification(user, password)

        {provider, user}
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp send_credentials_notification(user, password) do
    # Send email with login credentials
    send_credentials_email(user, password)

    # Send SMS with login credentials
    send_credentials_sms(user, password)
  end

  defp send_credentials_email(user, password) do
    subject = "Your Provider Account - Under Five Health Check-Up"

    email_body = """
    <h2>Welcome to Under Five Health Check-Up</h2>
    <p>Dear #{user.name},</p>

    <p>Your healthcare provider account has been created successfully.</p>

    <h3>Login Credentials:</h3>
    <ul>
      <li><strong>Email:</strong> #{user.email}</li>
      <li><strong>Password:</strong> #{password}</li>
    </ul>

    <p><strong>Important:</strong> Please change your password after your first login for security.</p>

    <p>You can access the provider portal at: [Your Website URL]/users/log_in</p>

    <p>If you have any questions, please contact the administrator.</p>

    <p>Best regards,<br>Under Five Health Check-Up Team</p>
    """

    App.Accounts.UserNotifier.build_email(user.email, subject, email_body)
    |> App.Mailer.deliver()
  end

  defp send_credentials_sms(user, password) do
    message = """
    Welcome to Under Five Health Check-Up!

    Your provider account login:
    Email: #{user.email}
    Password: #{password}

    Please change your password after first login.

    Login at: [Your Website URL]
    """

    # Use your SMS service
    App.Services.ProbaseSMS.send_sms(user.phone, message)
  end

  defp filtered_providers(providers, filter, search) do
    providers
    |> filter_by_criteria(filter)
    |> search_providers(search)
  end

  defp filter_by_criteria(providers, "all"), do: providers

  defp filter_by_criteria(providers, filter) do
    # Handle category-based filtering
    case filter do
      "category:" <> category ->
        category_specializations = App.Config.Specializations.specializations_by_category(category)
                                   |> Enum.map(& &1.code)
        Enum.filter(providers, fn p ->
          # Check both new and legacy specialization fields
          specialization_code = get_provider_specialization_code(p)
          specialization_code in category_specializations
        end)

      # Handle individual specialization filtering
      specialization ->
        if App.Config.Specializations.valid?(specialization) do
          Enum.filter(providers, fn p ->
            get_provider_specialization_code(p) == specialization
          end)
        else
          providers
        end
    end
  end

  # Helper to get specialization code from either new or legacy field
  defp get_provider_specialization_code(provider) do
    cond do
      provider.specialization_record -> provider.specialization_record.code
      provider.specialization -> provider.specialization
      true -> nil
    end
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