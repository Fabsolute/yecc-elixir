defmodule Yecc.Util.Conflict do
  alias Yecc.Util.{Table, States, Action, Shift, Reduce, Ctx}

  def action_conflicts() do
    {_, actions} =
      Table.get_instance_parse_actions()
      |> List.foldl({%Ctx{}, []}, fn {n, actions}, {ctx, state_actions} ->
        {ctx, actions} =
          Enum.flat_map(actions, fn {look_ahead, action} ->
            Enum.map(look_ahead, &{&1, action})
          end)
          |> States.family()
          |> List.foldl({ctx, []}, fn {terminal, as}, {ctx, acts} ->
            ctx = %{ctx | terminal: terminal, state_n: n}
            {action, ctx} = action_conflicts(as |> dbg, ctx)
            {ctx, [{action, terminal} | acts]}
          end)

        {ctx, [{n, actions |> States.family() |> inverse()} | state_actions]}
      end)

    actions
    |> Enum.reverse()
    |> Table.store_instance_parse_actions()
  end

  defp action_conflicts([action], ctx), do: {action, ctx}

  defp action_conflicts(
         [
           %Shift{state: state, pos: pos, precedence: precedence},
           %Shift{state: state} = shift | as
         ],
         ctx
       )
       when pos == :a and precedence == {0, :none} do
    action_conflicts([shift | as], ctx)
  end

  defp action_conflicts(
         [%Shift{state: new_state, pos: :z} = shift_1, %Shift{state: new_state} = shift_2 | _],
         ctx
       ) do
    conflict = conflict(shift_1, shift_2, ctx)
    add_conflict(conflict)
    {shift_1, ctx}
  end

  defp action_conflicts([%Shift{precedence: {p1, ass1}} = shift | rest], ctx) do
    {reduce, ctx} = find_reduce_reduce(rest, ctx)

    res = ctx.rest
    {p2, ass2} = reduce.precedence
    conflict = conflict(reduce, shift, ctx)

    cond do
      p1 > p2 ->
        {shift, %{ctx | res: [{conflict, :shift} | res]}}

      p2 > p1 ->
        {reduce, %{ctx | res: [{conflict, :reduce} | res]}}

      ass1 == :left and ass2 == :left ->
        {reduce, %{ctx | res: [{conflict, :reduce} | res]}}

      ass1 == :right and ass2 == :right ->
        {shift, %{ctx | res: [{conflict, :shift} | res]}}

      ass1 == :nonassoc and ass2 == :nonassoc ->
        {:nonassoc, ctx}

      p1 == 0 and p2 == 0 ->
        add_conflict(conflict)
        {shift, ctx}

      true ->
        add_conflict(conflict)
        {shift, ctx}
    end
  end

  defp action_conflicts(rs, ctx) do
    find_reduce_reduce(rs, ctx)
  end

  defp find_reduce_reduce([reduce], ctx), do: {reduce, ctx}

  defp find_reduce_reduce([:accept, %Reduce{} = reduce | rest], ctx) do
    conflict = conflict(reduce, :accept, ctx)
    add_conflict(conflict)
    find_reduce_reduce([reduce | rest], ctx)
  end

  defp find_reduce_reduce(
         [
           %Reduce{head: category_1, precedence: {p1}} = reduce_1,
           %Reduce{head: category_2, precedence: {p2, _}} = reduce_2 | rest
         ],
         ctx
       ) do
    res = ctx.res
    conflict = conflict(reduce_1, reduce_2, ctx)

    {reduce, res} =
      cond do
        p1 > p2 ->
          {reduce_1, [{conflict, category_1} | res]}

        p2 > p1 ->
          {reduce_2, [{conflict, category_2} | res]}

        true ->
          add_conflict(conflict)
          {reduce_1, res}
      end

    ctx = %{ctx | res: res}
    find_reduce_reduce([reduce | rest], ctx)
  end

  defp inverse(list) do
    list
    |> Enum.map(fn {a, b} -> {b, a} end)
    |> Enum.sort()
  end

  defp conflict(
         %Shift{precedence: precedence_1, rule_number: rule_number_1},
         %Shift{precedence: precedence_2, rule_number: rule_number_2},
         ctx
       ) do
    %Ctx{terminal: symbol, state_n: n} = ctx
    {_, rule_number_1} = Action.rule(rule_number_1)
    {_, rule_number_2} = Action.rule(rule_number_2)

    conflict = {:one_level_up, {rule_number_1, precedence_1}, {rule_number_2, precedence_2}}

    {symbol, n, conflict, conflict}
  end

  defp conflict(%Reduce{rule_number: rule_number_1}, new_action, ctx) do
    %Ctx{terminal: symbol, state_n: n} = ctx
    {reduce_1, rule_number_1} = Action.rule(rule_number_1)

    conflict =
      case new_action do
        :accept ->
          {:accept, Table.get_table_instance_root()}

        %Reduce{rule_number: rule_number_2} ->
          {reduce_2, rule_number_2} = Action.rule(rule_number_2)
          {:reduce, reduce_2, rule_number_2}

        %Shift{state: new_state} ->
          {:shift, new_state, List.last(reduce_1)}
      end

    {symbol, n, {reduce_1, rule_number_1}, conflict}
  end

  defp add_conflict(conflict) do
    case conflict do
      {symbol, state_n, _, {:reduce, _, _}} ->
        Table.store_reduce_reduce(state_n, symbol)

      {symbol, state_n, _, {:accept, _}} ->
        Table.store_reduce_reduce(state_n, symbol)

      {symbol, state_n, _, {:shift, _, _}} ->
        Table.store_shift_reduce(state_n, symbol)

      {_, _, {:one_level_up, _, _}, _} ->
        nil
    end
  end
end
