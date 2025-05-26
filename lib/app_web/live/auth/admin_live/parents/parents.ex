defmodule AppWeb.AdminLive.Parents do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Accounts.{User, Child}
  alias App.Scheduling

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "parents:update")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:parents, list_parents_with_details())
        |> assign(:page_title, "Parent Management")
        |> assign(:filter, "all")
        |> assign(:search, "")
        |> assign(:show_form, false)
        |> assign(:show_child_form, false)
        |> assign(:show_details_modal, false)
        |> assign(:show_appointment_form, false)
        |> assign(:selected_parent_id, nil)
        |> assign(:selected_child_id, nil)
        |> assign(:parent_changeset, Accounts.change_user_registration(%User{}))
        |> assign(:child_changeset, nil)
        |> assign(:providers, Scheduling.list_providers())
        |> assign(:available_slots, [])
        |> assign(:selected_date, nil)
        |> assign(:selected_provider_id, nil)
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

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("toggle_parent_form", _, socket) do
    {:noreply,
      socket
      |> assign(:show_form, !socket.assigns.show_form)
      |> assign(:parent_changeset, Accounts.change_user_registration(%User{}))}
  end

  @impl true
  def handle_event("save_parent", %{"user" => user_params}, socket) do
    user_params = Map.put(user_params, "role", "parent")

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Log the creation
        App.Administration.Auditing.log_action(%{
          action: "create",
          entity_type: "parent",
          entity_id: user.id,
          user_id: socket.assigns.user.id,
          details: %{
            parent_name: user.name,
            parent_email: user.email
          }
        })

        {:noreply,
          socket
          |> put_flash(:info, "Parent account created successfully.")
          |> assign(:parents, list_parents_with_details())
          |> assign(:show_form, false)
          |> assign(:parent_changeset, Accounts.change_user_registration(%User{}))}

      {:error, changeset} ->
        {:noreply, assign(socket, :parent_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("validate_parent", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :parent_changeset, changeset)}
  end

  @impl true
  def handle_event("show_child_form", %{"parent_id" => parent_id}, socket) do
    {:noreply,
      socket
      |> assign(:show_child_form, true)
      |> assign(:show_details_modal, false)
      |> assign(:selected_parent_id, String.to_integer(parent_id))}
  end

  @impl true
  def handle_event("hide_child_form", _, socket) do
    {:noreply,
      socket
      |> assign(:show_child_form, false)
      |> assign(:selected_parent_id, nil)
      |> assign(:child_changeset, %Child{} |> Accounts.change_child(%{}))}
  end

  @impl true
  def handle_event("save_child", %{"child" => child_params}, socket) do
    parent = Accounts.get_user!(socket.assigns.selected_parent_id)

    case Accounts.create_child(parent, child_params) do
      {:ok, child} ->
        # Log the creation
        App.Administration.Auditing.log_action(%{
          action: "create",
          entity_type: "child",
          entity_id: child.id,
          user_id: socket.assigns.user.id,
          details: %{
            child_name: child.name,
            parent_name: parent.name,
            date_of_birth: child.date_of_birth
          }
        })

        {:noreply,
          socket
          |> put_flash(:info, "Child #{child.name} created successfully.")
          |> assign(:parents, list_parents_with_details())
          |> assign(:show_child_form, false)
          |> assign(:selected_parent_id, nil)
          |> assign(:child_changeset, Accounts.change_child(%Child{}))}

      {:error, changeset} ->
        {:noreply, assign(socket, :child_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("validate_child", %{"child" => child_params}, socket) do
    changeset =
      %Child{}
      |> Accounts.change_child(child_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :child_changeset, changeset)}
  end

  @impl true
  def handle_event("show_appointment_form", %{"child_id" => child_id}, socket) do
    {:noreply,
      socket
      |> assign(:show_appointment_form, true)
      |> assign(:selected_child_id, String.to_integer(child_id))
      |> assign(:selected_date, nil)
      |> assign(:selected_provider_id, nil)
      |> assign(:available_slots, [])}
  end

  @impl true
  def handle_event("hide_appointment_form", _, socket) do
    {:noreply,
      socket
      |> assign(:show_appointment_form, false)
      |> assign(:selected_child_id, nil)
      |> assign(:selected_date, nil)
      |> assign(:selected_provider_id, nil)
      |> assign(:available_slots, [])}
  end

  @impl true
  def handle_event("date_selected", %{"date" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        # Reset available slots when date changes
        {:noreply,
          socket
          |> assign(:selected_date, date)
          |> assign(:available_slots, [])}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("provider_selected", %{"provider_id" => provider_id}, socket) do
    provider_id = String.to_integer(provider_id)

    if socket.assigns.selected_date do
      available_slots = Scheduling.get_available_slots(provider_id, socket.assigns.selected_date)

      {:noreply,
        socket
        |> assign(:selected_provider_id, provider_id)
        |> assign(:available_slots, available_slots)}
    else
      {:noreply, assign(socket, :selected_provider_id, provider_id)}
    end
  end

  @impl true
  def handle_event("create_appointment", %{"time" => time_string}, socket) do
    case Time.from_iso8601(time_string) do
      {:ok, time} ->
        appointment_params = %{
          child_id: socket.assigns.selected_child_id,
          provider_id: socket.assigns.selected_provider_id,
          scheduled_date: socket.assigns.selected_date,
          scheduled_time: time,
          status: "scheduled",
          notes: "Appointment created by admin"
        }

        case Scheduling.create_appointment(appointment_params) do
          {:ok, appointment} ->
            child = Accounts.get_child!(socket.assigns.selected_child_id)
            provider = Scheduling.get_provider!(socket.assigns.selected_provider_id)

            # Log the creation
            App.Administration.Auditing.log_action(%{
              action: "create",
              entity_type: "appointment",
              entity_id: appointment.id,
              user_id: socket.assigns.user.id,
              details: %{
                child_name: child.name,
                provider_name: provider.name,
                scheduled_date: appointment.scheduled_date,
                scheduled_time: appointment.scheduled_time
              }
            })

            {:noreply,
              socket
              |> put_flash(:info, "Appointment created successfully for #{child.name}.")
              |> assign(:show_appointment_form, false)
              |> assign(:selected_child_id, nil)
              |> assign(:selected_date, nil)
              |> assign(:selected_provider_id, nil)
              |> assign(:available_slots, [])
              |> assign(:parents, list_parents_with_details())}

          {:error, changeset} ->
            {:noreply,
              socket
              |> put_flash(:error, "Failed to create appointment: #{format_errors(changeset)}")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid time selected.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    parent = Accounts.get_user!(id)

    # Check if parent has children - we'll cascade delete
    children = Accounts.list_children(parent.id)
    children_count = length(children)

    # In a production app, you might want to soft delete or transfer children
    case delete_user_and_children(parent, children) do
      {:ok, _} ->
        # Log the deletion
        App.Administration.Auditing.log_action(%{
          action: "delete",
          entity_type: "parent",
          entity_id: id,
          user_id: socket.assigns.user.id,
          details: %{
            parent_name: parent.name,
            children_count: children_count
          }
        })

        message = if children_count > 0 do
          "Parent and #{children_count} children deleted successfully."
        else
          "Parent deleted successfully."
        end

        {:noreply,
          socket
          |> put_flash(:info, message)
          |> assign(:parents, list_parents_with_details())}

      {:error, reason} ->
        {:noreply,
          socket
          |> put_flash(:error, "Could not delete parent account: #{reason}")
          |> assign(:parents, list_parents_with_details())}
    end
  end

  # Private helper functions

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp list_parents_with_details do
    # Get all users with role "parent"
    parents = Accounts.list_users_by_role("parent")

    Enum.map(parents, fn parent ->
      # Get children for this parent
      children = Accounts.list_children(parent.id)

      # Get upcoming appointments count
      upcoming_appointments =
        children
        |> Enum.flat_map(fn child ->
          Scheduling.upcoming_appointments(child.id)
        end)
        |> length()

      # Calculate registration time in days
      days_since_registration =
        DateTime.utc_now()
        |> DateTime.diff(parent.inserted_at, :day)

      # Return parent with additional details
      %{
        id: parent.id,
        name: parent.name,
        email: parent.email,
        phone: parent.phone,
        children_count: length(children),
        children: children,
        upcoming_appointments: upcoming_appointments,
        days_since_registration: days_since_registration,
        confirmed: not is_nil(parent.confirmed_at)
      }
    end)
  end

  defp delete_user_and_children(parent, children) do
    # Use a transaction to ensure all deletions succeed or none do
    App.Repo.transaction(fn ->
      # Delete all children first (this will cascade to their appointments)
      Enum.each(children, fn child ->
        case Accounts.delete_child(child) do
          {:ok, _} -> :ok
          {:error, _} -> App.Repo.rollback("Failed to delete child #{child.name}")
        end
      end)

      # Delete the parent user
      case Accounts.delete_user(parent) do
        {:ok, user} -> user
        {:error, _} -> App.Repo.rollback("Failed to delete parent #{parent.name}")
      end
    end)
  end

  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp filtered_parents(parents, filter, search) do
    parents
    |> filter_by_criteria(filter)
    |> search_parents(search)
  end

  defp filter_by_criteria(parents, "all"), do: parents

  defp filter_by_criteria(parents, "confirmed") do
    Enum.filter(parents, fn p -> p.confirmed end)
  end

  defp filter_by_criteria(parents, "unconfirmed") do
    Enum.filter(parents, fn p -> not p.confirmed end)
  end

  defp filter_by_criteria(parents, "with_children") do
    Enum.filter(parents, fn p -> p.children_count > 0 end)
  end

  defp filter_by_criteria(parents, "no_children") do
    Enum.filter(parents, fn p -> p.children_count == 0 end)
  end

  defp search_parents(parents, ""), do: parents

  defp search_parents(parents, search) do
    search = String.downcase(search)

    Enum.filter(parents, fn p ->
      String.contains?(String.downcase(p.name), search) ||
        String.contains?(String.downcase(p.email), search) ||
        String.contains?(String.downcase(p.phone), search)
    end)
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end

  defp get_child_by_id(children, child_id) do
    Enum.find(children, &(&1.id == child_id))
  end

  @impl true
  def handle_event("view_parent_details", %{"parent_id" => parent_id}, socket) do
    parent = Accounts.get_user!(parent_id)
    children = Accounts.list_children(parent.id)

    # Get appointment statistics
    all_appointments = children
                       |> Enum.flat_map(fn child ->
      Scheduling.list_appointments(child_id: child.id)
    end)

    upcoming_appointments = Enum.count(all_appointments, fn appointment ->
      Date.compare(appointment.scheduled_date, Date.utc_today()) in [:eq, :gt] and
      appointment.status in ["scheduled", "confirmed"]
    end)

    completed_appointments = Enum.count(all_appointments, &(&1.status == "completed"))

    parent_details = %{
      parent: parent,
      children: children,
      total_appointments: length(all_appointments),
      upcoming_appointments: upcoming_appointments,
      completed_appointments: completed_appointments
    }

    {:noreply,
      socket
      |> assign(:show_details_modal, true)
      |> assign(:parent_details, parent_details)}
  end

  @impl true
  def handle_event("hide_details_modal", _, socket) do
    {:noreply,
      socket
      |> assign(:show_details_modal, false)
      |> assign(:parent_details, nil)}
  end
end