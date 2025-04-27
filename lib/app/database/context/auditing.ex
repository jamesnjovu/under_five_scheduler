defmodule App.Administration.Auditing do
  alias App.Repo
  alias App.Administration.AuditLog
  import Ecto.Query, warn: false

  def log_action(params) do
    %AuditLog{}
    |> AuditLog.changeset(params)
    |> Repo.insert()
  end

  def list_audit_logs(opts \\ []) do
    AuditLog
    |> apply_filters(opts)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:user_id, user_id}, query ->
        where(query, [a], a.user_id == ^user_id)

      {:action, action}, query ->
        where(query, [a], a.action == ^action)

      {:entity_type, type}, query ->
        where(query, [a], a.entity_type == ^type)

      {:date_range, {start_date, end_date}}, query ->
        where(query, [a], a.inserted_at >= ^start_date and a.inserted_at <= ^end_date)

      _, query ->
        query
    end)
  end
end
