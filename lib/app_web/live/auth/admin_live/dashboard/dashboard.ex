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

      # Get provider performance (providers with most appointments)
      providers_with_appointments = get_provider_performance()

      socket =
        socket
        |> assign(:user, user)
        |> assign(:stats, get_system_stats())
        |> assign(:providers, providers_with_appointments)
        |> assign(:appointment_chart_data, get_appointment_chart_data())
        |> assign(:recent_activity, get_recent_activity())
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

  defp get_system_stats() do
    # Get statistics data
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
      users: %{
        total: length(Accounts.list_users()),
        parents: length(Accounts.list_users_by_role("parent")),
        providers: length(Accounts.list_users_by_role("provider")),
        admins: length(Accounts.list_users_by_role("admin"))
      },
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
  end

  defp get_recent_activity do
    # Get recent audit logs for activity feed
    recent_logs = App.Administration.Auditing.list_audit_logs([
      limit: 10,
      order_by: [desc: :inserted_at]
    ])

    # Get recent appointments
    recent_appointments = App.Scheduling.list_appointments()
                          |> Enum.filter(fn appt ->
      Date.diff(Date.utc_today(), appt.inserted_at |> DateTime.to_date()) <= 7
    end)
                          |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
                          |> Enum.take(5)

    # Get recent user registrations
    recent_users = App.Accounts.list_users()
                   |> Enum.filter(fn user ->
      Date.diff(Date.utc_today(), user.inserted_at |> DateTime.to_date()) <= 7
    end)
                   |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
                   |> Enum.take(3)

    # Combine and format activities
    activities = []

    # Add appointment activities
    appointment_activities = Enum.map(recent_appointments, fn appointment ->
      child = App.Accounts.get_child!(appointment.child_id)
      provider = App.Scheduling.get_provider!(appointment.provider_id)

      %{
        type: :appointment,
        icon: get_appointment_icon(appointment.status),
        icon_color: get_appointment_icon_color(appointment.status),
        title: get_appointment_title(appointment.status),
        description: "#{child.name} with #{provider.name}",
        timestamp: appointment.inserted_at,
        relative_time: format_relative_time(appointment.inserted_at)
      }
    end)

    # Add user registration activities
    user_activities = Enum.map(recent_users, fn user ->
      %{
        type: :user_registration,
        icon: "user-plus",
        icon_color: "text-blue-600",
        title: "New #{String.capitalize(user.role)} registered",
        description: "#{user.name} joined the platform",
        timestamp: user.inserted_at,
        relative_time: format_relative_time(user.inserted_at)
      }
    end)

    # Add audit log activities for important actions
    audit_activities = recent_logs
                       |> Enum.filter(&important_action?/1)
                       |> Enum.map(fn log ->
      %{
        type: :audit_action,
        icon: get_audit_icon(log.action),
        icon_color: get_audit_icon_color(log.action),
        title: format_audit_title(log),
        description: format_audit_description(log),
        timestamp: log.inserted_at,
        relative_time: format_relative_time(log.inserted_at)
      }
    end)

    # Combine all activities and sort by timestamp
    (appointment_activities ++ user_activities ++ audit_activities)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(10)
  end

  # Helper functions for activity formatting
  defp get_appointment_icon(status) do
    case status do
      "completed" -> "check-circle"
      "cancelled" -> "x-circle"
      "scheduled" -> "calendar"
      "confirmed" -> "calendar-check"
      "rescheduled" -> "calendar-days"
      _ -> "calendar"
    end
  end

  defp get_appointment_icon_color(status) do
    case status do
      "completed" -> "text-green-600"
      "cancelled" -> "text-red-600"
      "scheduled" -> "text-blue-600"
      "confirmed" -> "text-indigo-600"
      "rescheduled" -> "text-yellow-600"
      _ -> "text-gray-600"
    end
  end

  defp get_appointment_title(status) do
    case status do
      "completed" -> "Appointment completed"
      "cancelled" -> "Appointment cancelled"
      "scheduled" -> "New appointment scheduled"
      "confirmed" -> "Appointment confirmed"
      "rescheduled" -> "Appointment rescheduled"
      _ -> "Appointment updated"
    end
  end

  defp important_action?(log) do
    log.action in ["create", "delete"] and
    log.entity_type in ["parent", "provider", "appointment", "child"]
  end

  defp get_audit_icon(action) do
    case action do
      "create" -> "plus-circle"
      "delete" -> "trash"
      "update" -> "pencil"
      _ -> "information-circle"
    end
  end

  defp get_audit_icon_color(action) do
    case action do
      "create" -> "text-green-600"
      "delete" -> "text-red-600"
      "update" -> "text-blue-600"
      _ -> "text-gray-600"
    end
  end

  defp format_audit_title(log) do
    entity_name = String.capitalize(String.replace(log.entity_type, "_", " "))
    action_name = String.capitalize(log.action)

    "#{entity_name} #{action_name}d"
  end

  defp format_audit_description(log) do
    case log.details do
      %{"name" => name} -> name
      %{"child_name" => name} -> name
      %{"parent_name" => name} -> name
      %{"provider_name" => name} -> name
      _ -> "#{log.entity_type} #{log.action}"
    end
  end

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "#{diff_seconds} seconds ago"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%B %d at %I:%M %p")
    end
  end
end
