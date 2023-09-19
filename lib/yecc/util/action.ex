defmodule Yecc.Util.Action do
  @accept {}

  alias Yecc.Util.{Table, Code, States, Reduce, Shift, Item, Rule}

  def parse_actions() do
    n = Table.get_instance_n()

    compute_parse_actions(n, [])
    |> Table.store_instance_parse_actions()
  end

  def rule(rule_pointer) do
    {^rule_pointer, %Rule{n: n, symbols: symbols}} = Table.get_rule_pointer_to_rule(rule_pointer)
    {symbols, n}
  end

  defp compute_parse_actions(n, state_actions) when n < 0, do: state_actions

  defp compute_parse_actions(n, state_actions) do
    {^n, state_n} = Table.lookup_state(n + 1)
    actions = compute_parse_actions1(state_n, n)
    compute_parse_actions(n - 1, [{n, actions} | state_actions])
  end

  defp compute_parse_actions1([], _), do: []

  defp compute_parse_actions1(
         [%Item{rule_pointer: rule_pointer, look_ahead: look_ahead, rhs: rhs} | items],
         n
       ) do
    case rhs do
      [] ->
        look_ahead = Code.decode_terminals(look_ahead)

        case rule(rule_pointer) do
          {[@accept | _], _} ->
            [{look_ahead, :accept} | compute_parse_actions1(items, n)]

          {[head | daughters], _} ->
            daughters = List.delete(daughters, :"$empty")

            [
              {look_ahead,
               %Reduce{
                 rule_number: rule_pointer,
                 head: head,
                 number_of_daughters: length(daughters),
                 precedence: get_precedence(daughters ++ [head])
               }}
              | compute_parse_actions1(items, n)
            ]
        end

      [symbol | daugters] ->
        if States.is_terminal?(symbol) do
          decoded_symbol = Code.decode_symbol(symbol)
          {[head | _], _} = rule(rule_pointer)

          precedence =
            case daugters do
              [] -> get_precedence([decoded_symbol, head])
              _ -> get_precedence([decoded_symbol])
            end

          pos =
            case daugters do
              [] -> :z
              _ -> :a
            end

          [
            {[decoded_symbol],
             %Shift{
               state: goto(n, decoded_symbol),
               pos: pos,
               precedence: precedence,
               rule_number: rule_pointer
             }}
            | compute_parse_actions1(items, n)
          ]
        else
          compute_parse_actions1(items, n)
        end
    end
  end

  defp get_precedence(symbols) do
    get_precedence(symbols, {0, :none})
  end

  defp get_precedence([], precedence), do: precedence

  defp get_precedence([symbol | rest], precedence) do
    case Table.lookup_precedence(symbol) do
      nil -> get_precedence(rest, precedence)
      {_, n, ass} -> get_precedence(rest, {n, ass})
    end
  end

  defp goto(from, symbol) do
    case Table.lookup_goto({from, symbol}) do
      {_, to} -> to
      nil -> throw({:error_in_goto_table, from, symbol})
    end
  end
end
