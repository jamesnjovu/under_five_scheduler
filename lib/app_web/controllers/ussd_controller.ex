defmodule AppWeb.USSDController do
  use AppWeb, :controller

  alias App.Accounts
  alias App.Scheduling
  alias App.USSDSession

  @doc """
  Main entry point for USSD requests.
  Handles requests from telecom USSD gateway.
  """
  def handle(
        conn,
        %{"sessionId" => session_id, "phoneNumber" => phone_number, "text" => text} = params
      ) do
    response = handle_ussd_request(params)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, response)
  end

  @doc """
  Handles USSD requests and returns the response text.
  This function is used both by the API endpoint and the emulator.
  """
  def handle_ussd_request(%{
        "sessionId" => session_id,
        "phoneNumber" => phone_number,
        "text" => text
      }) do
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

      :cancel_appointment ->
        handle_cancel_appointment(session, current_input)

      :select_child ->
        handle_select_child(session, current_input)

      :select_provider ->
        handle_select_provider(session, current_input)

      :select_date ->
        handle_select_date(session, current_input)

      :select_time ->
        handle_select_time(session, current_input)

      :confirm_booking ->
        handle_confirm_booking(session, current_input)

      :select_appointment_to_cancel ->
        handle_select_appointment_to_cancel(session, current_input)

      :confirm_cancellation ->
        handle_confirm_cancellation(session, current_input)

      _ ->
        "END An error occurred. Please restart your session."
    end

    # rescue
    #   e ->
    #     # Log error but provide user-friendly response
    #     IO.inspect(e, label: "USSD Error")
    #     "END An error occurred. Please try again later."
  end

  @doc """
  Initial greeting and verification of the user.
  """
  defp handle_initial_menu(session, phone_number) do
    user = Accounts.get_user_by_phone(phone_number)

    cond do
      user == nil ->
        "END Phone number not registered. Please register on our website or app first."

      user.role != "parent" ->
        "END This service is only available for parents. Please use the web or mobile app instead."

      true ->
        USSDSession.update_state(session, :main_menu, %{user_id: user.id, user_name: user.name})

        """
        CON Welcome to Under Five Health Check-Up
        1. Book Appointment
        2. Check Appointments
        3. Cancel Appointment
        4. Update Preferences
        """
    end
  end

  @doc """
  Main menu handler - routes to different features.
  """
  defp handle_main_menu(session, input) do
    case input do
      "1" ->
        USSDSession.update_state(session, :book_appointment)
        handle_book_appointment(session, "")

      "2" ->
        USSDSession.update_state(session, :check_appointments)
        handle_check_appointments(session, "")

      "3" ->
        USSDSession.update_state(session, :cancel_appointment)
        handle_cancel_appointment(session, "")

      "4" ->
        "END Feature coming soon. Please use the app or website to update your preferences."

      _ ->
        """
        CON Invalid option. Please select:
        1. Book Appointment
        2. Check Appointments
        3. Cancel Appointment
        4. Update Preferences
        """
    end
  end

  @doc """
  Book appointment entry point - transitions to child selection.
  """
  defp handle_book_appointment(session, _input) do
    # Transition to child selection
    USSDSession.update_state(session, :select_child)
    handle_select_child(session, "")
  end

  @doc """
  Displays and handles child selection for appointment booking.
  """
  defp handle_select_child(session, input) do
    user_id = session.data.user_id
    children = Accounts.list_children(user_id)

    if Enum.empty?(children) do
      "END You don't have any children registered. Please register a child on our website or app first."
    else
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
          updated_session =
            USSDSession.update_state(
              session,
              :select_provider,
              Map.put(session.data, :child_id, child.id)
            )

          handle_select_provider(updated_session, "")
        else
          "CON Invalid selection. Please try again:\n" <> handle_select_child(session, "")
        end
      end
    end
  rescue
    _ -> "CON Invalid input. Please enter a number:\n" <> handle_select_child(session, "")
  end

  @doc """
  Displays and handles provider selection for appointment booking.
  """
  defp handle_select_provider(session, input) do
    providers = Scheduling.list_providers()

    if Enum.empty?(providers) do
      "END No healthcare providers are currently available. Please try again later."
    else
      if input == "" do
        # Display providers list
        provider_options =
          providers
          |> Enum.with_index(1)
          |> Enum.map(fn {provider, index} ->
            "#{index}. #{provider.name} (#{format_specialization(provider.specialization)})"
          end)
          |> Enum.join("\n")

        "CON Select healthcare provider:\n#{provider_options}"
      else
        # Process selection
        index = String.to_integer(input) - 1

        if provider = Enum.at(providers, index) do
          updated_session =
            USSDSession.update_state(
              session,
              :select_date,
              Map.put(session.data, :provider_id, provider.id)
            )

          handle_select_date(updated_session, "")
        else
          "CON Invalid selection. Please try again:\n" <> handle_select_provider(session, "")
        end
      end
    end
  rescue
    _ -> "CON Invalid input. Please enter a number:\n" <> handle_select_provider(session, "")
  end

  @doc """
  Displays and handles date selection for appointment booking.
  """
  defp handle_select_date(session, input) do
    provider_id = session.data.provider_id

    # Get dates with available slots
    available_dates = get_dates_with_available_slots(provider_id, 14)

    if Enum.empty?(available_dates) do
      "END No available appointment dates for the selected provider in the next two weeks. Please try again later or select a different provider."
    else
      if input == "" do
        # Show available dates
        date_options =
          available_dates
          |> Enum.with_index(1)
          |> Enum.map(fn {date, index} -> "#{index}. #{format_date(date)}" end)
          |> Enum.join("\n")

        "CON Select appointment date:\n#{date_options}"
      else
        # Process date selection
        index = String.to_integer(input) - 1

        if date = Enum.at(available_dates, index) do
          updated_session =
            USSDSession.update_state(session, :select_time, Map.put(session.data, :date, date))

          handle_select_time(updated_session, "")
        else
          "CON Invalid selection. Please try again:\n" <> handle_select_date(session, "")
        end
      end
    end
  rescue
    _ -> "CON Invalid input. Please enter a number:\n" <> handle_select_date(session, "")
  end

  @doc """
  Displays and handles time slot selection for appointment booking.
  """
  defp handle_select_time(session, input) do
    provider_id = session.data.provider_id
    date = session.data.date

    # Get available slots from the scheduling system
    slots = get_available_time_slots(provider_id, date)

    if Enum.empty?(slots) do
      "END No available time slots for the selected date. Please try another date."
    else
      if input == "" do
        time_options =
          slots
          |> Enum.with_index(1)
          |> Enum.map(fn {slot, index} -> "#{index}. #{format_time(slot)}" end)
          |> Enum.join("\n")

        "CON Select appointment time:\n#{time_options}"
      else
        # Process time selection
        index = String.to_integer(input) - 1

        if time_slot = Enum.at(slots, index) do
          provider = Scheduling.get_provider!(session.data.provider_id)

          updated_session =
            USSDSession.update_state(
              session,
              :confirm_booking,
              Map.merge(session.data, %{
                time: time_slot,
                provider_name: provider.name
              })
            )

          handle_confirm_booking(updated_session, "")
        else
          "CON Invalid selection. Please try again:\n" <> handle_select_time(session, "")
        end
      end
    end
  rescue
    _ -> "CON Invalid input. Please enter a number:\n" <> handle_select_time(session, "")
  end

  @doc """
  Final confirmation screen for booking an appointment.
  """
  defp handle_confirm_booking(session, input) do
    if input == "" do
      child = Accounts.get_child!(session.data.child_id)
      date = session.data.date
      time = session.data.time
      provider_name = session.data.provider_name

      """
      CON Confirm appointment:
      Child: #{child.name}
      Date: #{format_date(date)}
      Time: #{format_time(time)}
      Provider: #{provider_name}

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
                 status: "scheduled",
                 notes: "Booked via USSD"
               }) do
            {:ok, appointment} ->
              USSDSession.end_session(session)
              "END Appointment booked successfully! You will receive a confirmation SMS shortly."

            {:error, changeset} ->
              error_message = format_changeset_errors(changeset)
              "END Failed to book appointment: #{error_message}. Please try again later."
          end

        "2" ->
          updated_session = USSDSession.update_state(session, :main_menu)
          handle_main_menu(updated_session, "")

        _ ->
          "CON Invalid option. Please select:\n1. Confirm\n2. Cancel"
      end
    end
  rescue
    _ -> "END An error occurred during booking. Please try again."
  end

  @doc """
  Lists upcoming appointments for the user's children.
  """
  defp handle_check_appointments(session, _input) do
    user_id = session.data.user_id
    children = Accounts.list_children(user_id)

    if Enum.empty?(children) do
      "END You don't have any children registered."
    else
      appointments =
        children
        |> Enum.flat_map(fn child ->
          Scheduling.upcoming_appointments(child.id)
        end)
        |> Enum.sort_by(fn appt -> {appt.scheduled_date, appt.scheduled_time} end)
        # Limit to 5 to avoid long messages
        |> Enum.take(5)

      if Enum.empty?(appointments) do
        "END You have no upcoming appointments."
      else
        appointment_list =
          appointments
          |> Enum.map(fn appt ->
            "#{appt.child.name} - #{format_date(appt.scheduled_date)} at #{format_time(appt.scheduled_time)} with #{appt.provider.name}"
          end)
          |> Enum.join("\n")

        "END Upcoming appointments:\n#{appointment_list}"
      end
    end
  end

  @doc """
  Starts the appointment cancellation flow.
  """
  defp handle_cancel_appointment(session, _input) do
    # Transition to selection of which appointment to cancel
    updated_session = USSDSession.update_state(session, :select_appointment_to_cancel)
    handle_select_appointment_to_cancel(updated_session, "")
  end

  @doc """
  Displays and handles appointment selection for cancellation.
  """
  defp handle_select_appointment_to_cancel(session, input) do
    user_id = session.data.user_id
    children = Accounts.list_children(user_id)

    if Enum.empty?(children) do
      "END You don't have any children registered."
    else
      # Get upcoming active appointments for all children
      appointments =
        children
        |> Enum.flat_map(fn child ->
          Scheduling.upcoming_appointments(child.id)
        end)
        |> Enum.sort_by(fn appt -> {appt.scheduled_date, appt.scheduled_time} end)

      if Enum.empty?(appointments) do
        "END You have no upcoming appointments to cancel."
      else
        if input == "" do
          # Display list of appointments that can be cancelled
          appointment_options =
            appointments
            |> Enum.with_index(1)
            |> Enum.map(fn {appt, index} ->
              "#{index}. #{appt.child.name} - #{format_date(appt.scheduled_date)} at #{format_time(appt.scheduled_time)}"
            end)
            |> Enum.join("\n")

          "CON Select appointment to cancel:\n#{appointment_options}\n99. Go back"
        else
          if input == "99" do
            # Go back to main menu
            updated_session = USSDSession.update_state(session, :main_menu)
            handle_main_menu(updated_session, "")
          else
            # Process appointment selection
            index = String.to_integer(input) - 1

            if appointment = Enum.at(appointments, index) do
              updated_session =
                USSDSession.update_state(
                  session,
                  :confirm_cancellation,
                  Map.put(session.data, :appointment_id, appointment.id)
                )

              handle_confirm_cancellation(updated_session, "")
            else
              "CON Invalid selection. Please try again:\n" <>
                handle_select_appointment_to_cancel(session, "")
            end
          end
        end
      end
    end
  rescue
    _ ->
      "CON Invalid input. Please enter a number:\n" <>
        handle_select_appointment_to_cancel(session, "")
  end

  @doc """
  Confirms appointment cancellation.
  """
  defp handle_confirm_cancellation(session, input) do
    appointment_id = session.data.appointment_id
    appointment = Scheduling.get_appointment!(appointment_id)

    if input == "" do
      """
      CON Confirm cancellation of:
      Child: #{appointment.child.name}
      Date: #{format_date(appointment.scheduled_date)}
      Time: #{format_time(appointment.scheduled_time)}
      Provider: #{appointment.provider.name}

      1. Yes, cancel appointment
      2. No, keep appointment
      """
    else
      case input do
        "1" ->
          # Cancel the appointment
          case Scheduling.update_appointment(appointment, %{status: "cancelled"}) do
            {:ok, _updated} ->
              USSDSession.end_session(session)

              "END Appointment cancelled successfully. You will receive a confirmation SMS shortly."

            {:error, _changeset} ->
              "END Failed to cancel appointment. Please try again later or contact support."
          end

        "2" ->
          updated_session = USSDSession.update_state(session, :main_menu)
          handle_main_menu(updated_session, "")

        _ ->
          "CON Invalid option. Please select:\n1. Yes, cancel appointment\n2. No, keep appointment"
      end
    end
  rescue
    _ -> "END An error occurred during cancellation. Please try again."
  end

  # ==========================
  # Helper functions
  # ==========================

  @doc """
  Gets dates that have available slots for a provider within the given days range.
  Returns only dates that have at least one available time slot.
  """
  defp get_dates_with_available_slots(provider_id, days_to_check) do
    today = Date.utc_today()

    1..days_to_check
    |> Enum.map(fn days -> Date.add(today, days) end)
    |> Enum.filter(fn date ->
      # Get the day of week
      day_of_week = Date.day_of_week(date)

      # Check if the provider has a schedule for this day
      day_of_week >= 1 && day_of_week <= 5
    end)
    |> Enum.filter(fn date ->
      # Check if there are available slots on this date
      slots = get_available_time_slots(provider_id, date)
      !Enum.empty?(slots)
    end)
  end

  @doc """
  Gets available time slots for a provider on a specific date.
  Filters out slots that are already booked.
  """
  defp get_available_time_slots(provider_id, date) do
    # Get the day of week and provider's schedule
    day_of_week = Date.day_of_week(date)
    schedule = Scheduling.get_provider_schedule(provider_id, day_of_week)

    case schedule do
      nil ->
        # Provider doesn't work on this day
        []

      schedule ->
        # Get all appointments for this provider and date
        existing_appointments = Scheduling.provider_appointments_for_date(provider_id, date)
        booked_times = Enum.map(existing_appointments, & &1.scheduled_time)

        # Generate all possible 30-minute slots between start and end time
        all_slots = generate_time_slots(schedule.start_time, schedule.end_time, 30)

        # Filter out booked slots
        Enum.filter(all_slots, fn slot -> !Enum.member?(booked_times, slot) end)
    end
  end

  @doc """
  Generates time slots of specified minutes between start and end time.
  """
  defp generate_time_slots(start_time, end_time, interval_minutes) do
    # Convert times to minutes since midnight for easier calculation
    start_minutes = time_to_minutes(start_time)
    end_minutes = time_to_minutes(end_time)

    # Generate slots
    start_minutes
    |> Stream.iterate(&(&1 + interval_minutes))
    |> Enum.take_while(&(&1 < end_minutes))
    |> Enum.map(&minutes_to_time/1)
  end

  @doc """
  Converts Time struct to minutes since midnight.
  """
  defp time_to_minutes(time) do
    time.hour * 60 + time.minute
  end

  @doc """
  Converts minutes since midnight to Time struct.
  """
  defp minutes_to_time(minutes) do
    hours = div(minutes, 60)
    mins = rem(minutes, 60)
    ~T[00:00:00] |> Time.add(hours * 3600 + mins * 60)
  end

  @doc """
  Formats a date for display in the USSD interface.
  """
  defp format_date(date) do
    Calendar.strftime(date, "%d %b %Y")
  end

  @doc """
  Formats a time for display in the USSD interface.
  """
  defp format_time(time) do
    Calendar.strftime(time, "%I:%M %p")
  end

  @doc """
  Formats provider specialization for display.
  """
  defp format_specialization(specialization) do
    case specialization do
      "pediatrician" -> "Pediatrician"
      "nurse" -> "Nurse"
      "general_practitioner" -> "General Practitioner"
      _ -> specialization
    end
  end

  @doc """
  Formats changeset errors into a readable string.
  """
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k} #{v}" end)
    |> Enum.join(", ")
  rescue
    _ -> "Invalid data provided"
  end
end
