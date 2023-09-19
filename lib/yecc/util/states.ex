defmodule Yecc.Util.States do
  alias Yecc.Util.{Table, Bitwise, Code, Item, Rule}

  def compute_states(rules, end_symbol) do
    coded_rules = Table.get_coded(:rules)
    coded_nonterminals = Table.get_coded(:nonterminals)
    Table.store_rule_pointer_to_rule(make_rule_pointer_to_rule(rules))
    Table.store_rhs(make_rhs_index(coded_rules))
    Table.store_info(make_rule_pointer_info(coded_rules, coded_nonterminals))

    end_symbol_code = Code.code_terminal(end_symbol)

    {state_id, state} = compute_state([{end_symbol_code, 1}])

    first_state = {0, state}

    state_table = insert_state({}, first_state, state_id)

    {state_table, n} =
      compute_states1([{0, get_current_symbols(state)}], first_state, state_table)

    Table.delete_state_id()
    Table.store_instance_n(n)
    Table.store_instance_state_table(state_table)

    Code.decode_goto()
  end

  def is_terminal?(element) when is_integer(element), do: element >= 0

  def family(list) do
    list
    |> :sofs.relation()
    |> :sofs.relation_to_family()
    |> :sofs.to_external()
  end

  def sofs_family_with_domain(relations, domain) do
    domain_function = :sofs.constant_function(domain, :sofs.from_term([]))

    :sofs.restriction(relations, domain)
    |> :sofs.relation_to_family()
    |> :sofs.family_union(domain_function)
  end

  defp lookup_state(state_table, n) do
    elem(state_table, n)
  end

  defp make_rule_pointer_info(rules, nonterminals) do
    rule_index = make_indexed_table(rules, nonterminals)
    left_corner_table = make_left_corner_table(rules, nonterminals)

    Table.get_rhs()
    |> Tuple.to_list()
    |> Enum.map(&rule_pointer_info(&1, left_corner_table, rule_index))
    |> List.to_tuple()
  end

  defp rule_pointer_info([], _, _), do: []

  defp rule_pointer_info([category | followers], left_corner_table, rule_index) do
    case Map.get(rule_index, category) do
      nil ->
        []

      expanding_rules when followers == [] ->
        expanding_rules

      expanding_rules ->
        case make_look_ahead(followers, left_corner_table, 0) do
          {:empty, look_ahead} -> {:union, expanding_rules, look_ahead}
          look_ahead -> {:no_union, expanding_rules, look_ahead}
        end
    end
  end

  defp make_look_ahead([], _, look_ahead), do: {:empty, look_ahead}

  defp make_look_ahead([symbol | symbols], left_corner_table, look_ahead) do
    case Map.get(left_corner_table, symbol) do
      nil ->
        Bitwise.set_add(symbol, look_ahead)

      left_corner ->
        if Bitwise.empty_member(left_corner) do
          make_look_ahead(
            symbols,
            left_corner_table,
            Bitwise.set_union(Bitwise.empty_delete(left_corner), look_ahead)
          )
        else
          Bitwise.set_union(left_corner, look_ahead)
        end
    end
  end

  defp make_left_corner_table(rules, nonterminals) do
    rules = rules |> Enum.map(fn %Rule{symbols: [lhs | rhs]} -> {lhs, {lhs, rhs}} end)
    left_hand_table = rules |> family() |> Map.new()

    xl =
      Enum.flat_map(rules, fn {head, {head, rhs}} ->
        Enum.reject(rhs, &is_terminal?/1) |> Enum.map(&{&1, head})
      end)
      |> family_with_domain(nonterminals)

    x = Map.new(xl)
    xref = fn nt -> Map.get(x, nt) end

    left_corner = xl |> Enum.map(&{elem(&1, 0), 0}) |> Map.new()

    {q, left_corner} =
      rules
      |> List.foldl({[], left_corner}, fn {head, {head, [symbol | _]}}, {q, left_corner} ->
        case Table.lookup_inverted_symbol(symbol) do
          {_, num} when num > 0 ->
            {[xref.(head) | q], Bitwise.set_add(num, 0) |> upd_first(head, left_corner)}

          _ ->
            {q, left_corner}
        end
      end)

    left_corners(q, left_corner, left_hand_table, xref)
  end

  defp left_corners(q, left_corner, left_hand_table, xref) do
    case Enum.concat(q) |> Enum.sort() |> Enum.dedup() do
      [] ->
        left_corner

      q ->
        {left_corner, q} =
          q
          |> Enum.flat_map(&Map.get(left_hand_table, &1))
          |> left_corners_2(left_corner, [], xref)

        left_corners(q, left_corner, left_hand_table, xref)
    end
  end

  defp left_corners_2([], left_corner, q, _), do: {left_corner, q}

  defp left_corners_2([{head, rhs} | rest], left_corner, q, xref) do
    ts = left_corner_rhs(rhs, head, left_corner, 0)
    first = Map.get(left_corner, head)

    if Bitwise.set_is_subset(ts, first) do
      left_corners_2(rest, left_corner, q, xref)
    else
      left_corner = upd_first(ts, head, left_corner)
      left_corners_2(rest, left_corner, [xref.(head) | q], xref)
    end
  end

  defp left_corner_rhs([symbol | rest], head, left_corner, ts) do
    case Table.lookup_inverted_symbol(symbol) do
      {_, num} when num >= 0 ->
        Bitwise.set_add(num, ts)

      _ ->
        first = Map.get(left_corner, symbol)

        if Bitwise.empty_member(first) do
          ts = first |> Bitwise.empty_delete() |> Bitwise.set_union(ts)
          left_corner_rhs(rest, head, left_corner, ts)
        else
          Bitwise.set_union(first, ts)
        end
    end
  end

  defp left_corner_rhs([], _, _, ts), do: Bitwise.set_add(0, ts)

  defp make_indexed_table(rules, nonterminals) do
    {rules, _} =
      List.foldl(rules, {[], 1}, fn %Rule{symbols: [nonterminal | daughters]}, {map, i} ->
        {map ++ [{nonterminal, i}], i + length(daughters) + 1}
      end)

    family_with_domain(rules, nonterminals)
    |> Map.new()
  end

  defp make_rhs_index(rules) do
    rules
    |> Enum.flat_map(&(&1.symbols |> tl() |> suffixes(:check_empty)))
    |> List.to_tuple()
  end

  defp make_rule_pointer_to_rule(rules) do
    symbol2rule = Enum.flat_map(rules, &List.duplicate(&1, length(&1.symbols)))
    Enum.zip(1..length(symbol2rule), symbol2rule)
  end

  defp insert_state(state_table, {n, _} = state, state_id) do
    insert_state_id(n, state_id)

    if tuple_size(state_table) > n do
      state_table
    else
      ((state_table |> Tuple.to_list()) ++ List.duplicate([], round(1 + n * 1.5)))
      |> List.to_tuple()
    end
    |> put_elem(n, state)
  end

  defp insert_state_id(n, state_id) do
    Table.store_state_id({state_id, n})
  end

  defp compute_states1([], {n, _}, state_table), do: {state_table, n}

  defp compute_states1(
         [{n, symbols} | rest],
         current_state,
         state_table
       ) do
    {_, s} = lookup_state(state_table, n)

    state_seeds(s, symbols)
    |> compute_states2(
      n,
      rest,
      current_state,
      state_table
    )
  end

  defp compute_states2(
         [],
         _,
         rest,
         current_state,
         state_table
       ) do
    compute_states1(
      rest,
      current_state,
      state_table
    )
  end

  defp compute_states2(
         [{symbol, seed} | seeds],
         n,
         rest,
         current_state,
         state_table
       ) do
    {state_id, new_state} = compute_state(seed)

    case check_states(new_state, state_id, state_table) do
      :add ->
        {m, _} = current_state
        current_symbols = get_current_symbols(new_state)
        next = m + 1
        next_state = {next, new_state}

        new_state_table = insert_state(state_table, next_state, state_id)

        insert_goto(n, symbol, next)

        compute_states2(
          seeds,
          n,
          [{next, current_symbols} | rest],
          next_state,
          new_state_table
        )

      {:old, m} ->
        insert_goto(n, symbol, m)

        compute_states2(
          seeds,
          n,
          rest,
          current_state,
          state_table
        )

      {:merge, m, new_current} ->
        rest =
          case List.keyfind(rest, m, 0) do
            nil ->
              [{m, new_current} | rest]

            {_, old_current} ->
              if :ordsets.is_subset(new_current, old_current) do
                rest
              else
                [{m, :ordsets.union(new_current, old_current)} | List.keydelete(rest, m, 0)]
              end
          end

        new_state_table = merge_states(new_state, state_table, m, state_id)
        insert_goto(n, symbol, m)

        compute_states2(
          seeds,
          n,
          rest,
          current_state,
          new_state_table
        )
    end
  end

  defp compute_closure(look_ahead, rule_pointer) do
    case Table.get_info(rule_pointer) do
      [] = void ->
        void

      {:no_union, expanding_rules, new_look_ahead} ->
        compute_closure1(expanding_rules, new_look_ahead)

      {:union, expanding_rules, look_ahead_1} ->
        new_look_ahead = Bitwise.set_union(look_ahead, look_ahead_1)
        compute_closure1(expanding_rules, new_look_ahead)

      expanding_rules ->
        compute_closure1(expanding_rules, look_ahead)
    end
  end

  defp compute_closure1([rule_pointer | tail], new_look_ahead) do
    compute_closure1(tail, new_look_ahead)

    case Table.get_closure(rule_pointer) do
      nil ->
        Table.store_closure(rule_pointer, new_look_ahead)
        compute_closure(new_look_ahead, rule_pointer)

      look_ahead_2 ->
        look_ahead = Bitwise.set_union(look_ahead_2, new_look_ahead)

        if look_ahead == look_ahead_2 do
          # void
          look_ahead_2
        else
          Table.store_closure(rule_pointer, look_ahead)
          compute_closure(new_look_ahead, rule_pointer)
        end
    end
  end

  defp compute_closure1(null, _), do: null

  defp compute_state(seed) do
    for {look_ahead, rule_pointer} <- seed do
      Table.store_closure(rule_pointer, look_ahead)
    end

    for {look_ahead, rule_pointer} <- seed do
      compute_closure(look_ahead, rule_pointer)
    end

    Table.pop_closure()
    |> Item.state_items([], [])
  end

  defp state_seeds(items, symbols) do
    for %Item{rule_pointer: rule_pointer, look_ahead: look_ahead, rhs: [s | _]} <- items do
      {s, {look_ahead, rule_pointer + 1}}
    end
    |> List.keysort(0)
    |> state_seeds1(symbols)
  end

  defp state_seeds1(_, []), do: []
  defp state_seeds1(list, [symbol | symbols]), do: state_seeds(list, symbol, symbols, [])

  defp state_seeds([{symbol, item} | list], symbol, symbols, items) do
    state_seeds(list, symbol, symbols, [item | items])
  end

  defp state_seeds([{s, _} | list], symbol, symbols, items) when s < symbol do
    state_seeds(list, symbol, symbols, items)
  end

  defp state_seeds(list, symbol, symbols, items) do
    [{symbol, items} | state_seeds1(list, symbols)]
  end

  defp get_current_symbols(state) do
    state
    |> get_current_symbols1([])
    |> Enum.sort()
    |> Enum.dedup()
  end

  defp get_current_symbols1([], symbols), do: symbols

  defp get_current_symbols1([%Item{rhs: rhs} | items], symbols) do
    case rhs do
      [] -> get_current_symbols1(items, symbols)
      [symbol | _] -> get_current_symbols1(items, [symbol | symbols])
    end
  end

  defp check_states(new_state, state_id, state_table) do
    try do
      n = Table.lookup_element_state_id(state_id)
      {_, old_state} = lookup_state(state_table, n)
      check_state1(new_state, old_state, [], n)
    rescue
      _ -> :add
    end
  end

  defp check_state1(
         [%Item{look_ahead: look_ahead_1, rhs: rhs} | items_1],
         [%Item{look_ahead: look_ahead_2} | items_2],
         symbols,
         n
       ) do
    if Bitwise.set_is_subset(look_ahead_1, look_ahead_2) do
      check_state1(items_1, items_2, symbols, n)
    else
      case rhs do
        [] -> check_state2(items_1, items_2, symbols, n)
        [symbol | _] -> check_state2(items_1, items_2, [symbol | symbols], n)
      end
    end
  end

  defp check_state1([], [], _, n), do: {:old, n}

  defp check_state2(
         [%Item{look_ahead: look_ahead_1, rhs: rhs} | items_1],
         [%Item{look_ahead: look_ahead_2} | items_2],
         symbols,
         n
       ) do
    if Bitwise.set_is_subset(look_ahead_1, look_ahead_2) do
      check_state2(items_1, items_2, symbols, n)
    else
      case rhs do
        [] -> check_state2(items_1, items_2, symbols, n)
        [symbol | _] -> check_state2(items_1, items_2, [symbol | symbols], n)
      end
    end
  end

  defp check_state2([], [], symbols, n), do: {:merge, n, symbols |> Enum.sort() |> Enum.dedup()}

  defp merge_states(new_state, state_table, m, state_id) do
    {_, old_state} = lookup_state(state_table, m)
    merged_state = merge_states1(new_state, old_state)
    insert_state(state_table, {m, merged_state}, state_id)
  end

  defp merge_states1([item_1 | items_1], [item_2 | items_2]) do
    look_ahead_1 = item_1.look_ahead
    look_ahead_2 = item_2.look_ahead

    item =
      if look_ahead_1 == look_ahead_2 do
        item_1
      else
        %{item_1 | look_ahead: Bitwise.set_union(look_ahead_1, look_ahead_2)}
      end

    [item | merge_states1(items_1, items_2)]
  end

  defp merge_states1(_, _), do: []

  defp insert_goto(from, symbol, to) do
    Table.store_goto({{from, symbol, to}})
  end

  defp family_with_domain(list, domain) do
    list
    |> :sofs.relation()
    |> sofs_family_with_domain(:sofs.set(domain))
    |> :sofs.to_external()
  end

  defp suffixes([0], :check_empty), do: [[], []]
  defp suffixes([], _), do: [[]]
  defp suffixes([_ | t] = l, _), do: [l | suffixes(t, :ok)]

  defp upd_first(ts, nt, left_corner) do
    Map.update!(left_corner, nt, &Bitwise.set_union(&1, ts))
  end
end
