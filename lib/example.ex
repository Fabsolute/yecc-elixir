defmodule Example do
  use Yecc

  known_as left_bracket :'['
  known_as right_bracket :']'
  known_as comma :','

  nonterminals list elems elem
  terminals left_bracket right_bracket comma int atom ex_do doing done well_done
  root list

  left ex_do 5
  right doing 10
  nonassoc done 15
  unary well_done 20

  list ~> left_bracket right_bracket       do [] end
  list ~> left_bracket elems right_bracket do @2 end

  elems ~> elem           do [@1] end
  elems ~> elem comma elems do [@1 | @3] end

  elem ~> int  do extract_token(@1) end
  elem ~> atom do extract_token(@1) end
  elem ~> list do @1 end
  elem ~> ex_do do @1 end
  elem ~> doing do @1 end
  elem ~> done do @1 end
  elem ~> well_done do @1 end


  defp extract_token({_token, _line, value}), do: value

end
