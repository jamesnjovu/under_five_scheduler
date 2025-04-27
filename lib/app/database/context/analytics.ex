defmodule App.Analytics do
  @moduledoc """
  The Analytics context.
  """

  import Ecto.Query, warn: false
  alias App.Repo

  alias App.Analytics.AppointmentLog

  @doc """
  Returns the list of appointment_logs.

  ## Examples

      iex> list_appointment_logs()
      [%AppointmentLog{}, ...]

  """
  def list_appointment_logs do
    Repo.all(AppointmentLog)
  end

  @doc """
  Gets a single appointment_log.

  Raises `Ecto.NoResultsError` if the Appointment log does not exist.

  ## Examples

      iex> get_appointment_log!(123)
      %AppointmentLog{}

      iex> get_appointment_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_appointment_log!(id), do: Repo.get!(AppointmentLog, id)

  @doc """
  Creates a appointment_log.

  ## Examples

      iex> create_appointment_log(%{field: value})
      {:ok, %AppointmentLog{}}

      iex> create_appointment_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_appointment_log(attrs \\ %{}) do
    %AppointmentLog{}
    |> AppointmentLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a appointment_log.

  ## Examples

      iex> update_appointment_log(appointment_log, %{field: new_value})
      {:ok, %AppointmentLog{}}

      iex> update_appointment_log(appointment_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_appointment_log(%AppointmentLog{} = appointment_log, attrs) do
    appointment_log
    |> AppointmentLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a appointment_log.

  ## Examples

      iex> delete_appointment_log(appointment_log)
      {:ok, %AppointmentLog{}}

      iex> delete_appointment_log(appointment_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_appointment_log(%AppointmentLog{} = appointment_log) do
    Repo.delete(appointment_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking appointment_log changes.

  ## Examples

      iex> change_appointment_log(appointment_log)
      %Ecto.Changeset{data: %AppointmentLog{}}

  """
  def change_appointment_log(%AppointmentLog{} = appointment_log, attrs \\ %{}) do
    AppointmentLog.changeset(appointment_log, attrs)
  end
end
