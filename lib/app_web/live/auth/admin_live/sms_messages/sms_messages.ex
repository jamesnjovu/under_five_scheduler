defmodule AppWeb.AdminLive.SMSMessages do
  use AppWeb, :live_view

  alias App.Repo
  alias App.Notifications.SMSMessage
  import Ecto.Query

  @messages_per_page 20

  def mount(_params, _session, socket) do
    {:ok,
      socket
      |> assign(:page, 1)
      |> assign(:filter, "all")
      |> assign_messages()
      |> assign(:loading, false)}
  end

  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    filter = params["filter"] || "all"

    {:noreply,
      socket
      |> assign(:page, page)
      |> assign(:filter, filter)
      |> assign_messages()}
  end

  def handle_event("filter_change", %{"filter" => filter}, socket) do
    {:noreply,
      push_patch(socket, to: ~p"/admin/sms_messages?filter=#{filter}&page=1")}
  end

  defp assign_messages(socket) do
    %{page: page, filter: filter} = socket.assigns

    # Base query
    query = from m in SMSMessage, order_by: [desc: m.inserted_at]

    # Apply filter
    query = case filter do
      "pending" -> from m in query, where: m.status == "pending"
      "sent" -> from m in query, where: m.status == "sent"
      "delivered" -> from m in query, where: m.status == "delivered"
      "failed" -> from m in query, where: m.status == "failed"
      _ -> query
    end

    # Paginate
    messages =
      query
      |> limit(@messages_per_page)
      |> offset(^((page - 1) * @messages_per_page))
      |> Repo.all()
      |> Repo.preload([:user, :appointment])

    # Get total count for pagination
    total_count = Repo.aggregate(query, :count, :id)
    total_pages = max(ceil(total_count / @messages_per_page), 1)

    socket
    |> assign(:messages, messages)
    |> assign(:total_pages, total_pages)
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold mb-6">SMS Messages</h1>

      <!-- Filters -->
      <div class="mb-6 flex items-center space-x-4">
        <span class="text-gray-700">Filter:</span>
        <select
          phx-change="filter_change"
          name="filter"
          class="border border-gray-300 rounded px-3 py-2"
        >
          <option value="all" selected={@filter == "all"}>All Messages</option>
          <option value="pending" selected={@filter == "pending"}>Pending</option>
          <option value="sent" selected={@filter == "sent"}>Sent</option>
          <option value="delivered" selected={@filter == "delivered"}>Delivered</option>
          <option value="failed" selected={@filter == "failed"}>Failed</option>
        </select>
      </div>

      <!-- Messages Table -->
      <div class="bg-white shadow overflow-hidden rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                ID
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Recipient
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Message
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Sent At
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for message <- @messages do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= message.id %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900"><%= message.phone_number %></div>
                  <%= if message.user do %>
                    <div class="text-xs text-gray-500"><%= message.user.name %></div>
                  <% end %>
                </td>
                <td class="px-6 py-4">
                  <div class="text-sm text-gray-900 max-w-xs truncate">
                    <%= message.message %>
                  </div>
                  <%= if message.appointment do %>
                    <div class="text-xs text-gray-500 mt-1">
                      Appointment #<%= message.appointment.id %>
                    </div>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={
                    "px-2 inline-flex text-xs leading-5 font-semibold rounded-full " <>
                    case message.status do
                      "pending" -> "bg-yellow-100 text-yellow-800"
                      "sent" -> "bg-blue-100 text-blue-800"
                      "delivered" -> "bg-green-100 text-green-800"
                      "failed" -> "bg-red-100 text-red-800"
                      _ -> "bg-gray-100 text-gray-800"
                    end
                  }>
                    <%= String.capitalize(message.status) %>
                  </span>
                  <%= if message.message_id do %>
                    <div class="text-xs text-gray-500 mt-1">
                      ID: <%= message.message_id %>
                    </div>
                  <% end %>
                  <%= if message.error_message do %>
                    <div class="text-xs text-red-500 mt-1">
                      <%= message.error_message %>
                    </div>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= format_datetime(message.inserted_at) %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <%= if message.message_id && message.status in ["pending", "sent"] do %>
                    <button
                      phx-click="check_status"
                      phx-value-id={message.id}
                      class={
                        "text-indigo-600 hover:text-indigo-900 " <>
                        if(@loading, do: "opacity-50 cursor-not-allowed", else: "")
                      }
                      disabled={@loading}
                    >
                      <%= if @loading do %>
                        Checking...
                      <% else %>
                        Check Status
                      <% end %>
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div class="flex justify-between items-center mt-6">
        <div>
          Showing page <%= @page %> of <%= @total_pages %>
        </div>
        <div class="flex space-x-2">
          <%= if @page > 1 do %>
            <.link
              patch={~p"/admin/sms_messages?page=#{@page - 1}&filter=#{@filter}"}
              class="px-3 py-1 border rounded bg-white hover:bg-gray-100"
            >
              Previous
            </.link>
          <% end %>

          <%= if @page < @total_pages do %>
            <.link
              patch={~p"/admin/sms_messages?page=#{@page + 1}&filter=#{@filter}"}
              class="px-3 py-1 border rounded bg-white hover:bg-gray-100"
            >
              Next
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_datetime(datetime) do
    datetime
    |> Calendar.strftime("%b %d, %Y %H:%M")
  end
end