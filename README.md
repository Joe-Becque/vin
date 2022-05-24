# Vin

An Elixir Phoenix server holding an in memory store of drivers and their cars with a GraphQL interface.

## Build and Run

To start the Phoenix server:

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `mix phx.server`

Now visit [`localhost:4000`](http://localhost:4000) from your browser.

## About

The server hosts a GraphQL query interface at [`localhost:4000`](http://localhost:4000).

The interface describes two entities:

* driver
* car

A driver has a name, and may have many cars. A car has a VIN as well as a
charging status. Each car's VIN is checked for validity according to the
check digit calculation documented on [the wikipedia page](https://en.wikipedia.org/wiki/Vehicle_identification_number#Check-digit_calculation).


The following OTP supervision tree manages the processes responsible for holding and serving driver data:

```
Vin.Supervisor (supervisor)
  |
  | -- Vin.DriverSupervisor (supervisor)
        |
        | -- Vin.DriverRegistry (worker)
        |
        | -- Vin.DynamicDriverSupervisor (supervisor)
              |
              | -- Vin.DriverSrv (dynamically spawned worker)
```

Vin.DriverRegistry is a gen server process which owns an ETS table mapping driver ids to their unique driver server process.
When creating new drivers it will dynamically spawn new Vin.DriverSrv processes, which it will monitor to enable it to keep an up to date list of drivers.
Each driver server process holds all the data associated with its driver.

## GraphQL API

The GraphQL API has the following queries:

* `drivers` - return all drivers
* `driver` - return a driver for a given id

and the following mutations:

* `createDriver`
* `createCar`
* `deleteCar`
* `deleteDriver`
* `setChargeStatus`

### drivers

Returns a list of driver objects.

```graphql
{
  drivers {
    id
    name
    cars {
      id
      vin
      chargeStatus
    }
  }
}
```

### driver

Returns a driver object.

```graphql
query driver($id: ID!){
  driver(id: $id){
    id
    name
    cars{
      id
      vin
      chargeStatus
    }
  }
}
```

### createDriver

Creates a driver. Returns a driver object.

```graphql
mutation createDriver($name: String!){
  createDriver(name: $name){
    id
    name
    cars{
      id
      vin
      chargeStatus
    }
  }
}
```

### createCar

Creates a car with charge status "DISCONNECTED". Returns a car object.

```graphql
mutation createCar($driverId: ID!, $vin: String!){
  createCar (driverId: $driverId, vin: $vin){
    id
    vin
    chargeStatus
  }
}
```

### deleteCar

Deletes a car. Returns a driver object.

```graphql
mutation deleteCar($driverId: ID!, $id: ID!){
  deleteCar (driverId: $driverId, id: $id){
    id
    name
    cars{
      id
      vin
      chargeStatus
    }
  }
}
```

### deleteDriver

Delete a driver. Returns a driver id.

```graphql
mutation deleteDriver($driverId: ID!){
  deleteDriver (driverId: $driverId){
    id
  }
}
```

### setChargeStatus

Sets the charge status of a car. Returns a car object.

```graphql
mutation setChargeStatus($driverId: ID!, $id: ID!, $newState: ChargeState!){
  setChargeStatus (driverId: $driverId, id: $id, newState: $newState){
    id
    vin
    chargeStatus
  }
}
```