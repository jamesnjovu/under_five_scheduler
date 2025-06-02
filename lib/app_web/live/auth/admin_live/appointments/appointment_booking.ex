defmodule AppWeb.AdminLive.AppointmentBooking do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.Scheduling.Appointment

  @impl true
  def mount(params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      providers = Scheduling.list_active_providers()

      # Get child if child_id is provided
      {child, parent} = case params do
        %{"child_id" => child_id} ->
          child = Accounts.get_child!(child_id)
          parent = Accounts.get_user!(child.user_id)
          {child, parent}
        _ -> {nil, nil}
      end

      # Initialize current month and calendar data
      current_month = Date.utc_today()
                      |> Date.beginning_of_month()

      socket =
        socket
        |> assign(:user, user)
        |> assign(:page_title, "Book Appointment")
        |> assign(:providers, providers)
        |> assign(:child, child)
        |> assign(:parent, parent)
        |> assign(:selected_provider_id, nil)
        |> assign(:selected_date, nil)
        |> assign(:available_dates, [])
        |> assign(:available_slots, [])
        |> assign(:selected_time, nil)
        |> assign(:appointment_changeset, nil)
        |> assign(:current_month, current_month)
        |> assign(:calendar_weeks, [])
        |> assign(:current_step, if(child, do: "select_provider", else: "select_child"))
        |> assign(:show_sidebar, false)
        |> assign(:all_children, list_all_children())

      {:ok, socket}
    else
      {
        :ok,
        socket
        |> put_flash(:error, "You don't have access to this page.")
        |> redirect(to: ~p"/admin/dashboard")
      }
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("select_child", %{"child_id" => child_id}, socket) do
    child = Accounts.get_child!(child_id)
    parent = Accounts.get_user!(child.user_id)

    {
      :noreply,
      socket
      |> assign(:child, child)
      |> assign(:parent, parent)
      |> assign(:current_step, "select_provider")
    }
  end

  @impl true
  def handle_event("select_provider", %{"provider_id" => provider_id}, socket) do
    provider_id = String.to_integer(provider_id)

    # Get available dates for this provider
    available_dates = get_provider_available_dates(provider_id, 90)

    # Generate calendar data for current month
    calendar_weeks = generate_calendar_weeks(socket.assigns.current_month)

    {
      :noreply,
      socket
      |> assign(:selected_provider_id, provider_id)
      |> assign(:available_dates, available_dates)
      |> assign(:calendar_weeks, calendar_weeks)
      |> assign(:current_step, "select_date")
    }
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    new_month = Date.add(socket.assigns.current_month, -32)
                |> Date.beginning_of_month()
    calendar_weeks = generate_calendar_weeks(new_month)

    {
      :noreply,
      socket
      |> assign(:current_month, new_month)
      |> assign(:calendar_weeks, calendar_weeks)
    }
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    new_month = Date.add(socket.assigns.current_month, 32)
                |> Date.beginning_of_month()
    calendar_weeks = generate_calendar_weeks(new_month)

    {
      :noreply,
      socket
      |> assign(:current_month, new_month)
      |> assign(:calendar_weeks, calendar_weeks)
    }
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    with {:ok, date} <- Date.from_iso8601(date_string),
         provider_id = socket.assigns.selected_provider_id do
      # Get available slots for the selected date and provider
      available_slots = Scheduling.get_available_slots(provider_id, date)

      {
        :noreply,
        socket
        |> assign(:selected_date, date)
        |> assign(:available_slots, available_slots)
        |> assign(:current_step, "select_time")
      }
    else
      _ -> {:noreply, put_flash(socket, :error, "Invalid date selected.")}
    end
  end

  @impl true
  def handle_event("select_time", %{"time" => time_string}, socket) do
    case parse_time(time_string) do
      {:ok, time} ->
        # Create appointment changeset
        appointment_params = %{
          child_id: socket.assigns.child.id,
          provider_id: socket.assigns.selected_provider_id,
          scheduled_date: socket.assigns.selected_date,
          scheduled_time: time,
          status: "scheduled",
          notes: "Appointment created by admin"
        }

        changeset = Appointment.changeset(%Appointment{}, appointment_params)

        {
          :noreply,
          socket
          |> assign(:selected_time, time)
          |> assign(:appointment_changeset, changeset)
          |> assign(:current_step, "confirm")
        }

      {:error, reason} ->
        {
          :noreply,
          socket
          |> put_flash(:error, "Invalid time selected: #{reason}. Please try again.")
        }
    end
  end

  @impl true
  def handle_event("update_notes", %{"value" => notes}, socket) do
    changeset =
      socket.assigns.appointment_changeset
      |> Ecto.Changeset.put_change(:notes, notes)

    {:noreply, assign(socket, :appointment_changeset, changeset)}
  end

  @impl true
  def handle_event("confirm_appointment", _params, socket) do
    appointment_params = Ecto.Changeset.apply_changes(socket.assigns.appointment_changeset)
    params_map = Map.from_struct(appointment_params)

    case Scheduling.create_appointment(params_map) do
      {:ok, appointment} ->
        # Log the creation
        App.Administration.Auditing.log_action(
          %{
            action: "create",
            entity_type: "appointment",
            entity_id: appointment.id,
            user_id: socket.assigns.user.id,
            details: %{
              child_name: socket.assigns.child.name,
              parent_name: socket.assigns.parent.name,
              provider_name: Enum.find(socket.assigns.providers, &(&1.id == socket.assigns.selected_provider_id)).name,
              scheduled_date: appointment.scheduled_date,
              scheduled_time: appointment.scheduled_time,
              created_by: "admin"
            }
          }
        )

        {
          :noreply,
          socket
          |> put_flash(:info, "Appointment scheduled successfully for #{socket.assigns.child.name}!")
          |> redirect(to: ~p"/admin/parents")
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        error_message = "Error creating appointment: " <> format_changeset_errors(changeset)

        {
          :noreply,
          socket
          |> put_flash(:error, error_message)
          |> assign(:appointment_changeset, changeset)
        }
    end
  end

  @impl true
  def handle_event("back", _params, socket) do
    current_step = socket.assigns.current_step

    previous_step =
      case current_step do
        "select_provider" -> "select_child"
        "select_date" -> "select_provider"
        "select_time" -> "select_date"
        "confirm" -> "select_time"
        _ -> current_step
      end

    {:noreply, assign(socket, :current_step, previous_step)}
  end

  # Private helper functions

  defp get_user_from_session(session) do
    token = session["user_token"]
    Accounts.get_user_by_session_token(token)
  end

  defp list_all_children do
    # Get all parents and their children
    parents = Accounts.list_users_by_role("parent")

    Enum.flat_map(
      parents,
      fn parent ->
        Accounts.list_children(parent.id)
        |> Enum.map(
             fn child ->
               %{
                 child: child,
                 parent: parent
               }
             end
           )
      end
    )
    |> Enum.sort_by(fn %{child: child} -> child.name end)
  end

  defp get_provider_available_dates(provider_id, days_ahead) do
    # Get days in the specified range
    today = Date.utc_today()

    1..days_ahead
    |> Enum.map(fn days -> Date.add(today, days) end)
    |> Enum.filter(
         fn date ->
           # Get the day of week and check if provider has schedule
           day_of_week = Date.day_of_week(date)
           schedule = Scheduling.get_provider_schedule(provider_id, day_of_week)

           # Only include dates where provider has a schedule
           if schedule do
             # Also check if there are available slots
             slots = Scheduling.get_available_slots(provider_id, date)
             !Enum.empty?(slots)
           else
             false
           end
         end
       )
  end

  defp parse_time(time_string) do
    try do
      cond do
        # Handle ISO format (HH:MM:SS or HH:MM)
        String.match?(time_string, ~r/\d\d:\d\d(:\d\d)?/) ->
          parts = String.split(time_string, ":")
          hour = String.to_integer(Enum.at(parts, 0))
          minute = String.to_integer(Enum.at(parts, 1))

          # Validate hour and minute
          if hour >= 0 && hour < 24 && minute >= 0 && minute < 60 do
            {:ok, Time.new!(hour, minute, 0)}
          else
            {:error, "Invalid hour or minute values"}
          end

        # Handle "HH:MM AM/PM" format
        String.match?(time_string, ~r/\d{1,2}:\d{2} (AM|PM)/) ->
          [time_part, period] = String.split(time_string, " ")
          [hour_str, minute_str] = String.split(time_part, ":")
          hour = String.to_integer(hour_str)
          minute = String.to_integer(minute_str)

          hour = if period == "PM" && hour < 12, do: hour + 12, else: hour
          hour = if period == "AM" && hour == 12, do: 0, else: hour

          {:ok, Time.new!(hour, minute, 0)}

        true ->
          {:error, "Unrecognized time format"}
      end
    rescue
      e ->
        IO.inspect(e, label: "Error parsing time")
        {:error, "Error parsing time: #{inspect(e)}"}
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(
      changeset,
      fn {msg, opts} ->
        Enum.reduce(
          opts,
          msg,
          fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end
        )
      end
    )
    |> Enum.map(fn {k, v} -> "#{k} #{v}" end)
    |> Enum.join(", ")
  end

  defp generate_calendar_weeks(month) do
    first_day = Date.beginning_of_month(month)
    last_day = Date.end_of_month(month)

    # Convert Elixir's day_of_week (1-7, Monday is 1) to Sunday-based (0-6, Sunday is 0)
    day_to_sunday_based = fn day_of_week ->
      case day_of_week do
        7 -> 0
        # Sunday
        n -> n  # Monday through Saturday
      end
    end

    # Get the week day of the first day (1-7 where 1 is Monday)
    first_dow = Date.day_of_week(first_day)

    # Convert to 0-based for Sunday start (0-6 where 0 is Sunday)
    first_sunday_based = day_to_sunday_based.(first_dow)
    # Get the days before the first day of the month to fill the calendar
    days_before = List.duplicate(nil, first_sunday_based)

    # Get all days in the month
    days_in_month = Date.range(first_day, last_day)
                    |> Enum.to_list()

    # Calculate days after
    last_dow = Date.day_of_week(last_day)
    last_sunday_based = day_to_sunday_based.(last_dow)
    days_after = List.duplicate(nil, 6 - last_sunday_based)

    # Combine all days
    all_days = days_before ++ days_in_month ++ days_after

    # Split into weeks (chunks of 7)
    Enum.chunk_every(all_days, 7)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end
end
