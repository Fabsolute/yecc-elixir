defmodule Yacc do
  def work do
    :ok
    |> states_and_goto_table
    |> parse_actions
    |> action_conflicts
    |> write_file
  end

  def states_and_goto_table(state) do
    state |> create_symbol_table() |> compute_states() |> create_precedence_table()
  end

  def parse_actions(_state) do
    :todo
  end

  def action_conflicts(_state) do
    :todo
  end

  def write_file(_state) do
    :todo
  end

  def create_symbol_table(state) do
    symbol_table = :ets.new(:yecc_symbols, [{:keypos, 1}])

    terminal_count =
      [:__empty__, :__end__ | :lists.delete(:__empty__, state.terminals)]
      |> count(0)

    nonterminal_count =
      state.nonterminals |> count(1) |> Enum.map(fn {nonterminal, i} -> {nonterminal, -i} end)

    counts = terminal_count ++ nonterminal_count
    true = :ets.insert(symbol_table, counts)

    inverted_symbol_table = :ets.new(:yecc_inverted_terminals, [{:keypos, 2}])
    true = :ets.insert(inverted_symbol_table, counts)

    state
    |> Map.put(:symbol_table, symbol_table)
    |> Map.put(:inverted_symbol_table, inverted_symbol_table)
  end

  def compute_states(state) do
    symbol_table = state.symbol_table

    coded_rules =
      Enum.map(state.rules_list, fn rule ->
        put_elem(rule, 1, code_symbols(elem(rule, 1), symbol_table))
      end)

    coded_nonterminals = code_symbols(state.nonterminals, symbol_table)

    state_current =
      state
      |> Map.put(:rules_list, coded_rules)
      |> Map.put(:rules, :erlang.list_to_tuple(coded_rules))
      |> Map.put(:nonterminals, coded_nonterminals)

    {rule_index, rule_pointer_to_rule} = make_rule_index(state_current, state.rules_list)

    state_table = {}
    state_id_table = :ets.new(:yecc_state_id, [:set])
    goto_table = :ets.new(:yecc_goto, [:bag])

    rule_pointer_rhs = make_rhs_index(state_current.rules_list)
    rule_pointer_info = make_rule_pointer_info(state_current, rule_pointer_rhs, rule_index)

    tables = %{
      :symbol => symbol_table,
      :state_id => state_id_table,
      :rp_rhs => rule_pointer_rhs,
      :rp_info => rule_pointer_info,
      :goto => goto_table
    }

    _ = :erlang.erase()

    end_symbol_code = code_terminal(:__end__, symbol_table)
    {state_id, state} = compute_state([{end_symbol_code, 1}], tables)

    state_num = 0
    first_state = {state_num, state}

    state_table = insert_state(tables, state_table, first_state, state_id)

    {state_table, n} =
      compute_states1([{state_num, get_current_symbols(state)}], first_state, state_table, tables)

    true = :ets.delete(state_id_table)

    state =
      state
      |> Map.put(:state_table, state_table)
      |> Map.put(:goto_table, goto_table)
      |> Map.put(:n_states, n)
      |> Map.put(:rule_pointer_to_rule, rule_pointer_to_rule)

    decode_goto(goto_table, state.inverted_symbol_table)
    check_usage(state)
  end

  defp compute_states1([], {n, _}, state_table, _) do
    {state_table, n}
  end

  defp compute_states1([{n, symbols} | rest], current_state, state_table, tables) do
    {_n, s} = elem(state_table, n)

    state_seeds(s, symbols)
    |> compute_states2(n, rest, current_state, state_table, tables)
  end

  defp compute_states2([], _n, rest, current_state, state_table, tables) do
    compute_states1(rest, current_state, state_table, tables)
  end

  defp compute_states2([{symbol, seed} | seeds], n, rest, current_state, state_table, tables) do
    {state_id, new_state} = compute_state(seed, tables)

    case check_states(new_state, state_id, state_table, tables) do
      :add ->
        {m, _} = current_state
        current_symbols = get_current_symbols(new_state)
        next = m + 1
        next_state = {next, new_state}
        new_state_table = insert_state(tables, state_table, next_state, state_id)
        insert_goto(tables, n, symbol, next)

        compute_states2(
          seeds,
          n,
          [{next, current_symbols} | rest],
          next_state,
          new_state_table,
          tables
        )

      {:old, m} ->
        insert_goto(tables, n, symbol, m)
        compute_states2(seeds, n, rest, current_state, state_table, tables)

      {:merge, m, new_current} ->
        rest =
          case :lists.keyfind(m, 1, rest) do
            false ->
              [{m, new_current} | rest]

            {_, old_current} ->
              if :ordsets.is_subset(new_current, old_current) do
                rest
              else
                [{m, :ordsets.union(new_current, old_current)} | :lists.keydelete(m, 1, rest)]
              end
          end

        new_state_table = merge_states(new_state, state_table, tables, m, state_id)
        insert_goto(tables, n, symbol, m)
        compute_states2(seeds, n, rest, current_state, new_state_table, tables)
    end
  end

  def create_precedence_table(state) do
  end

  defp make_rule_index(%{nonterminals: nonterminals, rules_list: rules_list}, rules_list_no_codes) do
    {rules_list, _n} =
      :lists.mapfoldl(
        fn {_, [nonterminal | daughters], _}, i ->
          new_i = i + length(daughters) + 1
          {{nonterminal, i}, new_i}
        end,
        1,
        rules_list
      )

    indexed_table = family_with_domain(rules_list, nonterminals)

    pointer_to_rule =
      Enum.flat_map(rules_list_no_codes, fn rule ->
        Enum.map(elem(rule, 1), &{&1, rule})
      end)
      |> count(1)
      |> Enum.map(fn {{_foo, rule}, i} -> {i, rule} end)

    {:maps.from_list(indexed_table), :maps.from_list(pointer_to_rule)}
  end

  defp count(list, from) do
    :lists.zip(list, :lists.seq(from, length(list) - 1 + from))
  end

  defp code_symbols(symbols, symbol_table) do
    Enum.map(symbols, &:ets.lookup_element(symbol_table, &1, 2))
  end

  defp make_rhs_index(rules_list) do
    rules_list
    |> Enum.flat_map(fn {_, [_, daughters], _} ->
      suffixes0(daughters)
    end)
    |> List.to_tuple()
  end

  defp make_rule_pointer_info(state, rule_pointer_rhs, rule_index) do
    symbol_table = state.symbol_table
    left_corner_table = make_left_corner_table(state)

    rule_pointer_rhs
    |> Tuple.to_list()
    |> Enum.map(&rp_info(&1, symbol_table, left_corner_table, rule_index))
    |> List.to_tuple()
  end

  defp code_terminal(symbol, symbol_table) do
    symbol_table
    |> :ets.lookup_element(symbol, 2)
    |> set_add(0)
  end

  defp compute_state(seed, tables) do
    rp_info_table = tables.rp_info
    Enum.each(seed, fn {look_ahead, rule_pointer} -> :erlang.put(rule_pointer, look_ahead) end)

    Enum.each(seed, fn {look_ahead, rule_pointer} ->
      compute_closure(look_ahead, rule_pointer, rp_info_table)
    end)

    :lists.keysort(1, :erlang.erase())
    |> state_items([], [], tables.rp_rhs)
  end

  defp insert_state(%{state_id: state_id_table}, state_table, state, state_id) do
    {n, _} = state
    insert_state_id(state_id_table, n, state_id)

    if tuple_size(state_table) > n do
      state_table
    else
      (Tuple.to_list(state_table) ++ :lists.duplicate(round(1 + n * 1.5), []))
      |> List.to_tuple()
    end
    |> put_elem(n + 1, state)
  end

  defp get_current_symbols(state) do
    state
    |> get_current_symbols([])
    |> Enum.sort()
  end

  defp get_current_symbols([], symbols), do: symbols

  defp get_current_symbols([%{rhs: rhs} | items], symbols) do
    case rhs do
      [] -> get_current_symbols(items, symbols)
      [symbol | _] -> get_current_symbols(items, [symbol | symbols])
    end
  end

  defp decode_goto(goto_table, inverted_symbol_table) do
    g = :ets.tab2list(goto_table)
    :ets.delete_all_objects(goto_table)

    :ets.insert(
      goto_table,
      Enum.map(g, fn {{from, symbol, next}} ->
        {{from, decode_symbol(symbol, inverted_symbol_table)}, next}
      end)
    )
  end

  defp check_usage(state) do
    sel_symbols = :ets.fun2ms(&elem(elem(&1, 0), 1))
    used_symbols = :ets.select(state.goto_table, sel_symbols)
    symbols = :ordsets.from_list([{}, :__empty__ | used_symbols])
    nonterminals = :ordsets.from_list(state.nonterminals)
    unused_nonterminals = :ordsets.to_list(:ordsets.subtract(nonterminals, symbols))

    defined_nonterminals =
      state.rules_list
      |> Enum.map(fn %{symbols: [name | _]} -> name end)
      |> :ordsets.from_list()

    undefined_nonterminals = :ordsets.subtract(nonterminals, defined_nonterminals)

    if :ordsets.size(:ordsets.subtract(undefined_nonterminals, unused_nonterminals)) > 0 do
      throw(:missing_syntax_rule)
    end
  end

  defp state_seeds(items, symbols) do
    l =
      Enum.map(items, fn %{rule_pointer: rule_pointer, look_ahead: look_ahead, rhs: [s | _]} ->
        {s, {look_ahead, rule_pointer + 1}}
      end)

    state_seeds1(:lists.keysort(1, l), symbols)
  end

  defp check_states(new_state, state_id, state_table, %{state_id: state_id_table}) do
    try do
      n = :ets.lookup_element(state_id_table, state_id, 2)
      {_n, old_state} = lookup_state(state_table, n)
      check_state1(new_state, old_state, [], n)
    catch
      _ -> :add
    end
  end

  defp insert_goto(tables, from, symbol, to) do
    true = :ets.insert(tables.goto, {{from, symbol, to}})
  end

  defp merge_states(new_state, state_table, tables, m, state_id) do
    {_m, old_state} = lookup_state(state_table, m)
    merged_state = merge_states1(new_state, old_state)
    insert_state(tables, state_table, {m, merged_state}, state_id)
  end

  defp family_with_domain(rule_list, nonterminals) do
    :sofs.relation(rule_list)
    |> sofs_family_with_domain(:sofs.set(nonterminals))
    |> :sofs.to_external()
  end

  defp sofs_family_with_domain(r, d) do
    r = :sofs.restriction(r, d)
    f = :sofs.relation_to_family(r)
    fd = :sofs.constant_function(d, :sofs.from_term([]))
    :sofs.family_union(f, fd)
  end

  defp suffixes0([0]) do
    [[], []]
  end

  defp suffixes0(l), do: suffixes(l)

  defp suffixes([] = l), do: [l]
  defp suffixes([_ | t] = l), do: [l | suffixes(t)]
end
