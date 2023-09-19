defmodule Yecc.Util.UserCode do
  alias Yecc.Util.Reduce

  defstruct state: nil, terminal: nil, fun_name: nil, action: nil

  def find_user_code(parse_actions) do
    for {state, lookahead_actions} <- parse_actions,
        {action, terminals, rule_number, numbers_of_daughters} <-
          find_user_code2(lookahead_actions),
        terminal <- terminals do
      %__MODULE__{
        state: state,
        terminal: terminal,
        fun_name: inlined_function_name(state, terminal),
        action: action
      }
    end
  end

  defp find_user_code2([]), do: []

  defp find_user_code2([
         {
           _,
           %Reduce{rule_number: rule_number, number_of_daughters: number_of_daughters} = action
         }
       ]) do
    [{action, ["cat"], rule_number, number_of_daughters}]
  end

  defp find_user_code2([
         {lookahead,
          %Reduce{rule_number: rule_number, number_of_daughters: number_of_daughters} = action}
         | t
       ]) do
    [{action, lookahead, rule_number, number_of_daughters} | find_user_code2(t)]
  end

  defp find_user_code2([_ | t]), do: find_user_code2(t)

  defp inlined_function_name(state, terminal) do
    function_end = case terminal do
      "cat" -> ""
      _ -> Atom.to_string(terminal)
    end

    String.to_atom("yecc_#{state}_#{function_end}")
  end
end
