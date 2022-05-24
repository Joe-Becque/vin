defmodule VinWeb.GraphqlTest do
  use VinWeb.ConnCase

  test "list all drivers" do
    # Assert there are no drivers
    expected_response = %{"drivers" => []}
    drivers = list_drivers()
    assert json_response(drivers, 200)["data"] == expected_response
  end

  test "e2e creating drivers and cars" do
    # A sequence of creating drivers and cars with GraphQL API to ensure that state is maintained correctly
    # Part 1 - create and get driver1
    # Part 2 - create and get 2 cars for driver1
    # Part 3 - create and get driver2
    # Part 4 - create and get a car3 for driver2 and ensure driver1 state is correct
    # Part 5 - set the charge status for driver2's car
    # Part 6 - delete driver 1 and check it is deleted
    # Part 7 - delete car3 and driver 2 and check it is deleted

    ## Part 1 - create and get driver1

    # list drivers - none returned
    expected_response = %{"drivers" => []}
    drivers = list_drivers()
    assert json_response(drivers, 200)["data"] == expected_response
    # create driver1
    variables = %{name: "test_driver1"}
    expected_response = %{
        "createDriver" => %{
            "cars" => [],
            "name" => "test_driver1"
        }
      }
    driver_resp = create_driver(variables)
    assert json_response(driver_resp, 200)["data"] == expected_response
    # list drivers - return driver1
    drivers = list_drivers(:id_returned)
    [driver1] = json_response(drivers, 200)["data"]["drivers"]
    assert driver1["name"] == "test_driver1"
    assert driver1["cars"] == []
    # get driver1
    variables = %{id: driver1["id"]}
    expected_response = %{
        "driver" => %{
            "cars" => [],
            "name" => "test_driver1"
        }
      }
    driver = get_driver(variables)
    assert json_response(driver, 200)["data"] == expected_response

    ## Part 2 - create and get 2 cars for driver1

    # create car1 for driver1
    variables = %{driverId: driver1["id"], vin: "11111111111111111"}
    expected_response = %{
        "createCar" => %{
          "chargeStatus" => "DISCONNECTED",
          "id"  => "0",
          "vin" => "11111111111111111"
        }
      }
    car1_resp = create_car(variables)
    car1 = json_response(car1_resp, 200)["data"]
    assert car1 == expected_response
    # get driver1 - return car1
    variables = %{id: driver1["id"]}
    expected_response = %{
        "driver" => %{
            "cars" => [car1["createCar"]],
            "name" => "test_driver1"
        }
      }
    driver = get_driver(variables)
    assert json_response(driver, 200)["data"] == expected_response
    # create car2 for driver1
    variables = %{driverId: driver1["id"], vin: "1M8GDM9AXKP042788"}
    expected_response = %{
        "createCar" => %{
          "chargeStatus" => "DISCONNECTED",
          "id"  => "1",
          "vin" => "1M8GDM9AXKP042788"
        }
      }
    car2_resp = create_car(variables)
    car2 = json_response(car2_resp, 200)["data"]
    assert car2 == expected_response
    # get driver1 - return car1 and car2
    variables = %{id: driver1["id"]}
    expected_response = %{
        "driver" => %{
            "cars" => [
                        car1["createCar"],
                        car2["createCar"]],
            "name" => "test_driver1"
        }
      }
    driver = get_driver(variables)
    assert json_response(driver, 200)["data"] == expected_response

    ## Part 3 - create and get driver2

    # create driver2
    variables = %{name: "test_driver2"}
    expected_response = %{
        "createDriver" => %{
            "cars" => [],
            "name" => "test_driver2"
        }
      }
    driver_resp = create_driver(variables)
    assert json_response(driver_resp, 200)["data"] == expected_response
    # list drivers - return driver1 and driver2
    drivers_resp = list_drivers()
    drivers = json_response(drivers_resp, 200)["data"]["drivers"]
    {[driver1_list_resp], [driver2_list_resp]} = Enum.split_with(drivers, fn(%{"cars" => cars}) -> cars != [] end)
    assert driver1_list_resp["name"] == "test_driver1"
    assert driver1_list_resp["cars"] == [car1["createCar"], car2["createCar"]]
    assert driver2_list_resp["name"] == "test_driver2"
    assert driver2_list_resp["cars"] == []

    ## Part 4 - create and get a car for driver2 and ensure driver1 state is correct

    # create car3 for driver2
    drivers_resp = list_drivers(:id_returned) # require the id to create a car
    drivers = json_response(drivers_resp, 200)["data"]["drivers"]
    driver2 = Enum.find(drivers, fn %{"cars" => cars} -> cars == [] end) # driver2 has no cars

    variables = %{driverId: driver2["id"], vin: "11111111111111111"}
    expected_response = %{
        "createCar" => %{
          "chargeStatus" => "DISCONNECTED",
          "id"  => "0",
          "vin" => "11111111111111111"
        }
      }
    car3_resp = create_car(variables)
    car3 = json_response(car3_resp, 200)["data"]
    assert car3 == expected_response
    # get driver2 - return car3
    variables = %{id: driver2["id"]}
    expected_response = %{
        "driver" => %{
            "cars" => [car3["createCar"]],
            "name" => "test_driver2"
        }
      }
    driver = get_driver(variables)
    assert json_response(driver, 200)["data"] == expected_response
    # get driver1 - return car1 and car2
    variables = %{id: driver1["id"]}
    expected_response = %{
        "driver" => %{
            "cars" => [
                        car1["createCar"],
                        car2["createCar"]],
            "name" => "test_driver1"
        }
      }
    driver = get_driver(variables)
    assert json_response(driver, 200)["data"] == expected_response

    ## Part 5 - set the charge status for driver2's car

    # set the charge status for driver2 car3
    variables = %{driverId: driver2["id"], id: "0", newState: "plugged_in"}
    expected_response = %{
        "chargeStatus" => "PLUGGED_IN",
        "id" => "0",
        "vin" => "11111111111111111"
    }
    car3_plugged_in_resp = set_charge_status(variables)
    car3_plugged_in = json_response(car3_plugged_in_resp, 200)["data"]["setChargeStatus"]
    assert car3_plugged_in == expected_response
    # get driver2 - has new charge status
    variables = %{id: driver2["id"]}
    expected_response = %{
        "driver" => %{
            "cars" => [car3_plugged_in],
            "name" => "test_driver2"
        }
      }
    driver = get_driver(variables)
    assert json_response(driver, 200)["data"] == expected_response

    ## Part 6 - delete driver 1 and check it is deleted

    # delete driver1
    variables = %{driverId: driver1["id"]}
    expected_response = %{
      "data" => %{
        "deleteDriver" => %{
          "id" => driver1["id"]
        }
      }
    }
    delete_resp = delete_driver(variables)
    assert json_response(delete_resp, 200) == expected_response
    # get driver1 - return driver not found
    variables = %{id: driver1["id"]}
    expected_data = %{"driver" => nil}
    expected_error_message = "driver id not found"
    expected_error_path = ["driver"]
    driver = get_driver(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
    # get driver2 - not impacted by delete
    variables = %{id: driver2["id"]}
    expected_response = %{
        "driver" => %{
            "cars" => [car3_plugged_in],
            "name" => "test_driver2"
        }
      }
    driver = get_driver(variables)
    assert json_response(driver, 200)["data"] == expected_response

    ## Part 7 - delete car3 and driver 2 and check it is deleted

    # delete car3 for driver 2
    variables = %{driverId: driver2["id"], id: "0"}
    expected_response = %{
        "deleteCar" => %{
          "id" => driver2["id"],
          "cars" => [],
          "name" => "test_driver2"
        }
      }
    delete_car_resp = delete_car(variables)
    assert json_response(delete_car_resp, 200)["data"] == expected_response
    # delete driver2
    variables = %{driverId: driver2["id"]}
    expected_response = %{
        "deleteDriver" => %{
          "id" => driver2["id"]
        }
      }
    delete_resp = delete_driver(variables)
    assert json_response(delete_resp, 200)["data"] == expected_response
    # get driver2 - return driver not found
    variables = %{id: driver2["id"]}
    expected_data = %{"driver" => nil}
    expected_error_message = "driver id not found"
    expected_error_path = ["driver"]
    driver = get_driver(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
    # list drivers - none returned
    expected_response = %{"drivers" => []}
    drivers = list_drivers()
    assert json_response(drivers, 200)["data"] == expected_response
  end

  test "get driver id not found failure" do
    variables = %{id: 100}
    expected_data = %{"driver" => nil}
    expected_error_message = "driver id not found"
    expected_error_path = ["driver"]

    driver = get_driver(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  test "get invalid driver id failure" do
    variables = %{id: "invalid"}
    expected_data = %{"driver" => nil}
    expected_error_message = "invalid driver id"
    expected_error_path = ["driver"]

    driver = get_driver(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end


  test "create car driver id not found failure" do
    variables = %{driverId: 99, vin: "11111111111111111"}
    expected_data = %{"createCar" => nil}
    expected_error_message = "driver id not found"
    expected_error_path = ["createCar"]

    driver = create_car(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  test "create car invalid driver id failure" do
    variables = %{driverId: "ok", vin: "11111111111111111"}
    expected_data = %{"createCar" => nil}
    expected_error_message = "invalid driver id"
    expected_error_path = ["createCar"]

    driver = create_car(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  test "create car invalid vin failure" do
    # create driver
    variables = %{name: "test_driver1"}
    create_resp = create_driver(variables, :id_returned)
    create_json = json_response(create_resp, 200)["data"]["createDriver"]
    id = create_json["id"]

    variables = %{driverId: id, vin: "woops"}
    expected_data = %{"createCar" => nil}
    expected_error_message = "VIN validation failed for reason {invalid VIN length: 5}"
    expected_error_path = ["createCar"]

    driver = create_car(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path

    # delete driver
    delete_driver(%{driverId: id})
  end

  test "delete car driver id not found failure" do
    variables = %{driverId: "99", id: "1"}
    expected_data = %{"deleteCar" => nil}
    expected_error_message = "driver id not found"
    expected_error_path = ["deleteCar"]

    driver = delete_car(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  test "delete car invalid driver id failure" do
    variables = %{driverId: "ok", id: "1"}
    expected_data = %{"deleteCar" => nil}
    expected_error_message = "invalid driver id"
    expected_error_path = ["deleteCar"]

    driver = delete_car(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  test "delete car car id not found failure" do
    # create driver
    variables = %{name: "test_driver1"}
    create_resp = create_driver(variables, :id_returned)
    create_json = json_response(create_resp, 200)["data"]["createDriver"]
    driver_id = create_json["id"]

    variables = %{driverId: driver_id, id: "99"}
    expected_data = %{"deleteCar" => nil}
    expected_error_message = "car id not found"
    expected_error_path = ["deleteCar"]

    driver = delete_car(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path

    # delete driver
    delete_driver(%{driverId: driver_id})
  end

  test "delete car invalid car id failure" do
    # create driver
    variables = %{name: "test_driver1"}
    create_resp = create_driver(variables, :id_returned)
    create_json = json_response(create_resp, 200)["data"]["createDriver"]
    driver_id = create_json["id"]

    variables = %{driverId: driver_id, id: "invalid"}
    expected_data = %{"deleteCar" => nil}
    expected_error_message = "invalid car id"
    expected_error_path = ["deleteCar"]

    driver = delete_car(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path

    # delete driver
    delete_driver(%{driverId: driver_id})
  end

  test "delete driver id not found failure" do
    variables = %{driverId: "99"}
    expected_data = %{"deleteDriver" => nil}
    expected_error_message = "driver id not found"
    expected_error_path = ["deleteDriver"]

    driver = delete_driver(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  test "delete driver invalid id failure" do
    variables = %{driverId: "invalid"}
    expected_data = %{"deleteDriver" => nil}
    expected_error_message = "invalid driver id"
    expected_error_path = ["deleteDriver"]

    driver = delete_driver(variables)
    json_resp = json_response(driver, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  test "set charge status invalid id failure" do
    variables = %{driverId: "invalid", id: "0", newState: "plugged_in"}
    expected_data = %{"setChargeStatus" => nil}
    expected_error_message = "invalid driver id"
    expected_error_path = ["setChargeStatus"]

    set_charge_resp = set_charge_status(variables)
    json_resp = json_response(set_charge_resp, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  test "set charge status bad new state failure" do
    variables = %{driverId: "0", id: "0", newState: "wrong"}
    expected_data = nil
    expected_error_message = "Argument \"newState\" has invalid value $newState."
    expected_error_path = nil

    set_charge_resp = set_charge_status(variables)
    json_resp = json_response(set_charge_resp, 200)
    assert json_resp["data"] == expected_data
    [errors] = json_resp["errors"]
    assert errors["message"] == expected_error_message
    assert errors["path"] == expected_error_path
  end

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Query Generators
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  def list_drivers(opt \\ :no_id_returned) do
    list_drivers_query = get_list_drivers_query(opt)
    build_conn()
      |> post("/api/graphql", %{query: list_drivers_query})
  end

  def get_driver(variables) do
    get_drivers_query = get_get_driver_query()
    build_conn()
      |> post("/api/graphql", %{query: get_drivers_query, variables: variables})
  end

  def create_driver(variables, opt \\ :no_id_returned) do
    create_drivers_mutation = get_create_drivers_mutation(opt)
    build_conn()
      |> post("/api/graphql", %{query: create_drivers_mutation, variables: variables})
  end

  def delete_driver(variables) do
    delete_driver_mutation = get_delete_driver_mutation()
    build_conn()
      |> post("/api/graphql", %{query: delete_driver_mutation, variables: variables})
  end

  def create_car(variables) do
    create_car_mutation = get_create_car_mutation()
    build_conn()
      |> post("/api/graphql", %{query: create_car_mutation, variables: variables})
  end

  def delete_car(variables) do
    delete_car_mutation = get_delete_car_mutation()
    build_conn()
      |> post("/api/graphql", %{query: delete_car_mutation, variables: variables})
  end

  def set_charge_status(variables) do
    set_charge_status_mutation = get_set_charge_status_mutation()
    build_conn()
      |> post("/api/graphql", %{query: set_charge_status_mutation, variables: variables})
  end

  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Query Templates
  #%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  def get_list_drivers_query(:no_id_returned) do
    """
    { drivers{
        name
        cars{
          id
          vin
          chargeStatus
        }
      }
    }
    """
  end
  def get_list_drivers_query(:id_returned) do
    """
    { drivers{
        id
        name
        cars{
          id
          vin
          chargeStatus
        }
      }
    }
    """
  end

  def get_get_driver_query() do
    """
    query driver($id: ID!){ driver(id: $id){
        name
        cars{
          id
          vin
          chargeStatus
        }
      }
    }
    """
  end

  def get_create_drivers_mutation(:no_id_returned) do
    """
    mutation createDriver($name: String){
      createDriver(name: $name){
        name
        cars{
          id
        }
      }
    }
    """
  end
  def get_create_drivers_mutation(:id_returned) do
    """
    mutation createDriver($name: String!){
      createDriver(name: $name){
        id
        name
        cars{
          id
        }
      }
    }
    """
  end

  def  get_delete_driver_mutation do
    """
    mutation deleteDriver($driverId: ID!){
      deleteDriver (driverId: $driverId){
        id
      }
    }
    """
  end

  def get_create_car_mutation do
    """
    mutation createCar($driverId: ID!, $vin: String){
      createCar (driverId: $driverId, vin: $vin){
        id
        vin
        chargeStatus
      }
    }
    """
  end

  def get_delete_car_mutation do
    """
    mutation deleteCar($driverId: ID!, $id: ID!){
      deleteCar (driverId: $driverId, id: $id){
        id
        name
        cars{
          id
        }
      }
    }
    """
  end

  def get_set_charge_status_mutation() do
    """
    mutation setChargeStatus($driverId: ID!, $id: ID!, $newState: ChargeState!){
      setChargeStatus (driverId: $driverId, id: $id, newState: $newState){
        id
        vin
        chargeStatus
      }
    }
    """
  end
end
