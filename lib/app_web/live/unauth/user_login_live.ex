defmodule AppWeb.UserLoginLive do
  use AppWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-b from-indigo-100 to-white py-20 px-4 sm:px-6 lg:px-8" id="login" phx-hook="AOSHook">
      <div class="max-w-4xl mx-auto flex flex-col md:flex-row overflow-hidden rounded-2xl shadow-xl" data-aos="fade-up">
        <!-- Left side - login form -->
        <div class="w-full md:w-1/2 bg-white p-8 md:p-12">
          <div class="text-center md:text-left">
            <div class="mx-auto md:mx-0 inline-flex h-12 w-12 items-center justify-center rounded-full bg-indigo-100">
              <svg class="h-8 w-8 text-indigo-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1921.75 8.25z" />
              </svg>
            </div>
            <h2 class="mt-6 text-3xl font-bold text-gray-900">
              Welcome back
            </h2>
            <p class="mt-2 text-sm text-gray-600">
              Sign in to access your Under-Five Health Check-Up account
            </p>
          </div>

          <div class="mt-10">
            <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
              <div class="space-y-6">
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
                    field={@form[:password]}
                    type="password"
                    label="Password"
                    required
                    placeholder="••••••••"
                    class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm transition-colors duration-200"
                  />
                </div>
              </div>

              <div class="flex items-center justify-between mt-6">
                <.input field={@form[:remember_me]} type="checkbox" label="Remember me" />
                <.link href={~p"/users/reset_password"} class="text-sm font-medium text-indigo-600 hover:text-indigo-500 transition-colors duration-200">
                  Forgot your password?
                </.link>
              </div>

              <div class="mt-6">
                <.button
                  type="submit"
                  phx-disable-with="Signing in..."
                  class="w-full py-3 px-4 rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors duration-200 transform hover:scale-105"
                >
                  Sign in to your account
                </.button>
              </div>
            </.simple_form>
          </div>

          <div class="mt-6 text-center md:text-left">
            <p class="text-sm text-gray-600">
              Don't have an account?
              <.link navigate={~p"/users/register"} class="font-medium text-indigo-600 hover:text-indigo-500 transition-colors duration-200">
                Sign up
              </.link>
            </p>
          </div>
        </div>

        <!-- Right side - info about the platform -->
        <div class="w-full md:w-1/2 bg-indigo-700 text-white p-8 md:p-12 hidden md:block">
          <h3 class="text-2xl font-bold mb-6">Under-Five Health Check-Up</h3>

          <div class="mb-8">
            <h4 class="text-xl font-semibold mb-3">Why use our platform?</h4>
            <ul class="space-y-2">
              <li class="flex items-start">
                <svg class="h-5 w-5 mr-2 mt-0.5 text-indigo-300" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                </svg>
                <span>Easy appointment scheduling with healthcare providers</span>
              </li>
              <li class="flex items-start">
                <svg class="h-5 w-5 mr-2 mt-0.5 text-indigo-300" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                </svg>
                <span>Track your child's growth and healthcare visits</span>
              </li>
              <li class="flex items-start">
                <svg class="h-5 w-5 mr-2 mt-0.5 text-indigo-300" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                </svg>
                <span>Receive timely reminders for upcoming check-ups</span>
              </li>
              <li class="flex items-start">
                <svg class="h-5 w-5 mr-2 mt-0.5 text-indigo-300" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                </svg>
                <span>Access important health records anytime</span>
              </li>
            </ul>
          </div>

          <div class="mb-8">
            <h4 class="text-xl font-semibold mb-3">Getting Started</h4>
            <ol class="list-decimal list-inside space-y-2 ml-5">
              <li>Sign in to your account</li>
              <li>Add your children's information</li>
              <li>Book an appointment with a healthcare provider</li>
              <li>Receive confirmation and reminders</li>
            </ol>
          </div>

          <div class="mt-8 pt-6 border-t border-indigo-600">
            <p class="text-indigo-200">Need assistance? Contact support at <span class="font-medium text-white">support@underfive.example.com</span></p>
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