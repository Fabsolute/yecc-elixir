defmodule Yecc.Util.Code do
  alias Yecc.Util.{Table, Bitwise}

  def create_codeds(rules, nonterminals) do
    rules = rules |> Enum.map(&%{&1 | symbols: code_symbols(&1.symbols)})
    nonterminals = nonterminals |> code_symbols()
    Table.store_coded(rules: rules, nonterminals: nonterminals)
  end

  def decode_goto() do
    Table.pop_all_goto()
    |> Enum.map(fn {{from, symbol, next}} -> {{from, decode_symbol(symbol)}, next} end)
    |> Table.store_goto()
  end

  def code_terminal(symbol) do
    Table.lookup_element_symbol(symbol)
    |> Bitwise.set_add(0)
  end

  def decode_terminals(bm) do
    case Table.lookup_action(bm) do
      :undefined ->
        symbols = decode_terminals(bm, 0)
        Table.store_action(bm, symbols)
        symbols

      symbols ->
        symbols
    end
  end

  def code_symbols(symbols) do
    Enum.map(symbols, &Table.lookup_element_symbol/1)
  end

  def decode_symbol(symbol) do
    Table.lookup_element_inverted_symbol(symbol)
  end

  defp decode_terminals(0, _), do: []

  defp decode_terminals(bm, i) do
    if Bitwise.set_member(i, bm) do
      [
        Table.lookup_element_inverted_symbol(i)
        | decode_terminals(Bitwise.set_delete(i, bm), i + 1)
      ]
    else
      decode_terminals(bm, i + 1)
    end
  end
end
