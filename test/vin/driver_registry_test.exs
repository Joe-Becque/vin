defmodule Vin.DriverRegistryTest do
  use ExUnit.Case
  alias Vin.DriverRegistry
  alias Vin.DriverSrv
  alias Vin.Driver

  test "create and delete a driver" do
    initial_state = %DriverRegistry{
      next_driver_id: 0,
      driver_refs: %{}
    }

    ## Create a driver
    expected_driver_id = 0
    name = "test_driver"
    {new_driver, new_state} = DriverRegistry.handle_create_driver(name, initial_state)

    # Check the driver returned
    assert %Driver{id: expected_driver_id, name: name} == new_driver

    # Check the new state
    assert 1 == new_state.next_driver_id
    assert [expected_driver_id] == Map.values(new_state.driver_refs)

    # Check the new driver srv process that's been started
    [{0, driver_srv_pid}] = :ets.lookup(:driver_registry, expected_driver_id)
    assert Process.alive?(driver_srv_pid)
    assert %DriverSrv{
      driver: new_driver,
      next_car_id: 0,
      cars: %{}
    } == :sys.get_state(driver_srv_pid)

    ## Delete the driver
    [expected_ref] = Map.keys(new_state.driver_refs)

    assert {:ok, 0} == DriverRegistry.handle_delete_driver("0")
    assert [] = :ets.lookup(:driver_registry, expected_driver_id)

    receive do
      {:DOWN, ref, :process, pid, {:shutdown, delete_driver: driver_id}} ->
        assert driver_id == expected_driver_id
        assert ref == expected_ref
        assert pid == driver_srv_pid
    end

    refute Process.alive?(driver_srv_pid)
  end

  test "shutdown message when driver is deleted" do
    test_id = 0
    next_id = 1
    test_ref = "dummy ref"
    test_pid = "dummy pid"
    initial_state = %DriverRegistry{
      next_driver_id: next_id,
      driver_refs: %{test_ref => test_id}
    }

    {:noreply, new_state} = DriverRegistry.handle_info({:DOWN, test_ref, :process, test_pid, {:shutdown, delete_driver: test_id}}, initial_state)
    assert new_state.next_driver_id == next_id
    assert new_state.driver_refs == %{}
  end

  test "shutdown message when driver dies" do
    test_id = 0
    next_id = 1
    test_ref = "dummy ref"
    test_pid = "dummy pid"
    initial_state = %DriverRegistry{
      next_driver_id: next_id,
      driver_refs: %{test_ref => test_id}
    }
    :ets.insert(:driver_registry, {test_id, test_pid})
    assert [{test_id, test_pid}] == :ets.lookup(:driver_registry, test_id)

    {:noreply, new_state} = DriverRegistry.handle_info({:DOWN, test_ref, :process, test_pid, :test_dead_driver}, initial_state)
    assert new_state.next_driver_id == next_id
    assert new_state.driver_refs == %{}
    assert [] == :ets.lookup(:driver_registry, test_id)
  end

  test "delete driver fails for bad inputs" do
    assert {:error, "driver id not found"} = DriverRegistry.handle_delete_driver("99")
    assert {:error, "invalid driver id"} = DriverRegistry.handle_delete_driver("2.5")
    assert {:error, "invalid driver id"} = DriverRegistry.handle_delete_driver("not an int")
  end

  test "list all drivers" do
    driver1 = DriverRegistry.create_driver("d1")
    driver2 = DriverRegistry.create_driver("d2")
    {:ok, drivers} = DriverRegistry.list_all_drivers()
    assert Enum.member?(drivers, driver1)
    assert Enum.member?(drivers, driver2)
    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert {:ok, driver2.id} == DriverRegistry.delete_driver(Integer.to_string(driver2.id))
    assert [] = :ets.tab2list(:driver_registry)
  end

  test "get driver success" do
    driver1 = DriverRegistry.create_driver("d1")
    driver2 = DriverRegistry.create_driver("d2")
    {:ok, driver1} = DriverRegistry.get_driver(Integer.to_string(driver1.id))
    {:ok, driver2} = DriverRegistry.get_driver(Integer.to_string(driver2.id))
    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert {:ok, driver2.id} == DriverRegistry.delete_driver(Integer.to_string(driver2.id))
    assert [] = :ets.tab2list(:driver_registry)
  end

  test "get driver failure" do
    assert {:error, "driver id not found"} == DriverRegistry.get_driver("99")
    assert {:error, "invalid driver id"} = DriverRegistry.get_driver("2.5")
    assert {:error, "invalid driver id"} = DriverRegistry.get_driver("not an int")
  end

  test "create car success" do
    driver1 = DriverRegistry.create_driver("d1")
    driver2 = DriverRegistry.create_driver("d2")

    {:ok, car1a} = DriverRegistry.create_car(Integer.to_string(driver1.id), "11111111111111111")
    assert %Vin.Car{id: 0, vin: "11111111111111111", charge_status: "disconnected"} == car1a

    {:ok, car1b} = DriverRegistry.create_car(Integer.to_string(driver1.id), "1M8GDM9AXKP042788")
    assert %Vin.Car{id: 1, vin: "1M8GDM9AXKP042788", charge_status: "disconnected"} == car1b

    {:ok, car2a} = DriverRegistry.create_car(Integer.to_string(driver2.id), "11111111111111111")
    assert %Vin.Car{id: 0, vin: "11111111111111111", charge_status: "disconnected"} == car2a

    {:ok, car2b} = DriverRegistry.create_car(Integer.to_string(driver2.id), "1M8GDM9AXKP042788")
    assert %Vin.Car{id: 1, vin: "1M8GDM9AXKP042788", charge_status: "disconnected"} == car2b

    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert {:ok, driver2.id} == DriverRegistry.delete_driver(Integer.to_string(driver2.id))
    assert [] = :ets.tab2list(:driver_registry)
  end

  test "create car failure" do
    driver1 = DriverRegistry.create_driver("d1")
    assert {:error, "driver id not found"} == DriverRegistry.create_car("99", "11111111111111111")
    assert {:error, "VIN validation failed for reason {invalid VIN length: 1}"} == DriverRegistry.create_car(Integer.to_string(driver1.id), "1")

    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert [] = :ets.tab2list(:driver_registry)
  end

  test "delete car success" do
    driver1 = DriverRegistry.create_driver("d1")

    {:ok, car1} = DriverRegistry.create_car(Integer.to_string(driver1.id), "11111111111111111")
    assert %Vin.Car{id: 0, vin: "11111111111111111", charge_status: "disconnected"} == car1

    {:ok, driver1} = DriverRegistry.delete_car(Integer.to_string(driver1.id), Integer.to_string(car1.id))
    assert {:ok, []} == DriverRegistry.get_cars(driver1.id)

    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert [] = :ets.tab2list(:driver_registry)
  end

  test "delete car failure" do
    driver1 = DriverRegistry.create_driver("d1")
    assert {:error, "driver id not found"} == DriverRegistry.delete_car("99", "0")
    assert {:error, "car id not found"} == DriverRegistry.delete_car(Integer.to_string(driver1.id), "99")

    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert [] = :ets.tab2list(:driver_registry)
  end

  test "get cars" do
    driver1 = DriverRegistry.create_driver("d1")
    assert {:ok, []} == DriverRegistry.get_cars(driver1.id)

    {:ok, car1a} = DriverRegistry.create_car(Integer.to_string(driver1.id), "11111111111111111")
    assert {:ok, [car1a]} == DriverRegistry.get_cars(driver1.id)

    {:ok, car1b} = DriverRegistry.create_car(Integer.to_string(driver1.id), "1M8GDM9AXKP042788")
    {:ok, cars} = DriverRegistry.get_cars(driver1.id)
    assert Enum.member?(cars, car1a)
    assert Enum.member?(cars, car1b)

    assert {:ok, []} == DriverRegistry.get_cars(123)

    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert [] = :ets.tab2list(:driver_registry)
  end

  test "set charge status success" do
    driver1 = DriverRegistry.create_driver("d1")
    {:ok, car1} = DriverRegistry.create_car(Integer.to_string(driver1.id), "11111111111111111")
    assert %Vin.Car{id: 0, vin: "11111111111111111", charge_status: "disconnected"} == car1

    {:ok, car2} = DriverRegistry.set_charge_status(Integer.to_string(driver1.id), "0", "plugged_in")
    assert %Vin.Car{id: 0, vin: "11111111111111111", charge_status: "plugged_in"} == car2

    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert [] = :ets.tab2list(:driver_registry)
  end

  test "set charge status failure" do
    driver1 = DriverRegistry.create_driver("d1")

    assert {:error, "driver id not found"} == DriverRegistry.set_charge_status("99", "0", "plugged_in")
    assert {:error, "invalid driver id"} == DriverRegistry.set_charge_status("one", "0", "plugged_in")
    assert {:error, "car id not found"} == DriverRegistry.set_charge_status(Integer.to_string(driver1.id), "99", "plugged_in")
    assert {:error, "invalid car id"} == DriverRegistry.set_charge_status(Integer.to_string(driver1.id), "one", "plugged_in")

    assert {:ok, driver1.id} == DriverRegistry.delete_driver(Integer.to_string(driver1.id))
    assert [] = :ets.tab2list(:driver_registry)
  end
end
