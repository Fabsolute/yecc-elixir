defmodule Yecc.Util.StateInfo do
  alias Yecc.Util.Reduce

  defstruct reduce_only: nil, state_repr: nil

  def collect_some_state_info(state_actions, state_reprs) do
    Enum.zip(state_actions, state_reprs)
    |> Enum.map(fn {{state, look_ahead_actions}, {state, repr}} ->
      {state,
        %__MODULE__{
          reduce_only: Enum.all?(look_ahead_actions, &Reduce.is(elem(&1, 1))),
          state_repr: repr
        }}
    end)
  end
end
