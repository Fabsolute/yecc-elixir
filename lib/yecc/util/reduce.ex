defmodule Yecc.Util.Reduce do
  defstruct rule_number: nil, head: nil, number_of_daughters: nil, precedence: nil

  def is(data) do
    is_struct(data, __MODULE__)
  end
end
