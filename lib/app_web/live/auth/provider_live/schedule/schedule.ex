defmodule AppWeb.ProviderLive.Schedule do
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
        Phoenix.PubSub.subscribe(App.PubSub, "appointments:updates")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:provider, provider)
        |> assign(:page_title, "My Schedule")
        |> assign(:schedules, get_provider_schedule(provider.id))
        |> assign(:active_tab, "schedule")
        |> assign(:editing_day, nil)
        |> assign(:form, nil)
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
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("edit_schedule", %{"day" => day}, socket) do
    day_num = String.to_integer(day)
    schedule = Enum.find(socket.assigns.schedules, fn s -> s.day_of_week == day_num end)

    form =
      if schedule do
        to_form(Scheduling.change_schedule(schedule))
      else
        to_form(
          Scheduling.change_schedule(%Scheduling.Schedule{
            provider_id: socket.assigns.provider.id,
            day_of_week: day_num,
            start_time: ~T[09:00:00],
            end_time: ~T[17:00:00]
          })
        )
      end

    {:noreply, socket |> assign(:editing_day, day_num) |> assign(:form, form)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, socket |> assign(:editing_day, nil) |> assign(:form, nil)}
  end

  @impl true
  def handle_event("save_schedule", %{"schedule" => params}, socket) do
    provider = socket.assigns.provider
    day_num = socket.assigns.editing_day
    schedule = Enum.find(socket.assigns.schedules, fn s -> s.day_of_week == day_num end)

    # Process time inputs
    start_time_str = params["start_time"]
    end_time_str = params["end_time"]

    params = Map.put(params, "provider_id", provider.id)
    params = Map.put(params, "day_of_week", day_num)

    result =
      if schedule do
        Scheduling.update_schedule(schedule, params)
      else
        # This works because our create_schedule/2 function in the context
        # expects a provider and attrs
        Scheduling.create_schedule(provider, params)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Schedule saved successfully.")
         |> assign(:editing_day, nil)
         |> assign(:form, nil)
         |> assign(:schedules, get_provider_schedule(provider.id))}

      {:error, changeset} ->
        {:noreply, socket |> assign(:form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_schedule", %{"day" => day}, socket) do
    day_num = String.to_integer(day)
    provider = socket.assigns.provider
    schedule = Enum.find(socket.assigns.schedules, fn s -> s.day_of_week == day_num end)

    if schedule do
      case Scheduling.delete_schedule(schedule) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Schedule deleted successfully.")
           |> assign(:schedules, get_provider_schedule(provider.id))}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not delete schedule.")}
      end
    else
      {:noreply, socket}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    user = Accounts.get_user_by_session_token(token)
    user
  end

  defp get_provider_schedule(provider_id) do
    # Gets all schedules for the provider and organizes them by day of week
    Scheduling.list_schedules()
    |> Enum.filter(fn s -> s.provider_id == provider_id end)
  end

  defp day_name(day_num) do
    case day_num do
      1 -> "Monday"
      2 -> "Tuesday"
      3 -> "Wednesday"
      4 -> "Thursday"
      5 -> "Friday"
      6 -> "Saturday"
      7 -> "Sunday"
      _ -> "Unknown"
    end
  end

  defp format_time(time) do
    hour = time.hour
    minute = time.minute

    am_pm = if hour >= 12, do: "PM", else: "AM"
    hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)

    "#{hour}:#{String.pad_leading("#{minute}", 2, "0")} #{am_pm}"
  end
end
