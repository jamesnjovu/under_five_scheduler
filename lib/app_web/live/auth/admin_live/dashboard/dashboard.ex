defmodule AppWeb.AdminLive.Dashboard do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Scheduling
  alias App.Analytics

  @impl true
  def mount(_params, session, socket) do
    # Verify admin role
    user = get_user_from_session(session)

    if Accounts.is_admin?(user) do
      if connected?(socket) do
        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(App.PubSub, "analytics:dashboard")
      end

      # Get statistics data
      total_users = length(Accounts.list_users())
      total_parents = length(Accounts.list_users_by_role("parent"))
      total_providers = length(Accounts.list_users_by_role("provider"))
      total_children = length(Accounts.list_children())

      # Get appointment statistics
      today = Date.utc_today()
      start_of_month = Date.beginning_of_month(today)

      appointments = Scheduling.list_appointments()

      upcoming_appointments =
        Enum.filter(appointments, fn appt ->
          Date.compare(appt.scheduled_date, today) in [:eq, :gt] &&
            appt.status in ["scheduled", "confirmed"]
        end)

      monthly_appointments =
        Enum.filter(appointments, fn appt ->
          Date.compare(appt.scheduled_date, start_of_month) in [:eq, :gt]
        end)

      # Calculate statistics
      stats = %{
        total_users: total_users,
        total_parents: total_parents,
        total_providers: total_providers,
        total_children: total_children,

        # Appointment statistics
        total_appointments: length(appointments),
        upcoming_appointments: length(upcoming_appointments),
        today_appointments: Enum.count(appointments, fn appt -> appt.scheduled_date == today end),

        # Monthly statistics
        monthly_appointments: length(monthly_appointments),
        monthly_completed:
          Enum.count(monthly_appointments, fn appt -> appt.status == "completed" end),
        monthly_cancelled:
          Enum.count(monthly_appointments, fn appt -> appt.status == "cancelled" end),
        monthly_no_show: Enum.count(monthly_appointments, fn appt -> appt.status == "no_show" end)
      }

      # Get provider performance (providers with most appointments)
      providers_with_appointments = get_provider_performance()

      socket =
        socket
        |> assign(:user, user)
        |> assign(:stats, stats)
        |> assign(:providers, providers_with_appointments)
        |> assign(:appointment_chart_data, get_appointment_chart_data())
        |> assign(:page_title, "Admin Dashboard")
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

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  # Get data for providers with appointments count
  defp get_provider_performance do
    # In a real app, this would use a proper query with joins and counts
    providers = Scheduling.list_providers()

    Enum.map(providers, fn provider ->
      # Get counts of different appointment statuses
      appointments = Scheduling.list_appointments(provider_id: provider.id)
      total = length(appointments)

      completed = Enum.count(appointments, fn a -> a.status == "completed" end)
      no_show = Enum.count(appointments, fn a -> a.status == "no_show" end)

      # Calculate completion rate
      completion_rate = if total > 0, do: completed / total * 100, else: 0

      %{
        provider: provider,
        total_appointments: total,
        completed_appointments: completed,
        no_show_appointments: no_show,
        completion_rate: completion_rate
      }
    end)
    |> Enum.sort_by(fn %{total_appointments: count} -> count end, :desc)
    # Top 5 providers
    |> Enum.take(5)
  end

  # Get chart data for appointments by month
  defp get_appointment_chart_data do
    # In real app, this would be a database query with proper grouping
    today = Date.utc_today()

    # Get last 6 months
    months =
      for n <- 5..0 do
        Date.add(today, -n * 30)
        |> Date.beginning_of_month()
      end

    Enum.map(months, fn month ->
      month_str = Calendar.strftime(month, "%b")
      next_month = Date.add(month, 31) |> Date.beginning_of_month()

      # Get appointments for this month
      appointments =
        Scheduling.list_appointments()
        |> Enum.filter(fn appt ->
          Date.compare(appt.scheduled_date, month) in [:eq, :gt] &&
            Date.compare(appt.scheduled_date, next_month) == :lt
        end)

      # Count by status
      scheduled = Enum.count(appointments, fn a -> a.status in ["scheduled", "confirmed"] end)
      completed = Enum.count(appointments, fn a -> a.status == "completed" end)
      cancelled = Enum.count(appointments, fn a -> a.status == "cancelled" end)
      no_show = Enum.count(appointments, fn a -> a.status == "no_show" end)

      %{
        month: month_str,
        scheduled: scheduled,
        completed: completed,
        cancelled: cancelled,
        no_show: no_show,
        total: length(appointments)
      }
    end)
  end
end
