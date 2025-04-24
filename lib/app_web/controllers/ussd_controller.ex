defmodule AppWeb.UssdController do
  use AppWeb, :controller

  alias App.Accounts
  alias App.Scheduling
  alias App.USSDSession

  def handle(conn, %{"sessionId" => session_id, "phoneNumber" => phone_number, "text" => text} = params) do
    response = process_ussd_request(session_id, phone_number, text)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, response)
  end

  defp process_ussd_request(session_id, phone_number, text) do
    # Get or create USSD session
    session = USSDSession.get_or_create(session_id, phone_number)

    # Parse the user input
    input_parts = String.split(text, "*")
    current_input = List.last(input_parts) || ""

    # Process based on the session state
    case session.state do
      :initial ->
        handle_initial_menu(session, phone_number)

      :main_menu ->
        handle_main_menu(session, current_input)

      :book_appointment ->
        handle_book_appointment(session, current_input)

      :check_appointments ->
        handle_check_appointments(session, current_input)

      :select_child ->
        handle_select_child(session, current_input)

      :select_date ->
        handle_select_date(session, current_input)

      :select_time ->
        handle_select_time(session, current_input)

      :confirm_booking ->
        handle_confirm_booking(session, current_input)

      _ ->
        "END An error occurred. Please try again."
    end
  end

  defp handle_initial_menu(session, phone_number) do
    user = Accounts.get_user_by_phone(phone_number)

    if user do
      USSDSession.update_state(session, :main_menu, %{user_id: user.id})
      """
      CON Welcome to Under Five Health Check-Up
      1. Book Appointment
      2. Check Appointments
      3. Cancel Appointment
      """
    else
      "END Phone number not registered. Please register on our website."
    end
  end

  defp handle_main_menu(session, input) do
    case input do
      "1" ->
        USSDSession.update_state(session, :select_child)
        handle_select_child(session, "")

      "2" ->
        USSDSession.update_state(session, :check_appointments)
        handle_check_appointments(session, "")

      "3" ->
        "END This feature is coming soon."

      _ ->
        "CON Invalid option. Please select:\n1. Book Appointment\n2. Check Appointments\n3. Cancel Appointment"
    end
  end

  defp handle_book_appointment(session, _input) do
    # This function is called when the state is :book_appointment
    # At this point, the user has already selected to book an appointment
    # and we need to guide them through the booking process

    # Since this state is just transitional, we immediately move to selecting a child
    USSDSession.update_state(session, :select_child)
    handle_select_child(session, "")
  end

  defp handle_select_child(session, input) do
    user_id = session.data.user_id
    children = Accounts.list_children(user_id)

    if input == "" do
      # Display children list
      child_options =
        children
        |> Enum.with_index(1)
        |> Enum.map(fn {child, index} -> "#{index}. #{child.name}" end)
        |> Enum.join("\n")

      "CON Select child:\n#{child_options}"
    else
      # Process selection
      index = String.to_integer(input) - 1

      if child = Enum.at(children, index) do
        USSDSession.update_state(session, :select_date, Map.put(session.data, :child_id, child.id))
        handle_select_date(session, "")
      else
        "CON Invalid selection. Please try again:\n" <> handle_select_child(session, "")
      end
    end
  end

  defp handle_select_date(session, input) do
    if input == "" do
      # Show available dates (next 5 working days)
      dates = get_next_available_dates(5)
      date_options =
        dates
        |> Enum.with_index(1)
        |> Enum.map(fn {date, index} -> "#{index}. #{format_date(date)}" end)
        |> Enum.join("\n")

      "CON Select appointment date:\n#{date_options}"
    else
      # Process date selection
      index = String.to_integer(input) - 1
      dates = get_next_available_dates(5)

      if date = Enum.at(dates, index) do
        USSDSession.update_state(session, :select_time, Map.put(session.data, :date, date))
        handle_select_time(session, "")
      else
        "CON Invalid selection. Please try again:\n" <> handle_select_date(session, "")
      end
    end
  end

  defp handle_select_time(session, input) do
    if input == "" do
      # Show available time slots
      provider = get_available_provider()
      date = session.data.date
      slots = Scheduling.get_available_slots(provider.id, date)

      time_options =
        slots
        |> Enum.with_index(1)
        |> Enum.map(fn {slot, index} -> "#{index}. #{format_time(slot)}" end)
        |> Enum.join("\n")

      "CON Select appointment time:\n#{time_options}"
    else
      # Process time selection
      index = String.to_integer(input) - 1
      provider = get_available_provider()
      date = session.data.date
      slots = Scheduling.get_available_slots(provider.id, date)

      if time_slot = Enum.at(slots, index) do
        USSDSession.update_state(session, :confirm_booking, Map.merge(session.data, %{
          time: time_slot,
          provider_id: provider.id
        }))
        handle_confirm_booking(session, "")
      else
        "CON Invalid selection. Please try again:\n" <> handle_select_time(session, "")
      end
    end
  end

  defp handle_confirm_booking(session, input) do
    if input == "" do
      child = Accounts.get_child!(session.data.child_id)
      date = session.data.date
      time = session.data.time

      """
      CON Confirm appointment:
      Child: #{child.name}
      Date: #{format_date(date)}
      Time: #{format_time(time)}

      1. Confirm
      2. Cancel
      """
    else
      case input do
        "1" ->
          # Create the appointment
          case Scheduling.create_appointment(%{
            child_id: session.data.child_id,
            provider_id: session.data.provider_id,
            scheduled_date: session.data.date,
            scheduled_time: session.data.time,
            status: "scheduled"
          }) do
            {:ok, appointment} ->
              USSDSession.end_session(session)
              "END Appointment booked successfully! You will receive a confirmation SMS."

            {:error, _} ->
              "END Failed to book appointment. Please try again later."
          end

        "2" ->
          USSDSession.update_state(session, :main_menu)
          handle_main_menu(session, "")

        _ ->
          "CON Invalid option. Please select:\n1. Confirm\n2. Cancel"
      end
    end
  end

  defp handle_check_appointments(session, _input) do
    user_id = session.data.user_id
    children = Accounts.list_children(user_id)

    appointments =
      children
      |> Enum.flat_map(fn child ->
        Scheduling.upcoming_appointments(child.id)
      end)
      |> Enum.take(3)

    if Enum.empty?(appointments) do
      "END You have no upcoming appointments."
    else
      appointment_list =
        appointments
        |> Enum.map(fn appt ->
          "#{appt.child.name} - #{format_date(appt.scheduled_date)} at #{format_time(appt.scheduled_time)}"
        end)
        |> Enum.join("\n")

      "END Upcoming appointments:\n#{appointment_list}"
    end
  end

  # Helper functions

  defp get_next_available_dates(count) do
    today = Date.utc_today()

    1..30
    |> Enum.map(fn days -> Date.add(today, days) end)
    |> Enum.filter(fn date ->
      # Only weekdays
      day_of_week = Date.day_of_week(date)
      day_of_week >= 1 && day_of_week <= 5
    end)
    |> Enum.take(count)
  end

  defp get_available_provider do
    # For simplicity, get the first available provider
    # In a real app, this would be more sophisticated
    Scheduling.list_providers() |> List.first()
  end

  defp format_date(date) do
    Calendar.strftime(date, "%d %b %Y")
  end

  defp format_time(time) do
    Calendar.strftime(time, "%I:%M %p")
  end
end
