defmodule Vin.Car do
  @enforce_keys [:id, :vin]
  defstruct [:id, :vin, charge_status: "disconnected"]
end
