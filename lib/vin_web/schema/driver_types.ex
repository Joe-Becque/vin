defmodule VinWeb.Schema.DriverTypes do
  use Absinthe.Schema.Notation
  alias VinWeb.Resolvers

  object :driver do
    field(:id, :id)
    field(:name, :string)

    field(:cars, list_of(:car)) do
      resolve(&Resolvers.Drivers.cars/3)
    end
  end

  object :car do
    field(:id, :id)
    field(:vin, :string)
    field(:charge_status, :charge_status)
  end

  object :delete_driver_payload do
    field(:id, :id)
  end

  enum :charge_status do
    value(:disconnected, as: "disconnected")
    value(:plugged_in, as: "plugged_in")
    value(:charging, as: "charging")
  end

  scalar :charge_state do
    serialize &encode/1
    parse &decode/1
  end

  defp encode(return) do
    case valid_charge_status?(return.value) do
      true -> return.value
      false -> :error
    end
  end

  defp decode(input) do
    case valid_charge_status?(input.value) do
     true -> {:ok, input.value}
     false -> :error
    end
  end

  defp valid_charge_status?("disconnected"), do: true
  defp valid_charge_status?("plugged_in"), do: true
  defp valid_charge_status?("charging"), do: true
  defp valid_charge_status?(_), do: false
end
