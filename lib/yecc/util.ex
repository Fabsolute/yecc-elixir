defmodule Yecc.Util do
  alias Yecc.Util.{Table, States, Code, Action, Conflict, Generator}

  def replace_args(args) do
    {other, variables} = replace_args(args, MapSet.new())
    {other, MapSet.to_list(variables)}
  end

  defp replace_args([h | t], variables) do
    {h, variables} = replace_args(h, variables)
    {t, variables} = replace_args(t, variables)
    {[h | t], variables}
  end

  defp replace_args({:@, meta, [arg]}, variables) when is_number(arg) do
    {{:get, meta, [arg]}, MapSet.put(variables, arg)}
  end

  defp replace_args({name, meta, args}, variables) when is_list(args) do
    {args, variables} = replace_args(args, variables)
    {{name, meta, args}, variables}
  end

  defp replace_args(other, variables), do: {other, variables}

  def clear_context(do: context), do: clear_context(context)
  def clear_context({:__block__, _, args}), do: args
  def clear_context(rest), do: [rest]

  def parse_parameters(values), do: parse_parameters(values, 0)

  defp parse_parameters([{h, v} | t], index) when is_atom(h) do
    {values, parameters} = parse_parameters(t, index + 1)
    {[{index, v} | values], [h | parameters]}
  end

  defp parse_parameters([h | t], index) when is_atom(h) do
    {values, parameters} = parse_parameters(t, index + 1)
    {values, [h | parameters]}
  end

  defp parse_parameters([], _), do: {[], []}

  def create_symbol_table(module) do
    root = Module.get_attribute(module, :root)
    symbol_empty = Module.get_attribute(module, :symbol_empty)
    symbol_end = Module.get_attribute(module, :symbol_end)
    terminals = [symbol_empty, symbol_end | Module.get_attribute(module, :terminals) |> List.delete(symbol_empty)]
    nonterminals = Module.get_attribute(module, :nonterminals)

    tables =
      Enum.zip(terminals, 0..length(terminals)) ++
        Enum.zip(nonterminals, -1..-length(nonterminals))

    Table.store_symbols(tables)
    Table.store_instance_root(root)
  end

  def create_codeds(module) do
    rules = Module.get_attribute(module, :rules)
    nonterminals = Module.get_attribute(module, :nonterminals)

    Code.create_codeds(rules, nonterminals)
  end

  def compute_states(module) do
    rules = Module.get_attribute(module, :rules)
    end_symbol = Module.get_attribute(module, :symbol_end)
    States.compute_states(rules, end_symbol)
  end

  def create_precedence_table(module) do
    precedences = Module.get_attribute(module, :precedences)

    Table.store_precedences(precedences)
  end

  def compute_parse_actions(_) do
    Action.parse_actions()
  end

  def action_conflicts(_) do
    Conflict.action_conflicts()
  end

  def generate_functions(_) do
    Generator.generate_functions()
  end
end
