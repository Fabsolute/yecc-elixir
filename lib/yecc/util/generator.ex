defmodule Yecc.Util.Generator do
  alias Yecc.Struct.{Reduce, Shift}
  alias Yecc.Util.Table

  def generate_functions() do
    parse_actions = Table.get_instance_parse_actions() |> sort_parse_actions()
  end

  defp sort_parse_actions(list) do
    list
    |> Enum.map(fn {n, look_ahead_actions} ->
      {n, sort_parse_actions1(look_ahead_actions)}
    end)
  end

  defp sort_parse_actions1(look_ahead_actions) do
    [
      &(&1 == :accept),
      &is_struct(&1, Shift),
      &is_struct(&1, Reduce),
      &(&1 == :non_assoc)
    ]
    |> Enum.flat_map(
      &Enum.filter(look_ahead_actions, fn action ->
        action |> elem(1) |> &1.()
      end)
    )
  end
end
