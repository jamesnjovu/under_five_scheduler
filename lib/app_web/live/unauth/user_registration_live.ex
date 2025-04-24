defmodule AppWeb.UserRegistrationLive do
  use AppWeb, :live_view

  alias App.Accounts
  alias App.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-tr from-indigo-100 to-blue-50 py-12 px-4 sm:px-6 lg:px-8" id="registration" phx-hook="AOSHook">
      <div class="max-w-md w-full bg-white rounded-xl shadow-xl overflow-hidden" data-aos="zoom-in">
        <div class="px-6 py-8 md:px-8">
          <div class="text-center">
            <div class="mx-auto h-12 w-12 flex items-center justify-center rounded-full bg-indigo-100">
              <svg
                class="h-8 w-8 text-indigo-600"
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

          <div class="mt-10">
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

              <div class="space-y-6">
                <div>
                  <.input
                    field={@form[:name]}
                    type="text"
                    label="Full Name"
                    required
                    placeholder="John Doe"
                    class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm transition-colors duration-200"
                  />
                </div>

                <div>
                  <.input
                    field={@form[:email]}
                    type="email"
                    label="Email"
                    required
                    placeholder="your@email.com"
                    class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm transition-colors duration-200"
                  />
                </div>

                <div>
                  <.input
                    field={@form[:phone]}
                    type="tel"
                    label="Phone Number"
                    required
                    placeholder="+1234567890"
                    class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm transition-colors duration-200"
                  />
                </div>

                <div>
                  <.input
                    field={@form[:password]}
                    type="password"
                    label="Password"
                    required
                    placeholder="••••••••"
                    class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm transition-colors duration-200"
                  />
                </div>

                <div>
                  <.input
                    field={@form[:password_confirmation]}
                    type="password"
                    label="Confirm Password"
                    required
                    placeholder="••••••••"
                    class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm transition-colors duration-200"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">I am a:</label>
                  <div class="mt-2 flex space-x-4">
                    <div class="flex items-center">
                      <input
                        id="role-parent"
                        name="user[role]"
                        type="radio"
                        value="parent"
                        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
                        checked
                      />
                      <label for="role-parent" class="ml-2 block text-sm text-gray-700">Parent</label>
                    </div>
                    <div class="flex items-center">
                      <input
                        id="role-provider"
                        name="user[role]"
                        type="radio"
                        value="provider"
                        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
                      />
                      <label for="role-provider" class="ml-2 block text-sm text-gray-700">
                        Healthcare Provider
                      </label>
                    </div>
                  </div>
                </div>
              </div>
              <div class="mt-8">
                <.button
                  type="submit"
                  phx-disable-with="Creating account..."
                  class="w-full py-3 px-4 rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors duration-200 transform hover:scale-105"
                >
                  Create account
                </.button>
              </div>
            </.simple_form>
          </div>
          <div class="mt-6 text-center">
            <p class="text-sm text-gray-600">
              Already have an account?
              <.link
                navigate={~p"/users/log_in"}
                class="font-medium text-indigo-600 hover:text-indigo-500 transition-colors duration-200"
              >
                Sign in
              </.link>
            </p>
          </div>
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
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    IO.inspect(changeset)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
