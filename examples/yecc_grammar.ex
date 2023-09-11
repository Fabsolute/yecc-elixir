defmodule YeccGrammar do
  use Yecc

  root :grammar

  nonterminals [
    :grammar,
    :declaration,
    :rule,
    :head,
    :symbol,
    :symbols,
    :strings,
    :attached_code,
    :token,
    :tokens
  ]

  terminals [
    :atom,
    :float,
    :integer,
    :reserved_symbol,
    :reserved_word,
    :string,
    :char,
    :var,
    :right_arrow,
    :colon,
    :dot
  ]

  defr grammar({:declaration, declaration}), do: declaration
  defr grammar({:rule, rule}), do: rule

  defr declaration({:symbol, symbol}, {:symbols, symbols}, :dot), do: {symbol, symbols}
  defr declaration({:symbol, symbol}, {:strings, strings}, :dot), do: {symbol, strings}

  defr rule(
         {:head, head},
         :right_arrow,
         {:symbols, symbols},
         {:attached_code, attached_code},
         :dot
       ) do
    {:rule, [head | symbols], attached_code}
  end

  defr head({:symbol, symbol}), do: symbol

  defr symbols({:symbol, symbol}), do: [symbol]
  defr symbols({:symbol, symbol}, {:symbols, symbols}), do: [symbol | symbols]

  defr strings({:string, string}), do: [string]
  defr strings({:string, string}, {:strings, strings}), do: [string | strings]

  defr attached_code(:colon, {:tokens, tokens}), do: {:erlang_code, tokens}

  defr attached_code(:__empty__) do
    {:erlang_code,
     [
       {
         :atom,
         :erl_anno.set_text(~c"__undefined__", :erl_anno.new(0)),
         :__undefined__
       }
     ]}
  end

  defr tokens({:token, token}), do: [token]
  defr tokens({:token, token}, {:tokens, tokens}), do: [token | tokens]

  defr symbol({:var, var}), do: symbol(var)
  defr symbol({:atom, atom}), do: symbol(atom)
  defr symbol({:integer, integer}), do: symbol(integer)
  defr symbol({:reserved_word, reserved_word}), do: symbol(reserved_word)

  defr token({:var, var}), do: var
  defr token({:atom, atom}), do: atom
  defr token({:float, float}), do: float
  defr token({:integer, integer}), do: integer
  defr token({:string, string}), do: string
  defr token({:char, char}), do: char

  defr token({:reserved_symbol, reserved_symbol}) do
    {value_of(reserved_symbol), anno_of(reserved_symbol)}
  end

  defr token({:reserved_word, reserved_word}) do
    {value_of(reserved_word), anno_of(reserved_word)}
  end

  # Have to be treated in this
  defr token({:right_arrow, right_arrow}), do: {:right_arrow, anno_of(right_arrow)}
  # manner, because they are also special symbols of the metagrammar
  defr token({:comma, comma}), do: {:comma, anno_of(comma)}

  defp symbol(symbol) do
    YeccGrammar.Symbol.new(value_of(symbol), anno_of(symbol))
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
