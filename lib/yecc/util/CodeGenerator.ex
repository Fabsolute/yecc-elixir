defmodule Yecc.Util.CodeGenerator do
  alias Yecc.Util.{Table, UserCode, Shift, Reduce,Rule, StateInfo}

  def output_actions(state_jumps, state_info) do
    call_list =
      for {_state, {actions, jump}} <- state_jumps,
          {_lookahead, %Shift{state: new_state}} <-
            actions ++
              (for {_tag, _to, part} <- [jump], action <- part do
                 action
               end) do
        new_state
      end

    call_set = :ordsets.from_list([0 | call_list])
    state_set = state_jumps |> Enum.map(&elem(&1, 0)) |> :ordsets.from_list()

    new_call_list =
      :ordsets.subtract(state_set, call_set)
      |> :ordsets.to_list()
      |> Enum.map(&{&1, false})

    call_list =
      call_set
      |> :ordsets.to_list()
      |> Enum.map(&{&1, true})

    (call_list ++ new_call_list)
    |> List.keysort(0)
    |> Enum.zip(state_jumps)
    |> Enum.filter(fn {{state, called}, {state, _jump_actions}} -> called end)
    |> Enum.map(&elem(elem(&1, 0), 0))
    |> Enum.map(fn state ->
      {^state, %StateInfo{state_repr: i_state}} = Enum.at(state_info, state)
      create_state_selection(state, i_state)
    end)
  end

  def output_goto([{_nonterminal, []} | goto_table], state_info) do
    output_goto(goto_table, state_info)
  end

  def output_goto([{nonterminal, list} | goto_table], state_info) do
    f = function_name(:yecc_goto, nonterminal)

    output_goto(list, f, state_info) ++
      output_goto(goto_table, state_info)
  end

  def output_goto([], _state_info), do: []

  def output_inlined([]), do: []

  def output_inlined([%UserCode{fun_name: inlined_function_name, action: reduce} | tail]) do
    %Reduce{rule_number: rule_number, number_of_daughters: number_of_daughters} = reduce

    %Rule{tokens: tokens} =
      Table.get_rule_pointer_to_rule(rule_number)



    quote do
      defp unquote(:"#{inlined_function_name}}")(__stack0) do

      end
    end

  end

  defp output_goto([{from, to} | tail], f, state_info) do
    {
      ^to,
      %StateInfo{
        reduce_only: reduce_only,
        state_repr: repr
      }
    } = Enum.at(state_info, to)

    [
      quote do
        defp unquote(:"#{f}")(unquote(from) = _s, cat, ss, stack, t, ts, tzr) do
          unquote(:"yecc_#{repr}")(
            if(unquote(reduce_only), do: _s, else: unquote(to)),
            cat,
            ss,
            stack,
            t,
            ts,
            tzr
          )
        end
      end
      | output_goto(tail, f, state_info)
    ]
  end

  defp output_goto([], _f, _state_info), do: []

  defp create_state_selection(state, i_state) do
    quote do
      defp yecc(unquote(:"yecc(#{state}") = state, cat, ss, stack, t, ts, tzr) do
        unquote(:"yecc_#{i_state}")(state, cat, ss, stack, t, ts, tzr)
      end
    end
  end

  defp function_name(name, suffix) do
    String.to_atom("#{name}_#{suffix}")
  end
end
