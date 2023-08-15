defmodule Yecc do
  alias Yecc.Util
  alias Yecc.Struct.Rule

  defmacro __using__(opts) do
    quote do
      @symbol_empty :__empty__
      @symbol_end :__end__
      @nonterminals []
      @terminals [@symbol_empty]

      @precedences []
      @rules []
      @expect 0

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Util.Table.initialize_tables()

    [
      &check_grammar/1,
      &prepare_attributes/1,
      &Util.create_symbol_table/1,
      &Util.create_codeds/1,
      &Util.compute_states/1,
      &Util.create_precedence_table/1,
      &Util.compute_parse_actions/1,
      &Util.action_conflicts/1,
      &Util.generate_functions/1
    ]
    |> Enum.each(& &1.(env.module))

    table_contents =
      [
        :symbol_table,
        :rule_pointer_to_rule,
        :codeds,
        :rule_pointer_rhs,
        :rule_pointer_info,
        :get_states,
        :parse_actions
      ]
      |> Enum.map(&{&1, Util.Table.get_content(&1)})

    contents =
      [:precedences, :root, :nonterminals, :terminals, :rules, :expect]
      |> Enum.map(&Module.get_attribute(env.module, &1))

    all_contents = (contents ++ table_contents) |> Macro.escape()

    quote do
      def parse(tokens) do
        {tokens, unquote(all_contents)}
      end

      def return_error(a, b) do
        quote do
          unquote(a ++ b)
        end
      end
    end
  end

  defmacro defr({name, _meta, parameters}, expr \\ nil) do
    {values, symbols} = Util.parse_parameters(parameters)
    values |> IO.inspect(label: :values)
    symbols |> IO.inspect(label: :symbols)

    expr  = Macro.escape(expr)

    quote do
      @rules @rules ++ [%Rule{symbols: [unquote(name) | unquote(symbols)], tokens: unquote(expr)}]
    end
  end

  defmacro root(name) do
    quote do
      @root unquote(name)
    end
  end

  defmacro expect(value) do
    quote do
      @expect unquote(value)
    end
  end

  defmacro nonterminals(names) do
    quote do
      @nonterminals @nonterminals ++ unquote(names)
    end
  end

  defmacro terminals(names) do
    quote do
      @terminals @terminals ++ unquote(names)
    end
  end

  for precedence_name <- [:right, :left, :nonassoc, :unary] do
    defmacro unquote(:"#{precedence_name}")(name, precedence) do
      precedence_name = unquote(precedence_name)
      quote do
        @precedences @precedences ++
                       [{unquote(name), unquote(precedence), unquote(precedence_name)}]
      end
    end
  end

  defp check_grammar(module) do
    root = Module.get_attribute(module, :root)
    nonterminals = Module.get_attribute(module, :nonterminals)
    terminals = Module.get_attribute(module, :terminals)
    rules = Module.get_attribute(module, :rules)
    precedences = Module.get_attribute(module, :precedences)

    cond do
      root == nil -> raise "root missing"
      nonterminals == [] -> raise "nonterminals missing"
      terminals == [] -> raise "terminals missing"
      rules == [] -> raise "rules missing"
      true -> :ok
    end

    all = terminals ++ nonterminals

    if all != Enum.uniq(all) do
      raise "terminals and nonterminals should be unique"
    end

    precedences = Enum.map(precedences, &elem(&1, 0))

    if precedences != Enum.uniq(precedences) do
      raise "precedences should be unique"
    end
  end

  defp prepare_attributes(module) do
    nonterminals = Module.get_attribute(module, :nonterminals) |> Enum.sort()
    terminals = Module.get_attribute(module, :terminals) |> Enum.sort()

    Module.put_attribute(module, :terminals, terminals)
    Module.put_attribute(module, :nonterminals, [{} | nonterminals])

    root = Module.get_attribute(module, :root)
    rules = Module.get_attribute(module, :rules)

    rules =
      [%Rule{symbols: [{}, root], tokens: []} | rules]
      |> Enum.with_index()
      |> Enum.map(fn {rule, index} -> %{rule | n: index} end)

    Module.put_attribute(module, :rules, rules)
  end
end
