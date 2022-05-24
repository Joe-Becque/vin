defmodule Vin.DriverRegistry do
  use GenServer
  require Logger
  alias Vin.DriverRegistry
  alias Vin.DriverSrv
  alias Vin.Driver
  alias Vin.Car

  @moduledoc """
  A registry of existing driver servers.
  Stores the pids of th driver servers against the driver's id in the :driver_registry ets table.
  Provides an API for actions on driver data in order to make calls to the driver servers.
  """

  @driver_registry_table :driver_registry # ets table - {id, pid} keyed on the driver id

  defstruct [
    next_driver_id: 0, # an ever increasing id to determine the next new driver's unique id
    driver_refs: %{}   # map of process references to each driver's id
  ]

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Gen Server API
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  @spec start_link(any) :: {:ok, pid}
  def start_link(args) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec create_driver(String.t) :: %Driver{}
  def create_driver(name) do
    GenServer.call(__MODULE__, {:create_driver, name})
  end

  @spec delete_driver(binary) :: {:ok, integer} | {:error, String.t}
  def delete_driver(driver_id) do
    GenServer.call(__MODULE__, {:delete_driver, driver_id})
  end

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## API that does not use gen server process
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  @spec list_all_drivers :: {:ok, list(%Driver{})}
  def list_all_drivers() do
    drivers = :ets.foldl(fn({_id, driver_pid}, acc) -> [ DriverSrv.get_driver(driver_pid) | acc] end, [], @driver_registry_table)
    {:ok, drivers}
  end

  @spec get_driver(String.t) :: {:ok, %Driver{}} | {:error, String.t}
  def get_driver(driver_id) do
    case lookup_driver_id(driver_id) do
      {:ok, {_driver_id, driver_pid}} ->
        driver = DriverSrv.get_driver(driver_pid)
        {:ok, driver}
      {:error, _reason} = error ->
        error
    end
  end

  @spec create_car(String.t, String.t) :: {:ok, %Car{}} | {:error, String.t}
  def create_car(driver_id, vin) do
    case lookup_driver_id(driver_id) do
      {:ok, {_driver_id, driver_pid}} ->
        DriverSrv.create_car(driver_pid, vin)
      {:error, _reason} = error ->
        error
    end
  end

  @spec delete_car(String.t, String.t) ::  {:ok, %Driver{}} | {:error, String.t}
  def delete_car(driver_id, car_id) do
    case lookup_driver_id(driver_id) do
      {:ok, {_driver_id, driver_pid}} ->
        DriverSrv.delete_car(driver_pid, car_id)
      {:error, _reason} = error ->
        error
    end
  end

  @spec get_cars(integer()) :: {:ok, list(%Vin.Car{})}
  def get_cars(driver_id_int) do
    case :ets.lookup(@driver_registry_table, driver_id_int) do
      [{_driver_id, driver_pid}] ->
        {:ok, DriverSrv.get_cars(driver_pid)}
      [] ->
        Logger.info("request for driver id not found: #{inspect driver_id_int}")
        {:ok, []}
    end
  end

  @spec set_charge_status(String.t, String.t, String.t) ::  {:ok, %Car{}} | {:error, String.t}
  def set_charge_status(driver_id, car_id, charge_status) do
    case lookup_driver_id(driver_id) do
      {:ok, {_driver_id, driver_pid}} ->
        DriverSrv.set_charge_status(driver_pid, car_id, charge_status)
      {:error, _reason} = error ->
        error
    end
  end

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Gen Server Call Backs
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  @impl true
  def init(_args) do
    Logger.info("starting driver registry")
    @driver_registry_table = :ets.new(@driver_registry_table, [:named_table, {:read_concurrency, true}, :public])
    {:ok, %DriverRegistry{}}
  end

  @impl true
  def handle_call({:create_driver, name}, _from, driver_registry) do
    {new_driver, new_state} = handle_create_driver(name, driver_registry)
    {:reply, new_driver, new_state}
  end

  def handle_call({:delete_driver, driver_id}, _from, state) do
    resp = handle_delete_driver(driver_id)
    {:reply, resp, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, {:shutdown, delete_driver: driver_id}}, %DriverRegistry{driver_refs: driver_refs} = state) do
    {_, remaining_refs} = Map.pop(driver_refs, ref)
    Logger.info("driver with id: #{driver_id} and pid: #{inspect pid} has been stopped")
    {:noreply, %DriverRegistry{state | driver_refs: remaining_refs}}
  end
  def handle_info({:DOWN, ref, :process, pid, reason}, %DriverRegistry{driver_refs: driver_refs} = state) do
    {driver_id, remaining_refs} = Map.pop(driver_refs, ref)
    :ets.take(@driver_registry_table, driver_id)
    Logger.error("driver #{driver_id} process #{inspect pid} died with reason: #{inspect reason}")
    {:noreply, %DriverRegistry{state | driver_refs: remaining_refs}}
  end

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Internal Functions
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  @spec handle_create_driver(String.t, %DriverRegistry{}) :: {%Driver{}, %DriverRegistry{}}
  def handle_create_driver(name, %DriverRegistry{next_driver_id: new_id, driver_refs: driver_refs} = state) do
    new_driver = %Driver{id: new_id, name: name}

    # create a new process for this new driver and monitor it so we can remove it from the registry if it dies
    {:ok, driver_pid} = DynamicSupervisor.start_child(Vin.DynamicDriversSupervisor, {DriverSrv, new_driver})
    driver_ref = Process.monitor(driver_pid)
    driver_refs = Map.put(driver_refs, driver_ref, new_id)
    :ets.insert(@driver_registry_table, {new_id, driver_pid})

    {new_driver, %DriverRegistry{state | next_driver_id: new_id + 1, driver_refs: driver_refs}}
  end

  @spec handle_delete_driver(String.t) :: {:ok, String.t} | {:error, String.t}
  def handle_delete_driver(driver_id) do
    case lookup_driver_id(driver_id) do
      {:ok, {driver_id, driver_pid}} ->
        :ets.take(@driver_registry_table, driver_id)
        # Remove the driver from the ets table here to prevent race conditions with other requests
        # But don't remove the ref from the ref map until the down message is recieved in case it crashes for another reason
        DriverSrv.delete_driver(driver_pid, delete_driver: driver_id)
        {:ok, driver_id}
      {:error, _reason} = error ->
        error
    end
  end

  @spec lookup_driver_id(String.t) :: {:error, String.t} | {:ok, tuple}
  def lookup_driver_id(driver_id) do
    case Integer.parse(driver_id) do
      {driver_id_int, ""} ->
        case :ets.lookup(@driver_registry_table, driver_id_int) do
          [driver_data] ->
            {:ok, driver_data}
          [] ->
            {:error, "driver id not found"}
        end
      _else ->
        {:error, "invalid driver id"}
    end
  end

end
