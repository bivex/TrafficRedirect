defmodule TrafficRedirect.Domain.Filter.Helpers do
  @moduledoc false

  @doc """
  Evaluates comparison mode against expected and actual value using clean pattern matching clauses.
  """
  def compare(:is, expected, actual) do
    clean_str(actual) == clean_str(expected)
  end

  def compare(:is_not, expected, actual) do
    clean_str(actual) != clean_str(expected)
  end

  def compare(:in, expected, actual) do
    act = clean_str(actual)
    expected |> normalize_list() |> Enum.any?(&(clean_str(&1) == act))
  end

  def compare(:not_in, expected, actual) do
    act = clean_str(actual)
    expected |> normalize_list() |> Enum.all?(&(clean_str(&1) != act))
  end

  def compare(:contains, expected, actual) do
    String.contains?(clean_str(actual), clean_str(expected))
  end

  def compare(:regex, expected, actual) do
    case Regex.compile(to_string(expected), "i") do
      {:ok, regex} -> Regex.match?(regex, clean_str(actual))
      _ -> false
    end
  end

  def compare(:greater, expected, actual) do
    parse_float(actual) > parse_float(expected)
  end

  def compare(:less, expected, actual) do
    parse_float(actual) < parse_float(expected)
  end

  def compare(_mode, _expected, _actual), do: true

  @doc """
  Normalizes any string or atom value to a lowercase trimmed string.
  """
  def clean_str(val), do: to_string(val || "") |> String.trim() |> String.downcase()

  defp normalize_list(list) when is_list(list), do: list
  defp normalize_list(str) when is_binary(str), do: String.split(str, ~r/[,\n\r]+/, trim: true)
  defp normalize_list(other), do: [other]

  defp parse_float(val) when is_number(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end
