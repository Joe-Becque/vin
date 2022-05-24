defmodule Vin.DriverSrvTest do
  use ExUnit.Case, async: true
  alias Vin.DriverSrv
  alias Vin.Car

  @sample_vin_1 "11111111111111111"
  @sample_id_1 "0"
  @sample_car_1 %Car{
    id: 0,
    vin: @sample_vin_1,
    charge_status: "disconnected"
  }

  @sample_vin_2 "1M8GDM9AXKP042788"
  @sample_id_2 "1"
  @sample_car_2 %Car{
    id: 1,
    vin: @sample_vin_2,
    charge_status: "disconnected"
  }

  setup do
    test_driver = %Vin.Driver{
      id: 0,
      name: "test_driver"
    }
    {:ok, driver_pid} = DynamicSupervisor.start_child(Vin.DynamicDriversSupervisor, {DriverSrv, test_driver})

    %{driver_pid: driver_pid, driver: test_driver}
  end

  test "create a driver", %{driver_pid: driver_pid, driver: test_driver} do
    # the set up has created a new driver. assert the state is as expected
    expected_state = %DriverSrv{
      driver: test_driver,
      next_car_id: 0,
      cars: %{}
    }
    assert expected_state == :sys.get_state(driver_pid)
  end

  test "create and get cars", %{driver_pid: driver_pid} do
    assert [] == DriverSrv.get_cars(driver_pid)

    assert {:ok, @sample_car_1} == DriverSrv.create_car(driver_pid, @sample_vin_1)
    assert [@sample_car_1] == DriverSrv.get_cars(driver_pid)

    assert {:ok, @sample_car_2} == DriverSrv.create_car(driver_pid, @sample_vin_2)
    cars = DriverSrv.get_cars(driver_pid)
    assert Enum.member?(cars, @sample_car_1)
    assert Enum.member?(cars, @sample_car_2)
  end

  test "create car failure", %{driver_pid: driver_pid} do
    expected_reason = "VIN validation failed for reason {invalid VIN length: 7}"
    assert {:error, expected_reason} == DriverSrv.create_car(driver_pid, "bad_vin")
  end

  test "delete car", %{driver_pid: driver_pid, driver: test_driver} do
    assert {:ok, @sample_car_1} == DriverSrv.create_car(driver_pid, @sample_vin_1)
    assert {:ok, @sample_car_2} == DriverSrv.create_car(driver_pid, @sample_vin_2)
    cars = DriverSrv.get_cars(driver_pid)
    assert Enum.member?(cars, @sample_car_1)
    assert Enum.member?(cars, @sample_car_2)

    assert {:ok, test_driver} == DriverSrv.delete_car(driver_pid, @sample_id_1)
    assert [@sample_car_2] == DriverSrv.get_cars(driver_pid)

    assert {:ok, test_driver} == DriverSrv.delete_car(driver_pid, @sample_id_2)
    assert [] == DriverSrv.get_cars(driver_pid)
  end

  test "delete car failure", %{driver_pid: driver_pid} do
    assert {:ok, @sample_car_1} == DriverSrv.create_car(driver_pid, @sample_vin_1)
    assert {:error, "car id not found"} == DriverSrv.delete_car(driver_pid, "99")
    assert {:error, "invalid car id"} == DriverSrv.delete_car(driver_pid, "2.5")
    assert {:error, "invalid car id"} == DriverSrv.delete_car(driver_pid, "not an int")
    assert [@sample_car_1] == DriverSrv.get_cars(driver_pid)
  end

  test "get driver", %{driver_pid: driver_pid, driver: test_driver} do
    assert test_driver == DriverSrv.get_driver(driver_pid)
    assert {:ok, @sample_car_1} == DriverSrv.create_car(driver_pid, @sample_vin_1)
    assert test_driver == DriverSrv.get_driver(driver_pid)
  end

  test "delete a driver",  %{driver_pid: driver_pid} do
    ref = Process.monitor(driver_pid)
    assert :ok = DriverSrv.delete_driver(driver_pid, "test delete")

    receive do
      {:DOWN, down_ref, :process, _pid, down_reason} ->
        assert {:shutdown, "test delete"} == down_reason
        assert ref == down_ref
      after
        100 -> Process.exit(self(), "failed to delete the driver")
    end

    refute Process.alive?(driver_pid)
  end

  test "set charge status", %{driver_pid: driver_pid} do
    assert {:ok, @sample_car_1} == DriverSrv.create_car(driver_pid, @sample_vin_1)
    plugged_in_car = %Car{ @sample_car_1 | charge_status: "plugged_in"}
    assert {:ok, plugged_in_car} == DriverSrv.set_charge_status(driver_pid, @sample_id_1, "plugged_in")
    assert [plugged_in_car] == DriverSrv.get_cars(driver_pid)
  end

  test "set charge status failure", %{driver_pid: driver_pid} do
    assert {:ok, @sample_car_1} == DriverSrv.create_car(driver_pid, @sample_vin_1)
    assert {:error, "car id not found"} == DriverSrv.set_charge_status(driver_pid, "99", "plugged_in")
    assert {:error, "invalid car id"} == DriverSrv.set_charge_status(driver_pid, "2.5", "plugged_in")
    assert {:error, "invalid car id"} == DriverSrv.set_charge_status(driver_pid, "not an int", "plugged_in")
    assert [@sample_car_1] == DriverSrv.get_cars(driver_pid)
  end

end
