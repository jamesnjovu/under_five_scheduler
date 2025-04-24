defmodule AppWeb.UserLoginLive do
  use AppWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-tr from-indigo-100 to-blue-50 py-12 px-4 sm:px-6 lg:px-8" id="login" phx-hook="AOSHook">
      <div class="max-w-md w-full bg-white rounded-xl shadow-xl overflow-hidden" data-aos="zoom-in">
        <div class="px-6 py-8 md:px-8">
          <div class="text-center">
            <div class="mx-auto h-12 w-12 flex items-center justify-center rounded-full bg-indigo-100">
              <svg class="h-8 w-8 text-indigo-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1121.75 8.25z" />
              </svg>
            </div>
            <h2 class="mt-6 text-3xl font-bold text-gray-900">
              Welcome back
            </h2>
            <p class="mt-2 text-sm text-gray-600">
              Sign in to access your account
            </p>
          </div>

          <div class="mt-10">
            <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
              <div class="space-y-6">
                <div>
                  <.input field={@form[:email]} type="email" label="Email" required placeholder="your@email.com"
                    class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm transition-colors duration-200" />
                </div>

                <div>
                  <.input field={@form[:password]} type="password" label="Password" required placeholder="••••••••"
                    class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm transition-colors duration-200" />
                </div>
              </div>

              <div class="flex items-center justify-between mt-6">
                <.input field={@form[:remember_me]} type="checkbox" label="Remember me" />
                <.link href={~p"/users/reset_password"} class="text-sm font-medium text-indigo-600 hover:text-indigo-500 transition-colors duration-200">
                  Forgot your password?
                </.link>
              </div>

              <div class="mt-6">
                <.button type="submit" phx-disable-with="Signing in..." class="w-full py-3 px-4 rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors duration-200">
                  Sign in
                </.button>
              </div>
            </.simple_form>
          </div>

          <div class="mt-6 text-center">
            <p class="text-sm text-gray-600">
              Don't have an account?
              <.link navigate={~p"/users/register"} class="font-medium text-indigo-600 hover:text-indigo-500 transition-colors duration-200">
                Sign up
              </.link>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
