defmodule AppWeb.PWAController do
  use AppWeb, :controller

  @doc """
  Serves the Web App Manifest file
  """
  def manifest(conn, _params) do
    conn
    |> put_resp_content_type("application/manifest+json")
    |> send_file(200, Application.app_dir(:app, "priv/static/manifest.json"))
  end

  @doc """
  Serves the service worker script
  """
  def service_worker(conn, _params) do
    conn
    |> put_resp_content_type("application/javascript")
    |> send_file(200, Application.app_dir(:app, "priv/static/service-worker.js"))
  end

  @doc """
  Serves the offline page
  """
  def offline(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:app, "priv/static/offline.html"))
  end

  @doc """
  Serves the service worker registration script.
  Typically this would be included directly in your JavaScript bundle,
  but this endpoint allows it to be loaded separately if needed.
  """
  def service_worker_registration(conn, _params) do
    conn
    |> put_resp_content_type("application/javascript")
    |> send_file(200, Application.app_dir(:app, "priv/static/service-worker-registration.js"))
  end

  @doc """
  Handles Web Push subscription submission from the client
  """
  def subscribe_push(conn, %{"subscription" => _subscription}) do
    # Here you would save the push subscription to your database
    # associated with the current user
    # App.Notifications.save_push_subscription(conn.assigns.current_user, subscription)

    json(conn, %{success: true, message: "Push subscription saved"})
  end

  @doc """
  Checks if the application is online by returning a simple response.
  Client-side JavaScript can call this to determine connectivity.
  """
  def connectivity_check(conn, _params) do
    json(conn, %{online: true, timestamp: DateTime.utc_now()})
  end
end
