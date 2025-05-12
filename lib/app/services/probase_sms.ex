defmodule App.Services.ProbaseSMS do
  @moduledoc """
  Client for interacting with the Probase SMS API.
  See: https://probasesms.com/api/docs?section=json_api
  """

  require Logger
  alias App.Config

  @base_url "https://probasesms.com/api/json"

  @doc """
  Sends an SMS message using the Probase SMS API.

  ## Parameters

    * `phone_number` - The recipient's phone number
    * `message` - The message content
    * `opts` - Additional options (sender_id, etc.)

  ## Returns

    * `{:ok, response}` - On successful API call
    * `{:error, reason}` - On failed API call
  """
  def send_sms(phone_number, message, opts \\ []) do
    # Format phone number (ensure it has country code)
    formatted_phone = format_phone_number(phone_number)

    # Prepare the request body
    sender_id = Keyword.get(opts, :sender_id, Config.get_sms_sender_id())

    body = %{
      "recipient" => [formatted_phone],
      "message" => message,
      "senderid" => sender_id,
      "username" => Config.get_probase_username(),
      "password" => Config.get_probase_password()
    }

    # Make the API call
    case post_json("/multi/res/bulk/sms", body) do
      {:ok, %{status: 200, body: %{"response" => response}}} when is_list(response) ->
        # Successful response with message IDs
        result = Enum.map(response, fn item ->
          %{
            message_id: item["messageid"],
            mobile: item["mobile"],
            status: item["messagestatus"]
          }
        end)
        {:ok, result}

      {:ok, %{status: 200, body: %{"response" => error}}} when is_binary(error) ->
        # Error response like "INVALID_REQUEST" or "INTERNAL_ERROR"
        Logger.error("Probase SMS API error: #{error}")
        {:error, error}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Probase SMS API unexpected response: status=#{status}, body=#{inspect(body)}")
        {:error, "Unexpected response: #{inspect(body)}"}

      {:error, reason} ->
        Logger.error("Probase SMS API request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helpers
  defp post_json(endpoint, body) do
    headers = [{"Content-Type", "application/json"}]

    # Use Finch for HTTP requests
    Finch.build(:post, @base_url <> endpoint, headers, Jason.encode!(body))
    |> Finch.request(App.Finch)
    |> case do
         {:ok, %Finch.Response{} = response} ->
           parsed_body =
             case Jason.decode(response.body) do
               {:ok, decoded} -> decoded
               {:error, _} -> response.body
             end

           {:ok, %{status: response.status, body: parsed_body}}

         error ->
           error
       end
  end

  defp handle_response(%{"status" => "OK"} = response) do
    {:ok, response}
  end

  defp handle_response(%{"status" => "FAIL", "error" => error}) do
    {:error, error}
  end

  defp handle_response(response) do
    # For any other unexpected response format
    {:error, "Unexpected response: #{inspect(response)}"}
  end

  defp format_phone_number("+" <> _ = phone), do: String.replace(phone, "+", "")
  defp format_phone_number(phone) when binary_part(phone, 0, 1) == "0" do
    # Replace leading 0 with Zambia country code (assuming Zambia since the app was deployed in Lusaka)
    "26" <> binary_part(phone, 1, byte_size(phone) - 1)
  end
  defp format_phone_number(phone), do: phone
end