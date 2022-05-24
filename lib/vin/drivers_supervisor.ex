defmodule Vin.DriversSupervisor do
  use Supervisor
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.info("drivers supervisor initialising")
    children = [
      {DynamicSupervisor, name: Vin.DynamicDriversSupervisor, strategy: :one_for_one},
      Vin.DriverRegistry
    ]
    options = [strategy: :one_for_all]
    Supervisor.init(children, options)
  end

end
