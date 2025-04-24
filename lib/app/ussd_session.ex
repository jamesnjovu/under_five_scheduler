defmodule App.USSDSession do
  @moduledoc """
  Manages USSD session state using GenServer.
  """

  use GenServer

  @session_timeout :timer.minutes(5)

  defstruct [:session_id, :phone_number, :state, :data, :last_activity]

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_or_create(session_id, phone_number) do
    GenServer.call(__MODULE__, {:get_or_create, session_id, phone_number})
  end

  def update_state(session, new_state, new_data \\ nil) do
    GenServer.call(__MODULE__, {:update_state, session.session_id, new_state, new_data})
  end

  def end_session(session) do
    GenServer.cast(__MODULE__, {:end_session, session.session_id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # Start cleanup timer
    :timer.send_interval(@session_timeout, :cleanup)
    {:ok, %{sessions: %{}}}
  end

  @impl true
  def handle_call({:get_or_create, session_id, phone_number}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        new_session = %__MODULE__{
          session_id: session_id,
          phone_number: phone_number,
          state: :initial,
          data: %{},
          last_activity: DateTime.utc_now()
        }
        {:reply, new_session, %{state | sessions: Map.put(state.sessions, session_id, new_session)}}

      existing_session ->
        updated_session = %{existing_session | last_activity: DateTime.utc_now()}
        {:reply, updated_session, %{state | sessions: Map.put(state.sessions, session_id, updated_session)}}
    end
  end

  @impl true
  def handle_call({:update_state, session_id, new_state, new_data}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        updated_session = %{session |
          state: new_state,
          data: new_data || session.data,
          last_activity: DateTime.utc_now()
        }
        {:reply, updated_session, %{state | sessions: Map.put(state.sessions, session_id, updated_session)}}
    end
  end

  @impl true
  def handle_cast({:end_session, session_id}, state) do
    {:noreply, %{state | sessions: Map.delete(state.sessions, session_id)}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now()

    cleaned_sessions = state.sessions
    |> Enum.filter(fn {_id, session} ->
      DateTime.diff(now, session.last_activity, :millisecond) < @session_timeout
    end)
    |> Enum.into(%{})

    {:noreply, %{state | sessions: cleaned_sessions}}
  end
end
