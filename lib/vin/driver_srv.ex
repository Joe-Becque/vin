defmodule Vin.DriverSrv do
  use GenServer, restart: :temporary
  require Logger
  alias Vin.Car
  alias Vin.DriverSrv
  alias Vin.Driver

  @moduledoc """
  Gen server process holding state for an individual driver.
  Dynamically spawned and supervised by Vin.DynamicDriversSupervisor
  """

  @enforce_keys :driver
  defstruct [
    :driver,         # Vin.Driver struct holding driver info
    next_car_id: 0,  # an ever increasing id to determine the next new car's unique id
    cars: %{}        # map of car ids to their associated car struct
  ]

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Gen Server API
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  def start_link(%Driver{} = driver) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, driver)
  end

  @spec create_car(pid, String.t) :: {:ok, %Car{}} | {:error, String.t}
  def create_car(driver_pid, vin) do
    GenServer.call(driver_pid, {:create_car, vin})
  end

  @spec delete_car(pid, String.t) :: {:ok, %Driver{}} | {:error, String.t}
  def delete_car(driver_pid, car_id) do
    GenServer.call(driver_pid, {:delete_car, car_id})
  end

  @spec get_cars(pid) :: list(%Car{})
  def get_cars(driver_pid) do
    GenServer.call(driver_pid, {:get_cars})
  end

  @spec get_driver(pid) :: %Driver{}
  def get_driver(driver_pid) do
    GenServer.call(driver_pid, {:get_driver})
  end

  @spec delete_driver(pid, term) :: :ok
  def delete_driver(driver_pid, reason) do
    GenServer.stop(driver_pid, {:shutdown, reason})
    Logger.info("stopped #{inspect driver_pid} with reason: #{inspect reason}")
  end

  @spec set_charge_status(pid, String.t, String.t) :: {:ok, %Car{}} | {:error, String.t}
  def set_charge_status(driver_pid, car_id, charge_status) do
    GenServer.call(driver_pid, {:set_charge_status, car_id, charge_status})
  end

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Gen Server Call Backs
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  @impl true
  def init(%Driver{} = driver) do
    Logger.info("starting gen server for new driver: #{inspect driver}")
    {:ok, %DriverSrv{driver: driver}}
  end

  @impl true
  def terminate(reason, %DriverSrv{} = state) do
    Logger.info("driver process #{inspect self()} has been terminated with reason #{inspect reason} and state #{inspect state}")
    state
  end

  @impl true
  def handle_call({:create_car, vin}, _from, %DriverSrv{} = state) do
    {response, new_state} = handle_create_car(vin, state)
    {:reply, response, new_state}
  end

  def handle_call({:delete_car, car_id}, _from, %DriverSrv{} = state) do
    {response, new_state} = handle_delete_car(car_id, state)
    {:reply, response, new_state}
  end

  def handle_call({:get_cars}, _from, %DriverSrv{cars: cars} = state) do
    {:reply, Map.values(cars), state}
  end

  def handle_call({:get_driver}, _from, %DriverSrv{} = state) do
    {:reply, state.driver, state}
  end

  def handle_call({:set_charge_status, car_id, charge_status}, _from, %DriverSrv{} = state) do
    {response, new_state} = handle_set_charge_status(car_id, charge_status, state)
    {:reply, response, new_state}
  end

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Internal Functions
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  def handle_create_car(vin, state) do
    case Vin.VinValidation.validate_vin(vin) do
      :valid ->
        new_id = state.next_car_id
        new_car = %Car{id: new_id, vin: vin}
        new_state = %DriverSrv{state | next_car_id: new_id + 1, cars: Map.put(state.cars, new_id, new_car) }
        {{:ok, new_car}, new_state}
      {:invalid, reason} ->
        {{:error, "VIN validation failed for reason {#{reason}}"}, state}
    end
  end

  def handle_delete_car(car_id, state) do
    case Integer.parse(car_id) do
      {car_id_int, ""} ->
        case Map.pop(state.cars, car_id_int) do
          {nil, _remaining_cars} ->
            {{:error, "car id not found"}, state}
          {_car, remaining_cars} ->
            {{:ok, state.driver}, %DriverSrv{state | cars: remaining_cars} }
        end
      _else ->
        {{:error, "invalid car id"}, state}
    end
  end

  def handle_set_charge_status(car_id, charge_status, %DriverSrv{cars: cars} = state) do
    case Integer.parse(car_id) do
      {car_id_int, ""} ->
        case cars[car_id_int] do
          nil ->
            {{:error, "car id not found"}, state}
          car ->
            new_car = %Car{car | charge_status: charge_status}
            new_cars = %{cars | car_id_int => new_car}
            {{:ok, new_car}, %DriverSrv{state | cars: new_cars}}
        end
      _else ->
        {{:error, "invalid car id"}, state}
    end
  end

end
