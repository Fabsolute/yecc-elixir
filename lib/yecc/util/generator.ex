defmodule Yecc.Util.Generator do
  alias Yecc.Util.{States, Table, UserCode, StateInfo, PartData, Shift, Reduce}

  def generate_functions() do
    parse_actions =
      Table.get_instance_parse_actions()
      |> sort_parse_actions()

    state_reprs =
      find_identical_shift_states(parse_actions)

    state_info = StateInfo.collect_some_state_info(parse_actions, state_reprs)
    state_jumps = find_partial_shift_states(parse_actions, state_reprs)

    user_code_actions =
      UserCode.find_user_code(parse_actions)
      |> dbg()
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
      &Shift.is/1,
      &Reduce.is/1,
      &(&1 == :non_assoc)
    ]
    |> Enum.flat_map(
      &Enum.filter(look_ahead_actions, fn action ->
        action |> elem(1) |> &1.()
      end)
    )
  end

  defp find_identical_shift_states(state_actions) do
    state_actions
    |> Enum.map(fn {state, actions} -> {actions, state} end)
    |> States.family()
    |> Enum.flat_map(fn {actions, states} ->
      Enum.map(
        states,
        &{&1,
         if shift_actions_only(actions) do
           hd(states)
         else
           &1
         end}
      )
    end)
    |> List.keysort(0)
  end

  defp shift_actions_only(actions) do
    Enum.count(actions, fn
      {_, %Shift{}} -> true
      _ -> false
    end) == length(actions)
  end

  defp find_partial_shift_states(state_action_list, state_reprs) do
    list =
      Enum.zip(state_action_list, state_reprs)
      |> Enum.filter(fn
        {{state, actions}, {state, state}} -> shift_actions_only(actions)
        _ -> false
      end)
      |> Enum.map(&elem(&1, 0))

    state_actions = :sofs.family(list, [{:state, [:action]}])
    parts_selected = PartData.select_part_data(state_actions)

    jump_list_1 =
      for {_, %PartData{actions: actions, eq_state: [], states: states}} <- parts_selected,
          state <- states do
        {state, actions, {:jump_some, hd(states)}}
      end

    jump_list_2 =
      for {_, %PartData{actions: actions, eq_state: eq_state, states: states}} <- parts_selected,
          to <- eq_state,
          state <- states,
          state != to do
        {state, actions, {:jump_all, to}}
      end

    jump_list = List.keysort(jump_list_1 ++ jump_list_2, 0)

    {js, njs} =
      jump_list
      |> Enum.map(&elem(&1, 0))
      |> :ordsets.from_list()
      |> :sofs.set([:state])
      |> then(
        &:sofs.partition(
          1,
          :sofs.relation(state_action_list, [{:state, :actions}]),
          &1
        )
      )

    (for {s, actions} <- :sofs.to_external(njs) do
       {s, {actions, :jump_none}}
     end ++
       for {{s, actions}, {s, part, {tag, to}}} <-
             js |> :sofs.to_external() |> Enum.zip(jump_list) do
         {s, {actions -- part, {tag, to, part}}}
       end)
    |> List.keysort(0)
  end
end
