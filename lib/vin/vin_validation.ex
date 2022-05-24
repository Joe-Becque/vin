defmodule Vin.VinValidation do

  @weights [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2]
  @magic_divisor 11
  @check_digit_position 8


  @moduledoc """
  Validate a VIN - https://en.wikipedia.org/wiki/Vehicle_identification_number#Check-digit_calculation

    1. Check length of the vin
    2. Check the 'check digit'
      a. For each character
        - transliterate to the value associated with the character
        - multiply by the weight
      b. Sum these values
      c. Modulo sum with 11 (a remainder of 10 evaluates to X)
      d. Compare the result with 9th char

  iex> Vin.VinValidation.validate_vin("11111111111111111")
  :valid

  iex> Vin.VinValidation.validate_vin("1M8GDM9AXKP042788") #2019 Motor D4520
  :valid

  iex> Vin.VinValidation.validate_vin("WAUKEAFM8DA033285") #2013 Audi A3
  :valid

  iex> Vin.VinValidation.validate_vin("YV1LZ5647W2469314") #1998 Volvo V70
  :valid

  iex> Vin.VinValidation.validate_vin("JH4DB1650NS000627") #1992 Acura Integra
  :valid

  iex> Vin.VinValidation.validate_vin("2T1BR18E5WC056406") #1998 Toyota Corolla
  :valid

  iex> Vin.VinValidation.validate_vin("1J4GX48S81C511876") #2001 Jeep Grand Cherokee
  :valid

  iex> Vin.VinValidation.validate_vin("123")
  {:invalid, "invalid VIN length: 3"}

  iex> Vin.VinValidation.validate_vin("11111111111111@11")
  {:invalid, "invalid character in VIN: \\"@\\""}

  iex> Vin.VinValidation.validate_vin("11111111X11111111")
  {:invalid, "invalid check digit value"}
  """

  @spec validate_vin(String.t) :: :valid | {:invalid, String.t}
  def validate_vin(vin) do
    try do
      validate_length(vin)
      validate_check_digit(vin)
    catch
      error -> {:invalid, error}
    end
  end

  def validate_length(vin) do
    len = String.length(vin)
    case len == length(@weights) do
      :true  -> :ok
      :false -> throw "invalid VIN length: #{inspect len}"
    end
  end

  def validate_check_digit(vin) do
    vin
    |> String.graphemes()
    |> Enum.zip(@weights)
    |> Enum.reduce(0, fn({value, weight}, acc) -> (transliterate(value) * weight) + acc end)
    |> determine_remainder()
    |> validate_remainder(vin)
  end

  def validate_remainder(remainder, vin) do
    case remainder == String.at(vin, @check_digit_position) do
      :true -> :valid
      :false -> throw "invalid check digit value"
    end
  end

  def determine_remainder(product) do
    case rem product, @magic_divisor do
      10 -> "X"
      int -> Integer.to_string(int)
    end
  end

  def transliterate("A"), do: 1
  def transliterate("B"), do: 2
  def transliterate("C"), do: 3
  def transliterate("D"), do: 4
  def transliterate("E"), do: 5
  def transliterate("F"), do: 6
  def transliterate("G"), do: 7
  def transliterate("H"), do: 8
  def transliterate("J"), do: 1
  def transliterate("K"), do: 2
  def transliterate("L"), do: 3
  def transliterate("M"), do: 4
  def transliterate("N"), do: 5
  def transliterate("P"), do: 7
  def transliterate("R"), do: 9
  def transliterate("S"), do: 2
  def transliterate("T"), do: 3
  def transliterate("U"), do: 4
  def transliterate("V"), do: 5
  def transliterate("W"), do: 6
  def transliterate("X"), do: 7
  def transliterate("Y"), do: 8
  def transliterate("Z"), do: 9
  def transliterate(char) do
    case Integer.parse(char) do
      {char_int, _} ->
        char_int
      :error ->
        throw "invalid character in VIN: #{inspect char}"
    end
  end

end
