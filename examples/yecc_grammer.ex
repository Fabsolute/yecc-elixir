defmodule YeccGrammer do
  use Yecc

  root grammar

  nonterminals do
    grammar declaration rule head symbol symbols strings attached_code
    token tokens
  end

  terminals do
    atom float integer reserved_symbol reserved_word string char var
    right_arrow colon dot
  end

  grammar ~> declaration do @1 end
  grammar ~> rule do @1 end

  declaration ~> symbol symbols dot do {@1, @2} end
  declaration ~> symbol strings dot do {@1, @2} end

  rule ~> head right_arrow symbols attached_code dot do {:rule, [@1 | @3], @4} end

  head ~> symbol do @1 end

  symbols ~> symbol do [@1] end
  symbols ~> symbol symbols do [@1 | @2] end

  strings ~> string do [@1] end
  strings ~> string strings do [@1 | @2] end

  attached_code ~> colon tokens do {:erlang_code, @2} end
  attached_code ~> __empty__ do
     {:erlang_code,[{
        :atom,
        :erl_anno.set_text('__undefined__', :erl_anno.new(0)),
        __undefined__
        }]}
  end

  tokens ~> token do [@1] end
  tokens ~> token tokens do [@1 | @2] end

  symbol ~> var do symbol(@1) end
  symbol ~> atom do symbol(@1) end
  symbol ~> integer do symbol(@1) end
  symbol ~> reserved_word do symbol(@1) end

  token ~> var do @1 end
  token ~> atom do @1 end
  token ~> float do @1 end
  token ~> integer do @1 end
  token ~> string do @1 end
  token ~> char do @1 end
  token ~> reserved_symbol do {value_of(@1), anno_of(@1)} end
  token ~> reserved_word do {value_of(@1), anno_of(@1)} end
  token ~> right_arrow do {:right_arrow, anno_of(@1)} end # Have to be treated in this
  token ~> comma do {:comma, anno_of(@1)} end   # manner, because they are also special symbols of the metagrammar

  defp symbol(symbol) do
    YeccGrammer.Symbol.new(value_of(symbol),anno_of(symbol))
  end

  defp value_of(token) do
    :erlang.element(3, token)
  end

  defp anno_of(token) do
    :erlang.element(2, token)
  end

  defmodule Symbol do
      defstruct anno: nil, name: nil

      def new(name, anno) do
        %__MODULE__{anno: anno, name: name}
      end
  end
end
