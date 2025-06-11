defmodule AppWeb.UserForgotPasswordLive do
  use AppWeb, :live_view

  alias App.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-b from-indigo-100 py-12 px-4 sm:px-6 lg:px-8" id="forgot-password" phx-hook="AOSHook">
      <div class="max-w-md w-full space-y-8" data-aos="fade-up">
        <div class="text-center">
          <div class="mx-auto h-16 w-16 flex items-center justify-center rounded-full bg-red-100">
            <svg class="h-10 w-10 text-red-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1121.75 8.25z" />
            </svg>
          </div>
          <h2 class="mt-6 text-3xl font-bold text-gray-900">
            Reset Your Password
          </h2>
          <p class="mt-2 text-sm text-gray-600">
            <%= if @step == :email do %>
              We'll send an OTP to your registered phone number
            <% else %>
              Enter the 6-digit code sent to your phone
            <% end %>
          </p>
        </div>

        <div class="bg-white py-8 px-6 shadow-lg rounded-xl">
          <%= if @step == :email do %>
            <!-- Step 1: Enter Phone Number -->
            <.simple_form for={@email_form} id="email_form" phx-submit="send_otp">
              <div class="space-y-5">
                <div>
                  <.input
                    field={@email_form[:email]}
                    type="email"
                    label="Email"
                    required
                    placeholder="your@email.com"
                    class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200"
                  />
                  <p class="mt-1 text-xs text-gray-500">Enter your registered phone number</p>
                </div>
              </div>

              <div class="mt-6">
                <.button
                  type="submit"
                  phx-disable-with="Sending OTP..."
                  class="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-all duration-200"
                >
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"></path>
                  </svg>
                  Send OTP
                </.button>
              </div>
            </.simple_form>

          <% else %>
            <!-- Step 2: Enter OTP and New Password -->
            <.simple_form for={@reset_form} id="reset_form" phx-submit="reset_password">
              <div class="space-y-5">
                <div class="text-center mb-4">
                  <p class="text-sm text-gray-600">
                    OTP sent to: <span class="font-medium text-gray-900"><%= mask_phone(@phone_number) %></span>
                  </p>
                  <%= if @resend_countdown > 0 do %>
                    <p class="text-xs text-gray-500 mt-1">
                      Resend available in <%= @resend_countdown %> seconds
                    </p>
                  <% else %>
                    <button
                      type="button"
                      phx-click="resend_otp"
                      class="text-xs text-indigo-600 hover:text-indigo-500 mt-1"
                    >
                      Resend OTP
                    </button>
                  <% end %>
                </div>

                <div>
                  <.input
                    field={@reset_form[:otp_code]}
                    type="text"
                    label="OTP Code"
                    required
                    placeholder="Enter 6-digit code"
                    maxlength="6"
                    class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200 text-center text-2xl tracking-widest"
                  />
                </div>

                <div>
                  <.input
                    field={@reset_form[:new_password]}
                    type="password"
                    label="New Password"
                    required
                    placeholder="Enter new password"
                    class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200"
                  />
                  <p class="mt-1 text-xs text-gray-500">At least 8 characters</p>
                </div>

                <div>
                  <.input
                    field={@reset_form[:confirm_password]}
                    type="password"
                    label="Confirm New Password"
                    required
                    placeholder="Re-enter new password"
                    class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200"
                  />
                </div>
              </div>

              <div class="mt-6">
                <.button
                  type="submit"
                  phx-disable-with="Resetting password..."
                  class="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-all duration-200"
                >
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                  Reset Password
                </.button>
              </div>

              <div class="mt-4 text-center">
                <button
                  type="button"
                  phx-click="back_to_phone"
                  class="text-sm text-gray-600 hover:text-gray-500"
                >
                  ← Back to phone number
                </button>
              </div>
            </.simple_form>
          <% end %>
        </div>

        <div class="text-center">
          <p class="text-sm text-gray-600">
            Remember your password?
            <.link
              navigate={~p"/users/log_in"}
              class="font-medium text-indigo-600 hover:text-indigo-500 transition-colors duration-200"
            >
              Sign in here
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:step, :email)
      |> assign(:phone_number, "")
      |> assign(:resend_countdown, 0)
      |> assign(:email_form, to_form(%{}, as: "email"))
      |> assign(:reset_form, to_form(%{}, as: "reset"))

    {:ok, socket}
  end

  def handle_event("send_otp", %{"email" => %{"email" => email}}, socket) do
    Task.start(fn -> Accounts.initiate_password_reset_by_email(email) end)

    # Start countdown timer
    send(self(), :countdown_tick)

    {
      :noreply,
      socket
      |> assign(:step, :otp)
      |> assign(:email, email)
      |> assign(:resend_countdown, 60)
      |> put_flash(:info, "OTP sent to your phone number linked to email")
    }
  end

  def handle_event("reset_password", %{"reset" => params}, socket) do
    %{"otp_code" => otp_code, "new_password" => new_password, "confirm_password" => confirm_password} = params

    # Validate password confirmation
    if new_password != confirm_password do
      {:noreply, put_flash(socket, :error, "Passwords do not match")}
    else
      case Accounts.reset_password_with_otp(socket.assigns.email, otp_code, new_password) do
        {:ok, user} ->
          # Generate session token and redirect to login
          token = Accounts.generate_user_session_token(user)

          {:noreply,
            socket
            |> put_flash(:info, "Password reset successfully. You are now logged in.")
            |> redirect(to: ~p"/users/log_in?user_return_to=/")}

        {:error, :invalid_otp} ->
          {:noreply,
            socket
            |> put_flash(:error, "Invalid OTP code. Please try again.")}

        {:error, :expired} ->
          {:noreply,
            socket
            |> put_flash(:error, "OTP has expired. Please request a new one.")
            |> assign(:step, :email)}

        {:error, :already_used} ->
          {:noreply,
            socket
            |> put_flash(:error, "OTP has already been used. Please request a new one.")
            |> assign(:step, :email)}

        {:error, :max_attempts} ->
          {:noreply,
            socket
            |> put_flash(:error, "Too many incorrect attempts. Please request a new OTP.")
            |> assign(:step, :email)}

        {:error, changeset} ->
          errors =
            changeset.errors
            |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
            |> Enum.join(", ")

          {:noreply,
            socket
            |> put_flash(:error, "Password reset failed: #{errors}")}
      end
    end
  end

  def handle_event("resend_otp", _params, socket) do
    if socket.assigns.resend_countdown == 0 do
      case Accounts.resend_password_reset_otp(socket.assigns.phone_number) do
        {:ok, :otp_sent} ->
          send(self(), :countdown_tick)

          {:noreply,
            socket
            |> assign(:resend_countdown, 60)
            |> put_flash(:info, "New OTP sent to your phone")}

        {:error, :too_soon} ->
          {:noreply,
            socket
            |> put_flash(:error, "Please wait before requesting another OTP")}

        {:error, _} ->
          {:noreply,
            socket
            |> put_flash(:error, "Failed to send OTP. Please try again.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("back_to_phone", _params, socket) do
    {:noreply,
      socket
      |> assign(:step, :email)
      |> assign(:phone_number, "")
      |> assign(:resend_countdown, 0)}
  end

  def handle_info(:countdown_tick, socket) do
    if socket.assigns.resend_countdown > 0 do
      Process.send_after(self(), :countdown_tick, 1000)
      {:noreply, assign(socket, :resend_countdown, socket.assigns.resend_countdown - 1)}
    else
      {:noreply, socket}
    end
  end

  defp mask_phone(phone_number) do
    if String.length(phone_number) > 6 do
      prefix = String.slice(phone_number, 0, 3)
      suffix = String.slice(phone_number, -4, 4)
      "#{prefix}****#{suffix}"
    else
      phone_number
    end
  end
end