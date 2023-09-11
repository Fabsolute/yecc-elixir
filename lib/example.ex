defmodule Example do
  use Yecc

  root :list

  expect 1

  nonterminals [
    :list,
    :elems,
    :elem
  ]

  terminals [
    :"{",
    :"}",
    :",",
    :int,
    :atom
  ]

  defr list(:"{", :"}"), do: []
  defr list(:"{", {:elems, elems}, :"}"), do: elems

  defr elems({:elem, elem}), do: elem
  defr elems({:elem, elem}, :",", {:elems, elems}), do: [elem | elems]

  defr elem({:int, value}), do: extract_token(value)
  defr elem({:atom, value}), do: extract_token(value)
  defr elem({:list, value}), do: value

  defp extract_token({_token, _line, value}), do: value
end
