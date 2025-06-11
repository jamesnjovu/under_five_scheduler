defmodule AppWeb.UserRegistrationLive do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-b from-indigo-100 py-12 px-4 sm:px-6 lg:px-8" id="registration" phx-hook="AOSHook">
      <div class="max-w-md w-full space-y-8" data-aos="fade-up">
        <div class="text-center">
          <div class="mx-auto h-16 w-16 flex items-center justify-center rounded-full bg-indigo-100">
            <svg
              class="h-10 w-10 text-indigo-600"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z"
              />
            </svg>
          </div>
          <h2 class="mt-6 text-3xl font-bold text-gray-900">
            Create your account
          </h2>
          <p class="mt-2 text-sm text-gray-600">
            Join us to manage your child's health check-ups
          </p>
        </div>

        <div class="bg-white py-8 px-6 shadow-lg rounded-xl">
          <.simple_form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/users/log_in?_action=registered"}
            method="post"
          >
            <.error :if={@check_errors}>
              Oops, something went wrong! Please check the errors below.
            </.error>

            <div class="space-y-5">
              <div>
                <.input
                  field={@form[:name]}
                  type="text"
                  label="Full Name"
                  required
                  placeholder="Enter your full name"
                  class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200"
                />
              </div>

              <div>
                <.input
                  field={@form[:email]}
                  type="email"
                  label="Email Address"
                  required
                  placeholder="your@email.com"
                  class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200"
                />
              </div>

              <div>
                <.input
                  field={@form[:phone]}
                  type="tel"
                  label="Phone Number"
                  required
                  placeholder="+260971234567"
                  class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200"
                />
                <p class="mt-1 text-xs text-gray-500">We'll use this for appointment reminders and password reset</p>
              </div>

              <div>
                <.input
                  field={@form[:password]}
                  type="password"
                  label="Password"
                  required
                  placeholder="Create a strong password"
                  class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200"
                />
                <p class="mt-1 text-xs text-gray-500">At least 8 characters</p>
              </div>

              <div>
                <.input
                  field={@form[:password_confirmation]}
                  type="password"
                  label="Confirm Password"
                  required
                  placeholder="Re-enter your password"
                  class="block w-full px-3 py-3 border border-gray-300 rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200"
                />
              </div>

              <!-- Hidden role field set to parent -->
              <.input
                field={@form[:role]}
                type="hidden"
                value="parent"
              />
            </div>

            <div class="mt-8">
              <.button
                type="submit"
                phx-disable-with="Creating account..."
                class="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-all duration-200 transform hover:scale-[1.02]"
              >
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
                </svg>
                Create Account
              </.button>
            </div>

            <div class="mt-6 text-center">
              <p class="text-sm text-gray-600">
                By creating an account, you agree to our
                <a href="#" class="font-medium text-indigo-600 hover:text-indigo-500">Terms of Service</a>
                and
                <a href="#" class="font-medium text-indigo-600 hover:text-indigo-500">Privacy Policy</a>
              </p>
            </div>
          </.simple_form>
        </div>

        <div class="text-center">
          <p class="text-sm text-gray-600">
            Already have an account?
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
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form1(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        Task.start(fn ->
          {:ok, _} =
            Accounts.deliver_user_confirmation_instructions(
              user,
              &url(~p"/users/confirm/#{&1}")
            )
        end)

        changeset = Accounts.change_user_registration(user)

        {:noreply,
          socket
          |> assign(trigger_submit: true)
          |> assign_form1(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
          socket
          |> assign(check_errors: true)
          |> assign_form1(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form1(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form1(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end