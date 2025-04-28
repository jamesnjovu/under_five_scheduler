defmodule AppWeb.USSDEmulatorLive do
  use AppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:phone_number, "")
     |> assign(:session_id, "sess_#{random_string(10)}")
     |> assign(:ussd_code, "*123#")
     |> assign(:current_screen, "")
     |> assign(:input_text, "")
     |> assign(:history, [])
     |> assign(:loading, false)
     |> assign(:error, nil)}
  end

  def handle_event("update_details", %{"phone_number" => phone_number, "ussd_code" => ussd_code}, socket) do
    {
      :noreply,
      assign(socket, :phone_number, phone_number)
      |> assign(:ussd_code, ussd_code)
    }
  end

  def handle_event("initial_dial", _params, socket) do
    if is_empty?(socket.assigns.phone_number) do
      {:noreply, assign(socket, :error, "Please enter a phone number")}
    else
      handle_ussd_request(socket, "")
    end
  end

  def handle_event("submit_reply", %{"input_text" => input_text}, socket) do
    if is_empty?(input_text) do
      {:noreply, socket}
    else
      # Add user input to history
      updated_history = socket.assigns.history ++ [%{type: :user, text: input_text}]
      socket = assign(socket, :history, updated_history)

      handle_ussd_request(socket, input_text)
    end
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:session_id, "sess_#{random_string(10)}")
     |> assign(:current_screen, "")
     |> assign(:input_text, "")
     |> assign(:history, [])
     |> assign(:error, nil)}
  end

  defp handle_ussd_request(socket, input_text) do
    # Get the phone number and session ID
    phone_number = socket.assigns.phone_number
    session_id = socket.assigns.session_id

    # Construct the full USSD text based on history (mimic real USSD behavior)
    user_inputs =
      socket.assigns.history
      |> Enum.filter(fn item -> item.type == :user end)
      |> Enum.map(fn item -> item.text end)

    full_text =
      if input_text == "" do
        ""
      else
        Enum.join(user_inputs, "*") <>
          if(length(user_inputs) > 0, do: "*", else: "") <> input_text
      end

    # Show loading state
    socket =
      socket
      |> assign(:loading, true)
      |> assign(:input_text, "")

    # This would normally be an HTTP request, but we can directly call the controller function
    # since we're in the same application
    try do
      # Create a conn-like structure with the required parameters
      params = %{
        "sessionId" => session_id,
        "phoneNumber" => phone_number,
        "text" => full_text,
        "serviceCode" => String.replace(socket.assigns.ussd_code, "#", "")
      }

      # Call the USSD handler directly
      response_text = AppWeb.USSDController.handle_ussd_request(params)

      # Check if the response starts with "END" or "CON"
      is_end = String.starts_with?(response_text, "END")
      display_text = String.replace(response_text, ~r/^(END|CON)\s+/, "")

      # Update history with system response
      updated_history =
        socket.assigns.history ++ [%{type: :system, text: display_text, is_end: is_end}]

      {:noreply,
       socket
       |> assign(:loading, false)
       |> assign(:current_screen, display_text)
       |> assign(:history, updated_history)
       |> assign(:error, nil)}
    rescue
      e ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, "Error: #{inspect(e)}")}
    end
  end

  defp is_empty?(str), do: String.trim(str) == ""

  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64()
    |> binary_part(0, length)
  end
end
