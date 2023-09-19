defmodule Yecc.Util.Item do
  defstruct look_ahead: nil, rule_pointer: nil, rhs: nil

  alias Yecc.Util.Table

  def state_items([{rule_pointer, look_ahead} | rest], items, id) do
    item = %__MODULE__{
      rule_pointer: rule_pointer,
      look_ahead: look_ahead,
      rhs: Table.get_rhs(rule_pointer)
    }

    state_items(rest, [item | items], [rule_pointer | id])
  end

  def state_items(_, items, id), do: {id, items}
end
