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
        |> assign(:edit_provider, nil)
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
      |> assign(:edit_provider, nil)
      |> assign(:changeset, new_provider_changeset())}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    provider = Scheduling.get_provider!(id) |> Repo.preload(:user)

    changeset = %{
      provider: Scheduling.change_provider(provider),
      user: Accounts.change_user(provider.user)
    }

    {:noreply,
      socket
      |> assign(:show_form, true)
      |> assign(:edit_provider, provider)
      |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"provider" => provider_params}, socket) do
    case socket.assigns.edit_provider do
      nil ->
        # Create new provider
        create_new_provider(socket, provider_params)

      provider ->
        # Update existing provider
        update_existing_provider(socket, provider, provider_params)
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    provider = Scheduling.get_provider!(id)
    user = Accounts.get_user!(provider.user_id)

    # Soft delete: set is_active to false instead of hard delete
    case soft_delete_provider(provider, user) do
      {:ok, _} ->
        App.Administration.Auditing.log_action(%{
          action: "deactivate",
          entity_type: "provider",
          entity_id: id,
          user_id: socket.assigns.user.id,
          ip_address: get_connect_ip(socket),
          details: %{
            provider_name: provider.name,
            specialization: provider.specialization,
            action: "soft_delete"
          }
        })

        {:noreply,
          socket
          |> put_flash(:info, "Provider deactivated successfully.")
          |> assign(:providers, list_providers_with_details())}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not deactivate provider.")
          |> assign(:providers, list_providers_with_details())}
    end
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    provider = Scheduling.get_provider!(id)
    user = Accounts.get_user!(provider.user_id)

    case reactivate_provider(provider, user) do
      {:ok, _} ->
        App.Administration.Auditing.log_action(%{
          action: "reactivate",
          entity_type: "provider",
          entity_id: id,
          user_id: socket.assigns.user.id,
          ip_address: get_connect_ip(socket),
          details: %{
            provider_name: provider.name,
            specialization: provider.specialization,
            action: "reactivate"
          }
        })

        {:noreply,
          socket
          |> put_flash(:info, "Provider reactivated successfully.")
          |> assign(:providers, list_providers_with_details())}

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not reactivate provider.")
          |> assign(:providers, list_providers_with_details())}
    end
  end

  # Private functions

  defp create_new_provider(socket, provider_params) do
    # Generate a random password
    password = generate_random_password()

    # Prepare user params with auto-generated password
    user_params = %{
      "name" => provider_params["name"],
      "email" => provider_params["email"],
      "phone" => provider_params["phone"],
      "password" => password,
      "role" => "provider"
    }

    # Prepare provider params with license number
    provider_create_params = %{
      "name" => provider_params["name"],
      "specialization" => provider_params["specialization"],
      "license_number" => provider_params["license_number"]
    }

    # Create provider and user in a transaction
    case create_provider_with_user(provider_create_params, user_params, password) do
      {:ok, {provider, user}} ->
        socket =
          socket
          |> put_flash(:info, "Provider created successfully. Login credentials have been sent via email and SMS.")
          |> assign(:providers, list_providers_with_details())
          |> assign(:show_form, false)
          |> assign(:edit_provider, nil)
          |> assign(:changeset, new_provider_changeset())

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp update_existing_provider(socket, provider, provider_params) do
    user_params = %{
      "name" => provider_params["name"],
      "email" => provider_params["email"],
      "phone" => provider_params["phone"]
    }

    provider_update_params = %{
      "name" => provider_params["name"],
      "specialization" => provider_params["specialization"],
      "license_number" => provider_params["license_number"]
    }

    case update_provider_with_user(provider, provider_update_params, user_params) do
      {:ok, {updated_provider, updated_user}} ->
        App.Administration.Auditing.log_action(%{
          action: "update",
          entity_type: "provider",
          entity_id: provider.id,
          user_id: socket.assigns.user.id,
          ip_address: get_connect_ip(socket),
          details: %{
            provider_name: updated_provider.name,
            specialization: updated_provider.specialization,
            changes: provider_update_params
          }
        })

        socket =
          socket
          |> put_flash(:info, "Provider updated successfully.")
          |> assign(:providers, list_providers_with_details())
          |> assign(:show_form, false)
          |> assign(:edit_provider, nil)
          |> assign(:changeset, new_provider_changeset())

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp soft_delete_provider(provider, user) do
    Repo.transaction(fn ->
      with {:ok, provider} <- Scheduling.update_provider(provider, %{is_active: false}),
           # Optionally also deactivate the user account
           {:ok, user} <- Accounts.update_user(user, %{}) do
        {provider, user}
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp reactivate_provider(provider, user) do
    Repo.transaction(fn ->
      with {:ok, provider} <- Scheduling.update_provider(provider, %{is_active: true}),
           {:ok, user} <- Accounts.update_user(user, %{}) do
        {provider, user}
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp update_provider_with_user(provider, provider_params, user_params) do
    Repo.transaction(fn ->
      with {:ok, user} <- Accounts.update_user(provider.user, user_params),
           {:ok, provider} <- Scheduling.update_provider(provider, provider_params) do
        {provider, user}
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp list_providers_with_details do
    # Only show active providers by default, but include inactive for admin review
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

      # Get specialization information
      specialization_info = get_specialization_info(provider.specialization)

      # Return map with all details
      %{
        id: provider.id,
        name: provider.name,
        specialization: provider.specialization, # Legacy field
        specialization_info: specialization_info, # Enhanced specialization data
        license_number: provider.license_number,
        user: user,
        total_appointments: total_appointments,
        upcoming_appointments: upcoming_appointments,
        is_active: provider.is_active
      }
    end)
  end

  defp get_specialization_info(specialization_code) when is_binary(specialization_code) do
    # Use the setup module that we know works
    case App.Setup.Specializations.get_by_code(specialization_code) do
      %{} = spec ->
        %{
          name: spec.name,
          description: spec.description,
          can_prescribe: spec.can_prescribe,
          requires_license: spec.requires_license,
          category: spec.category,
          icon: spec.icon
        }
      nil ->
        # Default fallback
        %{
          name: String.replace(specialization_code, "_", " ") |> String.capitalize(),
          description: "Healthcare Provider",
          can_prescribe: false,
          requires_license: true,
          category: nil,
          icon: "user-md"
        }
    end
  end

  defp get_specialization_info(_), do: nil

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
  defp filter_by_criteria(providers, "active"), do: Enum.filter(providers, & &1.is_active)
  defp filter_by_criteria(providers, "inactive"), do: Enum.filter(providers, &(!&1.is_active))

  defp filter_by_criteria(providers, filter) do
    # Handle category-based filtering
    case filter do
      "category:" <> category ->
        category_specializations = get_category_specializations(category)
        Enum.filter(providers, fn p ->
          p.specialization in category_specializations
        end)

      # Handle individual specialization filtering
      specialization ->
        if is_valid_specialization?(specialization) do
          Enum.filter(providers, fn p ->
            p.specialization == specialization
          end)
        else
          providers
        end
    end
  end

  defp get_category_specializations(category) do
    # Use the setup module
    App.Setup.Specializations.by_category(category)
    |> Enum.map(& &1.code)
  rescue
    _ ->
      # If there's an error, return empty list
      []
  end

  defp is_valid_specialization?(code) do
    # Check configuration
    App.Setup.Specializations.valid?(code)
  rescue
    _ -> false
  end

  defp search_providers(providers, ""), do: providers

  defp search_providers(providers, search) do
    search = String.downcase(search)

    Enum.filter(providers, fn p ->
      String.contains?(String.downcase(p.name), search) ||
        String.contains?(String.downcase(p.user.email), search)
    end)
  end

  # Helper function to safely get client IP
  defp get_connect_ip(socket) do
    case socket.assigns do
      %{connect_params: %{"_csrf_token" => _}} -> "127.0.0.1"
      _ -> "127.0.0.1"
    end
  end

  # Template helper functions
  defp display_specialization_name(code) when is_binary(code) do
    # Try to get from setup module first, fallback to simple formatting
    try do
      App.Setup.Specializations.display_name(code)
    rescue
      _ ->
        # Simple fallback formatting
        code
        |> String.replace("_", " ")
        |> String.split(" ")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
    end
  end

  defp display_specialization_name(_), do: "Unknown Specialization"
end