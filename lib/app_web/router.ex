defmodule AppWeb.Router do
  use AppWeb, :router

  import AppWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :sidebar_layout do
    plug(:put_root_layout, html: {AppWeb.Layouts, :sidebar})
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AppWeb do
    pipe_through :api

    post "/ussd", USSDController, :handle
  end

  ## Authentication routes
  scope "/", AppWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{AppWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      get "/", PageController, :home
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  # Authenticated routes
  # Admin routes
  scope "/admin", AppWeb.AdminLive do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_admin_user,
      on_mount: [
        {AppWeb.UserAuth, :ensure_authenticated},
        {AppWeb.UserAuth, :ensure_admin}
      ] do
      live "/dashboard", Dashboard, :index
      live "/providers", Providers, :index
      live "/parents", Parents, :index
      live "/appointments", Appointments, :index
      live "/reports", Reports, :index
      live "/settings", Settings, :index
      live "/sms_messages", SMSMessages, :index
    end
  end

  scope "/provider", AppWeb.ProviderLive do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_provider_user,
      on_mount: [
        {AppWeb.UserAuth, :ensure_authenticated},
        {AppWeb.UserAuth, :ensure_provider}
      ] do
      live "/dashboard", Dashboard, :index
      live "/patients", Patients, :index
      live "/schedule", Schedule, :index
      live "/appointments", Appointments, :index
      live "/reports", Reports, :index
      live "/patients/:id/health", ChildHealth, :index
      live "/settings", Settings, :index
      live "/appointments/:appointment_id/health", ChildHealthEnhanced, :index
      live "/health_dashboard", HealthDashboard, :index
    end
  end

  scope "/", AppWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{AppWeb.UserAuth, :ensure_authenticated}] do
      # Dashboard
      live "/dashboard", DashboardLive.Index, :index

      # Children management
      live "/children", ChildLive.Index, :index
      live "/children/new", ChildLive.Index, :new
      live "/children/:id/edit", ChildLive.Index, :edit
      live "/children/:id", ChildLive.Show, :show

      # Appointments
      live "/appointments", AppointmentLive.Index, :index
      live "/appointments/new", AppointmentLive.New, :new
      live "/appointments/:id", AppointmentLive.Show, :show
      live "/appointments/:id/reschedule", AppointmentLive.Reschedule, :edit

      # Provider routes (for healthcare staff)

      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", AppWeb do
    pipe_through [:browser]

    # PWA specific routes
    get "/manifest.json", PWAController, :manifest
    get "/service-worker.js", PWAController, :service_worker
    get "/service-worker-registration.js", PWAController, :service_worker_registration
    get "/offline.html", PWAController, :offline

    # Connectivity verification
    get "/connectivity-check", PWAController, :connectivity_check

    # Web Push notifications
    post "/push/subscribe", PWAController, :subscribe_push

    live "/ussd_emulator", USSDEmulatorLive, :index

    match :*, "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{AppWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
