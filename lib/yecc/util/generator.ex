defmodule Yecc.Util.Generator do
  alias Yecc.Struct.{Reduce, Shift, StateInfo, PartData}
  alias Yecc.Util.{States, Table}

  def generate_functions() do
    parse_actions =
      Table.get_instance_parse_actions()
      |> sort_parse_actions()

    state_reprs =
      find_identical_shift_states(parse_actions)

    state_info = collect_some_state_info(parse_actions, state_reprs)
    state_jumps = find_partial_shift_states(parse_actions, state_reprs)
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

  defp collect_some_state_info(state_actions, state_reprs) do
    Enum.zip(state_actions, state_reprs)
    |> Enum.map(fn {{state, look_ahead_actions}, {state, repr}} ->
      {state,
       %StateInfo{
         reduce_only: Enum.all?(look_ahead_actions, &is_struct(elem(&1, 1), Reduce)),
         state_repr: repr
       }}
    end)
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
    state_action = :sofs.family_to_relation(state_actions)

    parts =
      :sofs.partition(:sofs.range(state_actions))
      |> :sofs.to_external()

    part_name_list = Enum.with_index(parts, fn element, index -> {index + 1, element} end)

    part_in_states =
      Enum.flat_map(part_name_list, fn {part_name, actions} ->
        Enum.map(actions, &{&1, part_name})
      end)
      |> :sofs.relation([{:action, :part_name}])
      |> then(&:sofs.relative_product(state_action, &1))
      |> :sofs.converse()
      |> :sofs.relation_to_family()
      |> :sofs.to_external()

    part_actions = :sofs.family(part_name_list, [{:partname, [:action]}])

    part_states =
      state_actions
      |> :sofs.converse()
      |> then(&:sofs.relative_product(part_actions, &1))
      |> States.sofs_family_with_domain(:sofs.domain(part_actions))
      |> :sofs.to_external()

    parts_selected =
      List.zip([part_name_list, part_in_states, part_states])
      |> Enum.map(fn {{name, actions}, {name, states}, {name, eq_state}} ->
        %PartData{
          name: name,
          eq_state: eq_state,
          actions: actions,
          n_actions: length(actions),
          states: :ordsets.from_list(states)
        }
      end)
      |> select_parts()

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

  defp select_parts([]), do: []

  defp select_parts(part_data_list) do
    [{weight, part_data} | ws] =
      part_data_list
      |> Enum.map(&{score(&1), &1})
      |> List.keysort(0)
      |> Enum.reverse()

    %PartData{n_actions: n_actions, states: states} = part_data

    if weight < 8 do
      []
    else
      for {w1, %PartData{states: states0} = d} <- ws,
          w1 > 0,
          (new_states = :ordsets.subtract(states0, states)) != [] do
        %{d | states: new_states}
      end
      |> select_parts()
      |> then(
        &if length(states) == 1 or n_actions == 1 do
          &1
        else
          [{weight, part_data} | &1]
        end
      )
    end
  end

  # %% Does it pay off to extract clauses into a new function?
  # %% Assumptions:
  # %% - a call costs 8 (C = 8);
  # %% - a clause (per action) costs 20 plus 8 (select) (Cl = 28);
  # %% - a new function costs 20 (funinfo) plus 16 (select) (F = 36).
  # %% A is number of actions, S is number of states.
  # %% Special case (the part equals all actions of some state):
  # %% C * (S - 1) < (S - 1) * A * Cl
  # %% Normal case (introduce new function):
  # %% F + A * Cl + C * S < S * A * Cl
  defp score(%PartData{states: states, n_actions: n_actions, eq_state: eq_state}) do
    (length(states) - 1) * n_actions * 28 - length(states) * 8 -
      if eq_state == [] do
        36
      else
        -8
      end
  end
end
