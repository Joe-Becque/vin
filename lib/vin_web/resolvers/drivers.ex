defmodule VinWeb.Resolvers.Drivers do
  require Logger
  alias Vin.DriverRegistry
  alias Vin.Driver
  alias Vin.Car

  @spec list_drivers(any, any, any) :: {:ok, list(%Driver{})}
  def list_drivers(_, _, _) do
    Logger.info("listing drivers")
    DriverRegistry.list_all_drivers()
  end

  @spec get_driver(
    any,
    %{:id => String.t, optional(any) => any},
    any)
    :: {:ok, %Driver{}} | {:error, String.t}
  def get_driver(_, %{id: driver_id}, _) do
    Logger.info("get driver id: #{inspect driver_id}")
    DriverRegistry.get_driver(driver_id)
  end

  @spec create_driver(
    any,
    %{:name => String.t, optional(any) => any},
    any)
    :: {:ok, %Driver{}}
  def create_driver(_,%{name: name},_) do
    Logger.info("create driver with name: #{inspect name}")
    driver = DriverRegistry.create_driver(name)
    {:ok, driver}
  end

  @spec create_car(
    any,
    %{:driver_id => String.t, :vin => String.t, optional(any) => any},
    any)
    :: {:ok, %Car{}} | {:error, String.t}
  def create_car(_, %{driver_id: driver_id, vin: vin}, _) do
    Logger.info("create car. driver_id: #{inspect driver_id}, vin: #{inspect vin}")
    DriverRegistry.create_car(driver_id, vin)
  end

  @spec delete_car(
    any,
    %{:driver_id => String.t, :id => String.t, optional(any) => any},
    any)
    :: {:ok, %Driver{}} | {:error, String.t}
  def delete_car(_, %{driver_id: driver_id, id: car_id}, _) do
    Logger.info("delete car. driver_id: #{inspect driver_id}, car_id: #{inspect car_id}")
    DriverRegistry.delete_car(driver_id, car_id)
  end

  @spec cars(
    %{:id => integer, optional(any) => any},
    any,
    any)
    :: {:ok, list(%Vin.Car{})}
  def cars(%{id: driver_id}, _, _) do
    Logger.info("get cars for driver_id: #{inspect driver_id}")
    DriverRegistry.get_cars(driver_id)
  end

  @spec delete_driver(
    any,
    %{:driver_id => binary, optional(any) => any},
    any)
    :: {:ok, %{id: integer}} | {:error, String.t}
  def delete_driver(_, %{driver_id: driver_id}, _) do
    Logger.info("delete driver. driver_id #{inspect driver_id}")
    case DriverRegistry.delete_driver(driver_id) do
      {:ok, driver_id} -> {:ok, %{id: driver_id}}
      error -> error
    end
  end

  @spec set_charge_status(
    any,
    %{:driver_id => String.t, :id => String.t, :new_state => String.t, optional(any) => any},
    any)
    :: {:ok, %Car{}} | {:error, String.t}
  def set_charge_status(_, %{driver_id: driver_id, id: car_id, new_state: charge_status}, _) do
    Logger.info("set charge status. driver_id: #{inspect driver_id}, car_id: #{inspect car_id}, charge_status: #{inspect charge_status}")
    DriverRegistry.set_charge_status(driver_id, car_id, charge_status)
  end
end
