# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :app,
  ecto_repos: [App.Repo],
  generators: [timestamp_type: :utc_datetime]

  # Configures Oban for background jobs
config :app, Oban,
   repo: App.Repo,
   plugins: [
     {Oban.Plugins.Pruner, []},
     {Oban.Plugins.Cron,
       crontab: [
         {"0 0 * * *", App.Workers.ReminderSchedulerWorker},
         # Daily health alert generation at 6 AM
         {"0 6 * * *", App.Workers.HealthAlertGeneratorWorker},
         # Weekly follow-up reminders on Mondays at 9 AM
         {"0 9 * * 1", App.Workers.FollowUpReminderWorker},
         # Every hour
         {"0 */1 * * *", App.Workers.OTPCleanupWorker},
         # Daily immunization reminders at 10 AM
         {"0 10 * * *", App.Workers.ImmunizationReminderWorker, args: %{reminder_type: "upcoming"}},
         # Weekly overdue immunization alerts on Fridays at 2 PM
         {"0 14 * * 5", App.Workers.ImmunizationReminderWorker, args: %{reminder_type: "overdue"}}
     ]}
   ],
   queues: [
     default: 10,
     notifications: 20,
     health_monitoring: 5,
     analytics: 3
   ]

config :app, :probase_sms,
   username: System.get_env("SMS_USERNAME") || "Prince Mambwe",  # Replace with your test credentials
   password: System.get_env("SMS_PASSWORD") || "avcyYJwUqnyJfdfjeJcf",
   sender_id: System.get_env("SMS_SENDER") || "U5Health" # Default sender ID

# Configures the endpoint
config :app, AppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AppWeb.ErrorHTML, json: AppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: App.PubSub,
  live_view: [signing_salt: "uxL3/K8A"],
  check_origin: [
    "//66.42.87.179:4001",
    "//under5scheduler.sms.probasegroup.com",
  ]

  # Configure timezone handling
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase


# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :app, App.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  app: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  app: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
