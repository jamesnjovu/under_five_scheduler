defmodule AppWeb.AdminLive.Appointments do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.Scheduling.Appointment

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "appointments:update")
      end

      # Get current date and appointments for the view
      today = Date.utc_today()

      socket =
        socket
        |> assign(:user, user)
        |> assign(:current_date, today)
        # Options: day, week, month
        |> assign(:view_mode, "day")
        |> assign(:page_title, "Appointment Management")
        |> assign(:filter, "all")
        |> assign(:search, "")
        |> assign(:appointments, list_appointments_with_details(today))
        |> assign(:upcoming_appointments, get_upcoming_appointments())
        |> assign(:statistics, get_appointment_statistics())
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
  def handle_event("change_date", %{"date" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        {:noreply,
         socket
         |> assign(:current_date, date)
         |> assign(:appointments, list_appointments_with_details(date))}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("previous_day", _, socket) do
    new_date = Date.add(socket.assigns.current_date, -1)

    {:noreply,
     socket
     |> assign(:current_date, new_date)
     |> assign(:appointments, list_appointments_with_details(new_date))}
  end

  @impl true
  def handle_event("next_day", _, socket) do
    new_date = Date.add(socket.assigns.current_date, 1)

    {:noreply,
     socket
     |> assign(:current_date, new_date)
     |> assign(:appointments, list_appointments_with_details(new_date))}
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket)
      when view in ["day", "week", "month"] do
    {:noreply, assign(socket, :view_mode, view)}
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
  def handle_event("update_status", %{"id" => id, "status" => status}, socket)
      when status in [
             "scheduled",
             "confirmed",
             "cancelled",
             "completed",
             "no_show",
             "rescheduled"
           ] do
    appointment = Scheduling.get_appointment!(id)

    case Scheduling.update_appointment(appointment, %{status: status}) do
      {:ok, updated_appointment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Appointment status updated to #{status}.")
         |> assign(:appointments, list_appointments_with_details(socket.assigns.current_date))
         |> assign(:upcoming_appointments, get_upcoming_appointments())
         |> assign(:statistics, get_appointment_statistics())}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not update appointment status.")
         |> assign(:appointments, list_appointments_with_details(socket.assigns.current_date))}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp list_appointments_with_details(date) do
    # Get appointments for the given date
    appointments =
      case get_date_range(date) do
        {start_date, end_date} ->
          Scheduling.list_appointments()
          |> Enum.filter(fn appointment ->
            Date.compare(appointment.scheduled_date, start_date) in [:eq, :gt] &&
              Date.compare(appointment.scheduled_date, end_date) in [:eq, :lt]
          end)

        single_date ->
          Scheduling.list_appointments()
          |> Enum.filter(fn appointment -> appointment.scheduled_date == single_date end)
      end

    # Add additional information
    Enum.map(appointments, fn appointment ->
      child = Accounts.get_child!(appointment.child_id)
      provider = Scheduling.get_provider!(appointment.provider_id)

      # Calculate time until appointment
      days_until =
        if Date.compare(appointment.scheduled_date, Date.utc_today()) == :gt do
          Date.diff(appointment.scheduled_date, Date.utc_today())
        else
          0
        end

      # Return enriched appointment data
      %{
        id: appointment.id,
        scheduled_date: appointment.scheduled_date,
        scheduled_time: appointment.scheduled_time,
        status: appointment.status,
        notes: appointment.notes,
        child: child,
        provider: provider,
        days_until: days_until,
        formatted_time: format_time(appointment.scheduled_time)
      }
    end)
    |> Enum.sort_by(fn a -> {a.scheduled_date, a.scheduled_time} end)
  end

  defp get_date_range(date) do
    case date do
      :all ->
        # Return all appointments
        {~D[2020-01-01], Date.add(Date.utc_today(), 365)}

      _ ->
        # Return just the specified date
        date
    end
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end

  defp get_upcoming_appointments do
    today = Date.utc_today()

    Scheduling.list_appointments()
    |> Enum.filter(fn appointment ->
      Date.compare(appointment.scheduled_date, today) in [:eq, :gt] &&
        appointment.status in ["scheduled", "confirmed"]
    end)
    |> Enum.sort_by(fn a -> {a.scheduled_date, a.scheduled_time} end)
    |> Enum.take(5)
    |> Enum.map(fn appointment ->
      child = Accounts.get_child!(appointment.child_id)
      provider = Scheduling.get_provider!(appointment.provider_id)

      %{
        id: appointment.id,
        scheduled_date: appointment.scheduled_date,
        scheduled_time: appointment.scheduled_time,
        status: appointment.status,
        child: child,
        provider: provider,
        formatted_time: format_time(appointment.scheduled_time)
      }
    end)
  end

  defp get_appointment_statistics do
    all_appointments = Scheduling.list_appointments()
    today = Date.utc_today()

    # Today's appointments
    today_appointments = Enum.filter(all_appointments, fn a -> a.scheduled_date == today end)

    # This week's appointments
    {week_start, week_end} = get_week_range(today)

    this_week_appointments =
      Enum.filter(all_appointments, fn a ->
        Date.compare(a.scheduled_date, week_start) in [:eq, :gt] &&
          Date.compare(a.scheduled_date, week_end) in [:eq, :lt]
      end)

    # This month's appointments
    month_start = Date.beginning_of_month(today)
    # Last day of month
    month_end = Date.add(Date.beginning_of_month(Date.add(today, 32)), -1)

    this_month_appointments =
      Enum.filter(all_appointments, fn a ->
        Date.compare(a.scheduled_date, month_start) in [:eq, :gt] &&
          Date.compare(a.scheduled_date, month_end) in [:eq, :lt]
      end)

    # Calculate statistics
    %{
      total_appointments: length(all_appointments),
      today: %{
        total: length(today_appointments),
        confirmed: Enum.count(today_appointments, &(&1.status == "confirmed")),
        completed: Enum.count(today_appointments, &(&1.status == "completed")),
        cancelled: Enum.count(today_appointments, &(&1.status == "cancelled")),
        no_show: Enum.count(today_appointments, &(&1.status == "no_show"))
      },
      this_week: %{
        total: length(this_week_appointments),
        confirmed: Enum.count(this_week_appointments, &(&1.status == "confirmed")),
        completed: Enum.count(this_week_appointments, &(&1.status == "completed")),
        cancelled: Enum.count(this_week_appointments, &(&1.status == "cancelled")),
        no_show: Enum.count(this_week_appointments, &(&1.status == "no_show"))
      },
      this_month: %{
        total: length(this_month_appointments),
        confirmed: Enum.count(this_month_appointments, &(&1.status == "confirmed")),
        completed: Enum.count(this_month_appointments, &(&1.status == "completed")),
        cancelled: Enum.count(this_month_appointments, &(&1.status == "cancelled")),
        no_show: Enum.count(this_month_appointments, &(&1.status == "no_show"))
      }
    }
  end

  defp get_week_range(date) do
    # Get the start of the week (Monday)
    # 1-based (Monday is 1)
    start_offset = Date.day_of_week(date) - 1
    start_date = Date.add(date, -start_offset)

    # Get the end of the week (Sunday)
    end_date = Date.add(start_date, 7)

    {start_date, end_date}
  end

  defp filtered_appointments(appointments, filter, search) do
    appointments
    |> filter_by_status(filter)
    |> search_appointments(search)
  end

  defp filter_by_status(appointments, "all"), do: appointments

  defp filter_by_status(appointments, "scheduled") do
    Enum.filter(appointments, &(&1.status == "scheduled"))
  end

  defp filter_by_status(appointments, "confirmed") do
    Enum.filter(appointments, &(&1.status == "confirmed"))
  end

  defp filter_by_status(appointments, "completed") do
    Enum.filter(appointments, &(&1.status == "completed"))
  end

  defp filter_by_status(appointments, "cancelled") do
    Enum.filter(appointments, &(&1.status == "cancelled"))
  end

  defp filter_by_status(appointments, "no_show") do
    Enum.filter(appointments, &(&1.status == "no_show"))
  end

  defp search_appointments(appointments, ""), do: appointments

  defp search_appointments(appointments, search) do
    search = String.downcase(search)

    Enum.filter(appointments, fn a ->
      String.contains?(String.downcase(a.child.name), search) ||
        String.contains?(String.downcase(a.provider.name), search) ||
        String.contains?(String.downcase(a.notes || ""), search)
    end)
  end
end
