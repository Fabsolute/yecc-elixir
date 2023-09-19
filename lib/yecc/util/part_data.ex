defmodule Yecc.Util.PartData do
  defstruct name: nil, eq_state: nil, actions: nil, n_actions: nil, states: nil

  alias Yecc.Util.States

  def select_part_data(state_actions) do
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

      List.zip([part_name_list, part_in_states, part_states])
      |> Enum.map(fn {{name, actions}, {name, states}, {name, eq_state}} ->
        %__MODULE__{
          name: name,
          eq_state: eq_state,
          actions: actions,
          n_actions: length(actions),
          states: :ordsets.from_list(states)
        }
      end)
      |> select_parts()
  end

  defp select_parts([]), do: []

  defp select_parts(part_data_list) do
    [{weight, part_data} | ws] =
      part_data_list
      |> Enum.map(&{score(&1), &1})
      |> List.keysort(0)
      |> Enum.reverse()

    %__MODULE__{n_actions: n_actions, states: states} = part_data

    if weight < 8 do
      []
    else
      for {w1, %__MODULE__{states: states0} = d} <- ws,
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
  defp score(%__MODULE__{states: states, n_actions: n_actions, eq_state: eq_state}) do
    (length(states) - 1) * n_actions * 28 - length(states) * 8 -
      if eq_state == [] do
        36
      else
        -8
      end
  end
end
