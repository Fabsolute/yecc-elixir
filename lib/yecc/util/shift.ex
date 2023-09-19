defmodule Yecc.Util.Shift do
  defstruct state: nil, pos: nil, precedence: nil, rule_number: nil

  def is(data) do
    is_struct(data, __MODULE__)
  end
end
