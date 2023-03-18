defmodule ElixirParser do
  use Yecc

  root grammar

  # Two shift/reduce conflicts coming from call_args_parens and
  # one coming from empty_paren on stab
  expect 3

  nonterminals do
    grammar expr_list
    expr container_expr block_expr access_expr
    no_parens_expr no_parens_zero_expr no_parens_one_expr no_parens_one_ambig_expr
    bracket_expr bracket_at_expr bracket_arg matched_expr unmatched_expr
    unmatched_op_expr matched_op_expr no_parens_op_expr no_parens_many_expr
    comp_op_eol at_op_eol unary_op_eol and_op_eol or_op_eol capture_op_eol
    dual_op_eol mult_op_eol power_op_eol concat_op_eol xor_op_eol pipe_op_eol
    stab_op_eol arrow_op_eol match_op_eol when_op_eol in_op_eol in_match_op_eol
    type_op_eol rel_op_eol range_op_eol ternary_op_eol
    open_paren close_paren empty_paren eoe
    list list_args open_bracket close_bracket
    tuple open_curly close_curly
    bitstring open_bit close_bit
    map map_op map_close map_args struct_expr struct_op
    assoc_op_eol assoc_expr assoc_base assoc_update assoc_update_kw assoc
    container_args_base container_args
    call_args_parens_expr call_args_parens_base call_args_parens parens_call
    call_args_no_parens_one call_args_no_parens_ambig call_args_no_parens_expr
    call_args_no_parens_comma_expr call_args_no_parens_all call_args_no_parens_many
    call_args_no_parens_many_strict
    stab stab_eoe stab_expr stab_op_eol_and_expr stab_parens_many
    kw_eol kw_base kw_data kw_call call_args_no_parens_kw_expr call_args_no_parens_kw
    dot_op dot_alias dot_bracket_identifier dot_call_identifier
    dot_identifier dot_op_identifier dot_do_identifier dot_paren_identifier
    do_block fn_eoe do_eoe end_eoe block_eoe block_item block_list
  end

  terminals do
    identifier kw_identifier kw_identifier_safe kw_identifier_unsafe bracket_identifier
    paren_identifier do_identifier block_identifier op_identifier
    ex_fn ex_end alias
    atom atom_quoted atom_safe atom_unsafe bin_string list_string sigil
    bin_heredoc list_heredoc
    comp_op at_op unary_op and_op or_op arrow_op match_op in_op in_match_op
    type_op dual_op mult_op power_op concat_op range_op xor_op pipe_op stab_op when_op
    capture_int capture_op assoc_op rel_op ternary_op dot_call_op
    ex_true ex_false ex_nil ex_do eol pn_semicolon pn_comma pn_dot
    pn_rparen pn_lparen pn_rbracket pn_lbracket pn_rbrace pn_lbrace pn_rshift pn_lshift pn_map pm_percent
    int flt char
  end

  # Changes in ops and precedence should be reflected on:
  #
  #   1. lib/elixir/lib/code/identifier.ex
  #   2. lib/elixir/pages/operators.md
  #   3. lib/iex/lib/iex/evaluator.ex
  #
  # Note though the operator => in practice has lower precedence
  # than all others, its entry in the table is only to support the
  # %{user | foo => bar} syntax

  left      ex_do            5
  right     stab_op_eol     10 # ~>
  left      ex_comma        20
  left      in_match_op_eol 40 # <-, \\ (allowed in matches along =)
  right     when_op_eol     50 # when
  right     type_op_eol     60 # do:
  right     pipe_op_eol     70 # |
  right     assoc_op_eol    80 # =>
  nonassoc  capture_op_eol  90 # &
  right     match_op_eol   100 # =
  left      or_op_eol      120 # ||, |||, or
  left      and_op_eol     130 # &&, &&&, and
  left      comp_op_eol    140 # ==, !=, =~, ===, !==
  left      rel_op_eol     150 # <, >, <=, >=
  left      arrow_op_eol   160 # |>, <<<, >>>, <<~, ~>>, <~, ~>, <~>, <|>
  left      in_op_eol      170 # in, not in
  left      xor_op_eol     180 # ^^^
  right     ternary_op_eol 190 # //
  right     concat_op_eol  200 # ++, --, +++, ---, <>
  right     range_op_eol   200 # .
  left      dual_op_eol    210 # +, -
  left      mult_op_eol    220 # *, /
  left      power_op_eol   230 # **
  nonassoc  unary_op_eol   300 # +, -, !, ^, not, ~~~
  left      dot_call_op    310
  left      dot_op         310 #
  nonassoc  at_op_eol      320 # @
  nonassoc  dot_identifier 330


  # MAIN FLOW OF EXPRESSIONS
  grammar ~> eoe do {:__block__, meta_from_token(@1), []} end
  grammar ~> expr_list do build_block(reverse(@1)) end
  grammar ~> eoe expr_list do build_block(reverse(@2)) end
  grammar ~> expr_list eoe do build_block(reverse(@1)) end
  grammar ~> eoe expr_list eoe do build_block(reverse(@2)) end
  grammar ~> __empty__ do {:__block__, [], []} end

  # Note expressions are on reverse order
  expr_list ~> expr do [@1] end
  expr_list ~> expr_list eoe expr do [@3 | annotate_eoe(@2, @1)] end

  expr ~> matched_expr do @1 end
  expr ~> no_parens_expr do @1 end
  expr ~> unmatched_expr do @1 end

  # ## In Elixir we have three main call syntaxes: with parentheses,
  # ## without parentheses and with do blocks. They are represented
  # ## in the AST as matched, no_parens and unmatched
  # ##
  # ## Calls without parentheses are further divided according to how
  # ## problematic they are:
  # ##
  # ## (a) no_parens_one: a call with one unproblematic argument
  # ## (for example, `f a` or `f g a` and similar) (includes unary operators)
  # ##
  # ## (b) no_parens_many: a call with several arguments (for example, `f a, b`)
  # ##
  # ## (c) no_parens_one_ambig: a call with one argument which is
  # ## itself a no_parens_many or no_parens_one_ambig (for example, `f g a, b`,
  # ## `f g h a, b` and similar)
  # ##
  # ## Note, in particular, that no_parens_one_ambig expressions are
  # ## ambiguous and are interpreted such that the outer function has
  # ## arity 1. For instance, `f g a, b` is interpreted as `f(g(a, b))` rather
  # ## than `f(g(a), b)`. Hence the name, no_parens_one_ambig
  # ##
  # ## The distinction is required because we can't, for example, have
  # ## a function call with a do block as argument inside another do
  # ## block call, unless there are parentheses:
  # ##
  # ##   if if true do true else false end do  #=> invalid
  # ##   if(if true do true else false end) do #=> valid
  # ##
  # ## Similarly, it is not possible to nest calls without parentheses
  # ## if their arity is more than 1:
  # ##
  # ##   foo a, bar b, c  #=> invalid
  # ##   foo(a, bar b, c) #=> invalid
  # ##   foo bar a, b     #=> valid
  # ##   foo a, bar(b, c) #=> valid
  # ##
  # ## So the different grammar rules need to take into account
  # ## if calls without parentheses are do blocks in particular
  # ## segments and act accordingly

  matched_expr ~> matched_expr matched_op_expr do build_op(@1, @2) end
  matched_expr ~> unary_op_eol matched_expr do build_unary_op(@1, @2) end
  matched_expr ~> at_op_eol matched_expr do build_unary_op(@1, @2) end
  matched_expr ~> capture_op_eol matched_expr do build_unary_op(@1, @2) end
  matched_expr ~> no_parens_one_expr do @1 end
  matched_expr ~> no_parens_zero_expr do @1 end
  matched_expr ~> access_expr do @1 end
  matched_expr ~> access_expr kw_identifier do error_invalid_kw_identifier(@2) end

  unmatched_expr ~> matched_expr unmatched_op_expr do build_op(@1, @2) end
  unmatched_expr ~> unmatched_expr matched_op_expr do build_op(@1, @2) end
  unmatched_expr ~> unmatched_expr unmatched_op_expr do build_op(@1, @2) end
  unmatched_expr ~> unary_op_eol expr do build_unary_op(@1, @2) end
  unmatched_expr ~> at_op_eol expr do build_unary_op(@1, @2) end
  unmatched_expr ~> capture_op_eol expr do build_unary_op(@1, @2) end
  unmatched_expr ~> block_expr do @1 end

  no_parens_expr ~> matched_expr no_parens_op_expr do build_op(@1, @2) end
  no_parens_expr ~> unary_op_eol no_parens_expr do build_unary_op(@1, @2) end
  no_parens_expr ~> at_op_eol no_parens_expr do build_unary_op(@1, @2) end
  no_parens_expr ~> capture_op_eol no_parens_expr do build_unary_op(@1, @2) end
  no_parens_expr ~> no_parens_one_ambig_expr do @1 end
  no_parens_expr ~> no_parens_many_expr do @1 end

  block_expr ~> dot_call_identifier call_args_parens do_block do build_parens(@1, @2, @3) end
  block_expr ~> dot_call_identifier call_args_parens call_args_parens do_block do build_nested_parens(@1, @2, @3, @4) end
  block_expr ~> dot_do_identifier do_block do build_no_parens_do_block(@1, [], @2) end
  block_expr ~> dot_op_identifier call_args_no_parens_all do_block do build_no_parens_do_block(@1, @2, @3) end
  block_expr ~> dot_identifier call_args_no_parens_all do_block do build_no_parens_do_block(@1, @2, @3) end

  matched_op_expr ~> match_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> dual_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> mult_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> power_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> concat_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> range_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> ternary_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> xor_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> and_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> or_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> in_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> in_match_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> type_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> when_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> pipe_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> comp_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> rel_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> arrow_op_eol matched_expr do {@1, @2} end
  matched_op_expr ~> arrow_op_eol no_parens_one_expr do
    warn_pipe(@1, @2)
    {@1, @2}
  end

  unmatched_op_expr ~> match_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> dual_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> mult_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> power_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> concat_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> range_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> ternary_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> xor_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> and_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> or_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> in_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> in_match_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> type_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> when_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> pipe_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> comp_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> rel_op_eol unmatched_expr do {@1, @2} end
  unmatched_op_expr ~> arrow_op_eol unmatched_expr do {@1, @2} end

  no_parens_op_expr ~> match_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> dual_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> mult_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> power_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> concat_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> range_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> ternary_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> xor_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> and_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> or_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> in_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> in_match_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> type_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> when_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> pipe_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> comp_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> rel_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> arrow_op_eol no_parens_expr do {@1, @2} end
  no_parens_op_expr ~> arrow_op_eol no_parens_one_ambig_expr do
    warn_pipe(@1, @2)
    {@1, @2}
  end
  no_parens_op_expr ~> arrow_op_eol no_parens_many_expr do
    warn_pipe(@1, @2)
    {@1, @2}
  end

  ## Allow when (and only when) with keywords
  no_parens_op_expr ~> when_op_eol call_args_no_parens_kw do {@1, @2} end

  no_parens_one_ambig_expr ~> dot_op_identifier call_args_no_parens_ambig do build_no_parens(@1, @2) end
  no_parens_one_ambig_expr ~> dot_identifier call_args_no_parens_ambig do build_no_parens(@1, @2) end

  no_parens_many_expr ~> dot_op_identifier call_args_no_parens_many_strict do build_no_parens(@1, @2) end
  no_parens_many_expr ~> dot_identifier call_args_no_parens_many_strict do build_no_parens(@1, @2) end

  no_parens_one_expr ~> dot_op_identifier call_args_no_parens_one do build_no_parens(@1, @2) end
  no_parens_one_expr ~> dot_identifier call_args_no_parens_one do build_no_parens(@1, @2) end
  no_parens_zero_expr ~> dot_do_identifier do build_no_parens(@1, nil) end
  no_parens_zero_expr ~> dot_identifier do build_no_parens(@1, nil) end

  ## From this point on, we just have constructs that can be
  ## used with the access syntax. Note that (dot_)identifier
  ## is not included in this list simply because the tokenizer
  ## marks identifiers followed by brackets as bracket_identifier
  access_expr ~> bracket_at_expr do @1 end
  access_expr ~> bracket_expr do @1 end
  access_expr ~> capture_int int do build_unary_op(@1, number_value(@2)) end
  access_expr ~> fn_eoe stab end_eoe do build_fn(@1, @2, @3) end
  access_expr ~> open_paren stab close_paren do build_paren_stab(@1, @2, @3) end
  access_expr ~> open_paren stab pn_semicolon close_paren do build_paren_stab(@1, @2, @4) end
  access_expr ~> open_paren pn_semicolon stab pn_semicolon close_paren do build_paren_stab(@1, @3, @5) end
  access_expr ~> open_paren pn_semicolon stab close_paren do build_paren_stab(@1, @3, @4) end
  access_expr ~> open_paren pn_semicolon close_paren do build_paren_stab(@1, [], @3) end
  access_expr ~> empty_paren do
    warn_empty_paren(@1)
    {:__block__, [], []}
  end
  access_expr ~> int do handle_number(number_value(@1), @1, exprs(@1)) end
  access_expr ~> flt do handle_number(number_value(@1), @1, exprs(@1)) end
  access_expr ~> char do handle_number(exprs(@1), @1, number_value(@1)) end
  access_expr ~> list do element(1, @1) end
  access_expr ~> map do @1 end
  access_expr ~> tuple do @1 end
  access_expr ~> ex_true do handle_literal(id(@1), @1) end
  access_expr ~> ex_false do handle_literal(id(@1), @1) end
  access_expr ~> ex_nil do handle_literal(id(@1), @1) end
  access_expr ~> bin_string do build_bin_string(@1, delimiter(<<?">>)) end
  access_expr ~> list_string do build_list_string(@1, delimiter(<<?'>>)) end
  access_expr ~> bin_heredoc do build_bin_heredoc(@1) end
  access_expr ~> list_heredoc do build_list_heredoc(@1) end
  access_expr ~> bitstring do @1 end
  access_expr ~> sigil do build_sigil(@1) end
  access_expr ~> atom do handle_literal(exprs(@1), @1) end
  access_expr ~> atom_quoted do handle_literal(exprs(@1), @1, delimiter(<<?">>)) end
  access_expr ~> atom_safe do build_quoted_atom(@1, true, delimiter(<<?">>)) end
  access_expr ~> atom_unsafe do build_quoted_atom(@1, false, delimiter(<<?">>)) end
  access_expr ~> dot_alias do @1 end
  access_expr ~> parens_call do @1 end
  access_expr ~> range_op do build_nullary_op(@1) end

  ## Also used by maps and structs
  parens_call ~> dot_call_identifier call_args_parens do build_parens(@1, @2, {[], []}) end
  parens_call ~> dot_call_identifier call_args_parens call_args_parens do build_nested_parens(@1, @2, @3, {[], []}) end

  bracket_arg ~> open_bracket kw_data close_bracket do build_access_arg(@1, @2, @3) end
  bracket_arg ~> open_bracket container_expr close_bracket do build_access_arg(@1, @2, @3) end
  bracket_arg ~> open_bracket container_expr pn_comma close_bracket do build_access_arg(@1, @2, @4) end
  bracket_arg ~> open_bracket container_expr pn_comma container_args close_bracket do error_too_many_access_syntax(@3) end

  bracket_expr ~> dot_bracket_identifier bracket_arg do build_access(build_no_parens(@1, nil), @2) end
  bracket_expr ~> access_expr bracket_arg do build_access(@1, meta_with_from_brackets(@2)) end

  bracket_at_expr ~> at_op_eol dot_bracket_identifier bracket_arg do
    build_access(build_unary_op(@1, build_no_parens(@2, nil)), @3)
  end
  bracket_at_expr ~> at_op_eol access_expr bracket_arg do
    build_access(build_unary_op(@1, @2), @3)
  end

  ## Blocks

  do_block ~> do_eoe ex_end do
    {do_end_meta(@1, @2), [[{handle_literal(ex_do, @1), {:__block__, [], []}}]]}
  end
  do_block ~> do_eoe stab end_eoe do
    {do_end_meta(@1, @3), [[{handle_literal(ex_do, @1), build_stab(@2)}]]}
  end
  do_block ~> do_eoe block_list ex_end do
    {do_end_meta(@1, @3), [[{handle_literal(ex_do, @1), {:__block__, [], []}} | @2]]}
  end
  do_block ~> do_eoe stab_eoe block_list ex_end do
    {do_end_meta(@1, @4), [[{handle_literal(ex_do, @1), build_stab(@2)} | @3]]}
  end
  eoe ~> eol do @1 end
  eoe ~> pn_semicolon do @1 end
  eoe ~> eol pn_semicolon do @1 end

  fn_eoe ~> ex_fn do @1 end
  fn_eoe ~> ex_fn eoe do next_is_eol(@1, @2) end

  do_eoe ~> ex_do do @1 end
  do_eoe ~> ex_do eoe do @1 end

  end_eoe ~> ex_end do @1 end
  end_eoe ~> eoe ex_end do @2 end

  block_eoe ~> block_identifier do @1 end
  block_eoe ~> block_identifier eoe do @1 end

  stab ~> stab_expr do [@1] end
  stab ~> stab eoe stab_expr do [@3 | annotate_eoe(@2, @1)] end

  stab_eoe ~> stab do @1 end
  stab_eoe ~> stab eoe do @1 end

  stab_expr ~> expr do
    @1
  end
  stab_expr ~> stab_op_eol_and_expr do
    build_op([], @1)
  end
  stab_expr ~> empty_paren stab_op_eol_and_expr do
    build_op([], @2)
  end
  stab_expr ~> empty_paren when_op expr stab_op_eol_and_expr do
    build_op([{ex_when, meta_from_token(@2), [@3]}], @4)
  end
  stab_expr ~> call_args_no_parens_all stab_op_eol_and_expr do
    build_op(unwrap_when(unwrap_splice(@1)), @2)
  end
  stab_expr ~> stab_parens_many stab_op_eol_and_expr do
    build_op(unwrap_splice(@1), @2)
  end
  stab_expr ~> stab_parens_many when_op expr stab_op_eol_and_expr do
    build_op([{ex_when, meta_from_token(@2), unwrap_splice(@1) ++ [@3]}], @4)
  end

  stab_op_eol_and_expr ~> stab_op_eol expr do {@1, @2} end
  stab_op_eol_and_expr ~> stab_op_eol do
    warn_empty_stab_clause(@1)
    {@1, handle_literal(ex_nil, @1)}
  end

  block_item ~> block_eoe stab_eoe do
    {handle_literal(exprs(@1), @1), build_stab(@2)}
  end
  block_item ~> block_eoe do
    {handle_literal(exprs(@1), @1), {:__block__, [], []}}
  end

  block_list ~> block_item do [@1] end
  block_list ~> block_item block_list do [@1 | @2] end

  ## Helpers

  open_paren ~> pn_lparen      do @1 end
  open_paren ~> pn_lparen eol  do next_is_eol(@1, @2) end
  close_paren ~> pn_rparen     do @1 end
  close_paren ~> eol pn_rparen do @2 end

  empty_paren ~> open_paren pn_rparen do @1 end

  open_bracket  ~> pn_lbracket     do @1 end
  open_bracket  ~> pn_lbracket eol do next_is_eol(@1, @2) end
  close_bracket ~> pn_rbracket     do @1 end
  close_bracket ~> eol pn_rbracket do @2 end

  open_bit  ~> pn_lshift     do @1 end
  open_bit  ~> pn_lshift eol do next_is_eol(@1, @2) end
  close_bit ~> pn_rshift     do @1 end
  close_bit ~> eol pn_rshift do @2 end

  open_curly  ~> pn_lbrace     do @1 end
  open_curly  ~> pn_lbrace eol do next_is_eol(@1, @2) end
  close_curly ~> pn_rbrace     do @1 end
  close_curly ~> eol pn_rbrace do @2 end

  # Operators

  unary_op_eol ~> unary_op do @1 end
  unary_op_eol ~> unary_op eol do @1 end
  unary_op_eol ~> dual_op do @1 end
  unary_op_eol ~> dual_op eol do @1 end
  unary_op_eol ~> ternary_op do @1 end
  unary_op_eol ~> ternary_op eol do @1 end

  capture_op_eol ~> capture_op do @1 end
  capture_op_eol ~> capture_op eol do @1 end

  at_op_eol ~> at_op do @1 end
  at_op_eol ~> at_op eol do @1 end

  match_op_eol ~> match_op do @1 end
  match_op_eol ~> match_op eol do next_is_eol(@1, @2) end

  dual_op_eol ~> dual_op do @1 end
  dual_op_eol ~> dual_op eol do next_is_eol(@1, @2) end

  mult_op_eol ~> mult_op do @1 end
  mult_op_eol ~> mult_op eol do next_is_eol(@1, @2) end

  power_op_eol ~> power_op do @1 end
  power_op_eol ~> power_op eol do next_is_eol(@1, @2) end

  concat_op_eol ~> concat_op do @1 end
  concat_op_eol ~> concat_op eol do next_is_eol(@1, @2) end

  range_op_eol ~> range_op do @1 end
  range_op_eol ~> range_op eol do next_is_eol(@1, @2) end

  ternary_op_eol ~> ternary_op do @1 end
  ternary_op_eol ~> ternary_op eol do next_is_eol(@1, @2) end

  xor_op_eol ~> xor_op do @1 end
  xor_op_eol ~> xor_op eol do next_is_eol(@1, @2) end

  pipe_op_eol ~> pipe_op do @1 end
  pipe_op_eol ~> pipe_op eol do next_is_eol(@1, @2) end

  and_op_eol ~> and_op do @1 end
  and_op_eol ~> and_op eol do next_is_eol(@1, @2) end

  or_op_eol ~> or_op do @1 end
  or_op_eol ~> or_op eol do next_is_eol(@1, @2) end

  in_op_eol ~> in_op do @1 end
  in_op_eol ~> in_op eol do next_is_eol(@1, @2) end

  in_match_op_eol ~> in_match_op do @1 end
  in_match_op_eol ~> in_match_op eol do next_is_eol(@1, @2) end

  type_op_eol ~> type_op do @1 end
  type_op_eol ~> type_op eol do next_is_eol(@1, @2) end

  when_op_eol ~> when_op do @1 end
  when_op_eol ~> when_op eol do next_is_eol(@1, @2) end

  stab_op_eol ~> stab_op do @1 end
  stab_op_eol ~> stab_op eol do next_is_eol(@1, @2) end

  comp_op_eol ~> comp_op do @1 end
  comp_op_eol ~> comp_op eol do next_is_eol(@1, @2) end

  rel_op_eol ~> rel_op do @1 end
  rel_op_eol ~> rel_op eol do next_is_eol(@1, @2) end

  arrow_op_eol ~> arrow_op do @1 end
  arrow_op_eol ~> arrow_op eol do next_is_eol(@1, @2) end

  # Dot operator

  dot_op ~> pn_dot do @1 end
  dot_op ~> pn_dot eol do @1 end

  dot_identifier ~> identifier do @1 end
  dot_identifier ~> matched_expr dot_op identifier do build_dot(@2, @1, @3) end

  dot_alias ~> alias do build_alias(@1) end
  dot_alias ~> matched_expr dot_op alias do build_dot_alias(@2, @1, @3) end
  dot_alias ~> matched_expr dot_op open_curly pn_rbrace do build_dot_container(@2, @1, [], []) end
  dot_alias ~> matched_expr dot_op open_curly container_args close_curly do build_dot_container(@2, @1, @4, newlines_pair(@3, @5)) end

  dot_op_identifier ~> op_identifier do @1 end
  dot_op_identifier ~> matched_expr dot_op op_identifier do build_dot(@2, @1, @3) end

  dot_do_identifier ~> do_identifier do @1 end
  dot_do_identifier ~> matched_expr dot_op do_identifier do build_dot(@2, @1, @3) end

  dot_bracket_identifier ~> bracket_identifier do @1 end
  dot_bracket_identifier ~> matched_expr dot_op bracket_identifier do build_dot(@2, @1, @3) end

  dot_paren_identifier ~> paren_identifier do @1 end
  dot_paren_identifier ~> matched_expr dot_op paren_identifier do build_dot(@2, @1, @3) end

  dot_call_identifier ~> dot_paren_identifier do @1 end
  dot_call_identifier ~> matched_expr dot_call_op do {pn_dot, meta_from_token(@2), [@1]} end # Fun/local calls

  # Function calls with no parentheses

  call_args_no_parens_expr ~> matched_expr do @1 end
  call_args_no_parens_expr ~> no_parens_expr do error_no_parens_many_strict(@1) end

  call_args_no_parens_comma_expr ~> matched_expr pn_comma call_args_no_parens_expr do [@3, @1] end
  call_args_no_parens_comma_expr ~> call_args_no_parens_comma_expr pn_comma call_args_no_parens_expr do [@3 | @1] end

  call_args_no_parens_all ~> call_args_no_parens_one do @1 end
  call_args_no_parens_all ~> call_args_no_parens_ambig do @1 end
  call_args_no_parens_all ~> call_args_no_parens_many do @1 end

  call_args_no_parens_one ~> call_args_no_parens_kw do [@1] end
  call_args_no_parens_one ~> matched_expr do [@1] end

  ## This is the only no parens ambiguity where we don't
  ## raise nor warn: "parent_call nested_call 1, 2, 3"
  ## always assumes that all arguments are nested
  call_args_no_parens_ambig ~> no_parens_expr do [@1] end

  call_args_no_parens_many ~> matched_expr pn_comma call_args_no_parens_kw do [@1, @3] end
  call_args_no_parens_many ~> call_args_no_parens_comma_expr do reverse(@1) end
  call_args_no_parens_many ~> call_args_no_parens_comma_expr pn_comma call_args_no_parens_kw do reverse([@3 | @1]) end

  call_args_no_parens_many_strict ~> call_args_no_parens_many do @1 end
  call_args_no_parens_many_strict ~> open_paren call_args_no_parens_kw close_paren do error_no_parens_strict(@1) end
  call_args_no_parens_many_strict ~> open_paren call_args_no_parens_many close_paren do error_no_parens_strict(@1) end

  stab_parens_many ~> open_paren call_args_no_parens_kw close_paren do [@2] end
  stab_parens_many ~> open_paren call_args_no_parens_many close_paren do @2 end

  # Containers

  container_expr ~> matched_expr do @1 end
  container_expr ~> unmatched_expr do @1 end
  container_expr ~> no_parens_expr do error_no_parens_container_strict(@1) end

  container_args_base ~> container_expr do [@1] end
  container_args_base ~> container_args_base pn_comma container_expr do [@3 | @1] end

  container_args ~> container_args_base do reverse(@1) end
  container_args ~> container_args_base pn_comma do reverse(@1) end
  container_args ~> container_args_base pn_comma kw_data do reverse([@3 | @1]) end

  # Function calls with parentheses

  call_args_parens_expr ~> matched_expr do @1 end
  call_args_parens_expr ~> unmatched_expr do @1 end
  call_args_parens_expr ~> no_parens_expr do error_no_parens_many_strict(@1) end

  call_args_parens_base ~> call_args_parens_expr do [@1] end
  call_args_parens_base ~> call_args_parens_base pn_comma call_args_parens_expr do [@3 | @1] end

  call_args_parens ~> open_paren pn_rparen do
    {newlines_pair(@1, @2), []}
  end
  call_args_parens ~> open_paren no_parens_expr close_paren do
    {newlines_pair(@1, @3), [@2]}
  end
  call_args_parens ~> open_paren kw_call close_paren do
    {newlines_pair(@1, @3), [@2]}
  end
  call_args_parens ~> open_paren call_args_parens_base close_paren do
    {newlines_pair(@1, @3), reverse(@2)}
  end
  call_args_parens ~> open_paren call_args_parens_base pn_comma kw_call close_paren do
    {newlines_pair(@1, @5), reverse([@4 | @2])}
  end

  # KV

  kw_eol ~> kw_identifier do handle_literal(exprs(@1), @1, [{format, keyword}]) end
  kw_eol ~> kw_identifier eol do handle_literal(exprs(@1), @1, [{format, keyword}]) end
  kw_eol ~> kw_identifier_safe do build_quoted_atom(@1, true, [{format, keyword}]) end
  kw_eol ~> kw_identifier_safe eol do build_quoted_atom(@1, true, [{format, keyword}]) end
  kw_eol ~> kw_identifier_unsafe do build_quoted_atom(@1, false, [{format, keyword}]) end
  kw_eol ~> kw_identifier_unsafe eol do build_quoted_atom(@1, false, [{format, keyword}]) end

  kw_base ~> kw_eol container_expr do [{@1, @2}] end
  kw_base ~> kw_base pn_comma kw_eol container_expr do [{@3, @4} | @1] end

  kw_call ~> kw_base do reverse(@1) end
  kw_call ~> kw_base pn_comma do
    warn_trailing_comma(@2)
    reverse(@1)
  end
  kw_call ~> kw_base pn_comma matched_expr do maybe_bad_keyword_call_follow_up(@2, @1, @3) end

  kw_data ~> kw_base do reverse(@1) end
  kw_data ~> kw_base pn_comma do reverse(@1) end
  kw_data ~> kw_base pn_comma matched_expr do maybe_bad_keyword_data_follow_up(@2, @1, @3) end

  call_args_no_parens_kw_expr ~> kw_eol matched_expr do {@1, @2} end
  call_args_no_parens_kw_expr ~> kw_eol no_parens_expr do
    warn_nested_no_parens_keyword(@1, @2)
    {@1, @2}
  end

  call_args_no_parens_kw ~> call_args_no_parens_kw_expr do [@1] end
  call_args_no_parens_kw ~> call_args_no_parens_kw_expr pn_comma call_args_no_parens_kw do [@1 | @3] end
  call_args_no_parens_kw ~> call_args_no_parens_kw_expr pn_comma matched_expr do maybe_bad_keyword_call_follow_up(@2, [@1], @3) end

  # Lists

  list_args ~> kw_data do @1 end
  list_args ~> container_args_base do reverse(@1) end
  list_args ~> container_args_base pn_comma do reverse(@1) end
  list_args ~> container_args_base pn_comma kw_data do reverse(@1, @3) end

  list ~> open_bracket pn_rbracket do build_list(@1, [], @2) end
  list ~> open_bracket list_args close_bracket do build_list(@1, @2, @3) end

  # Tuple

  tuple ~> open_curly pn_rbrace do build_tuple(@1, [], @2) end
  tuple ~> open_curly kw_data pn_rbrace do bad_keyword(@1, tuple) end
  tuple ~> open_curly container_args close_curly do  build_tuple(@1, @2, @3) end

  # Bitstrings

  bitstring ~> open_bit pn_rshift do build_bit(@1, [], @2) end
  bitstring ~> open_bit kw_data pn_rshift do bad_keyword(@1, bitstring) end
  bitstring ~> open_bit container_args close_bit do build_bit(@1, @2, @3) end

  # Map and structs

  assoc_op_eol ~> assoc_op do @1 end
  assoc_op_eol ~> assoc_op eol do @1 end

  assoc_expr ~> matched_expr assoc_op_eol matched_expr do {@1, @3} end
  assoc_expr ~> unmatched_expr assoc_op_eol unmatched_expr do {@1, @3} end
  assoc_expr ~> matched_expr assoc_op_eol unmatched_expr do {@1, @3} end
  assoc_expr ~> unmatched_expr assoc_op_eol matched_expr do {@1, @3} end
  assoc_expr ~> dot_identifier do build_identifier(@1, nil) end
  assoc_expr ~> no_parens_one_expr do @1 end
  assoc_expr ~> parens_call do @1 end

  assoc_update ~> matched_expr pipe_op_eol assoc_expr do {@2, @1, [@3]} end
  assoc_update ~> unmatched_expr pipe_op_eol assoc_expr do {@2, @1, [@3]} end

  assoc_update_kw ~> matched_expr pipe_op_eol kw_data do {@2, @1, @3} end
  assoc_update_kw ~> unmatched_expr pipe_op_eol kw_data do {@2, @1, @3} end

  assoc_base ~> assoc_expr do [@1] end
  assoc_base ~> assoc_base pn_comma assoc_expr do [@3 | @1] end

  assoc ~> assoc_base do reverse(@1) end
  assoc ~> assoc_base pn_comma do reverse(@1) end

  map_op ~> pn_map do @1 end
  map_op ~> pn_map eol do @1 end

  map_close ~> kw_data close_curly do {@1, @2} end
  map_close ~> assoc close_curly do {@1, @2} end
  map_close ~> assoc_base pn_comma kw_data close_curly do {reverse(@1, @3), @4} end

  map_args ~> open_curly pn_rbrace do build_map(@1, [], @2) end
  map_args ~> open_curly map_close do build_map(@1, element(1, @2), element(2, @2)) end
  map_args ~> open_curly assoc_update close_curly do build_map_update(@1, @2, @3, []) end
  map_args ~> open_curly assoc_update pn_comma close_curly do build_map_update(@1, @2, @4, []) end
  map_args ~> open_curly assoc_update pn_comma map_close do build_map_update(@1, @2, element(2, @4), element(1, @4)) end
  map_args ~> open_curly assoc_update_kw close_curly do build_map_update(@1, @2, @3, []) end

  struct_op ~> pn_percent do @1 end
  struct_expr ~> atom do handle_literal(exprs(@1), @1, []) end
  struct_expr ~> atom_quoted do handle_literal(exprs(@1), @1, delimiter(<<?">>)) end
  struct_expr ~> dot_alias do @1 end
  struct_expr ~> dot_identifier do build_identifier(@1, nil) end
  struct_expr ~> at_op_eol struct_expr do build_unary_op(@1, @2) end
  struct_expr ~> unary_op_eol struct_expr do build_unary_op(@1, @2) end
  struct_expr ~> parens_call do @1 end

  map ~> map_op map_args do @2 end
  map ~> struct_op struct_expr map_args do {pn_percent, meta_from_token(@1), [@2, @3]} end
  map ~> struct_op struct_expr eol map_args do {pn_percent, meta_from_token(@1), [@2, @4]} end

  defmacrop columns do
    quote do
      :erlang.get(:elixir_parser_columns)
    end
  end

  defmacrop token_metadata do
    quote do
      :erlang.get(:elixir_token_metadata)
    end
  end

  defmacrop id(token) do
    quote do
      :erlang.element(1, unquote(token))
    end
  end

  defmacrop location(token) do
    quote do
      :erlang.element(2, unquote(token))
    end
  end

  defmacrop exprs(token) do
    quote do
      :erlang.element(3, unquote(token))
    end
  end

  defmacrop meta(node) do
    quote do
      :erlang.element(2, unquote(node))
    end
  end

  defguardp rearrange_uop(op) when op == :not or op == :!

  defp meta_from_token(token) do
    meta_from_location(location(token))
  end

  defp meta_from_location({line, column, _}) do
    if columns() do
      [{:line, line}, {:column, column}]
    else
      [{:line, line}]
    end
  end

  defp do_end_meta(ex_do, ex_end) do
    if token_metadata() do
      [
        {:ex_do, meta_from_location(location(ex_do))},
        {:ex_end, meta_from_location(location(ex_end))}
      ]
    else
      []
    end
  end

  defp meta_from_token_with_closing(begin, closing) do
    if token_metadata() do
      [{:closing, meta_from_location(location(closing))} | meta_from_token(begin)]
    else
      meta_from_token(begin)
    end
  end

  defp append_non_empty(left, []), do: left
  defp append_non_empty(left, right), do: left ++ right

  ## Handle metadata in literals

  defp handle_literal(literal, token) do
    handle_literal(literal, token, [])
  end

  defp handle_literal(literal, token, extra_meta) do
    case get(:elixir_literal_encoder) do
      false ->
        literal

      fun ->
        meta = extra_meta ++ meta_from_token(token)

        case fun.(literal, meta) do
          {:ok, encoded_literal} ->
            encoded_literal

          {:error, reason} ->
            return_error(
              location(token),
              :elixir_utils.characters_to_list(reason) ++ [': '],
              'literal'
            )
        end
    end
  end

  defp handle_number(number, token, original) do
    if token_metadata() do
      handle_literal(number, token, [{:token, :elixir_utils.characters_to_binary(original)}])
    else
      handle_literal(number, token, [])
    end
  end

  defp number_value({_, {_, _, value}, _}), do: value

  ## Operators

  defp build_op(left, {op, right}) do
    build_op(left, op, right)
  end

  defp build_op(ast, {_kind, location, :"//"}, right) do
    case ast do
      {:.., meta, [left, middle]} ->
        {:"..//", meta, [left, middle, right]}

      _ ->
        return_error(
          location,
          ~c"the range step operator (//) must immediately follow the range definition operator (..), for example: 1..9//2. If you wanted to define a default argument, use (\\\\) instead. Syntax error before: ",
          "'//'"
        )
    end
  end

  defp build_op({u_op, _, [left]}, {_kind, {line, column, _} = location, :in}, right)
       when rearrange_uop(u_op) do
    # TODO: Remove "not left in right" rearrangement on v2.0
    warn(
      {line, column},
      ~c"\"not expr1 in expr2\" is deprecated, use \"expr1 not in expr2\" instead"
    )

    meta = meta_from_location(location)
    {u_op, meta, [{:in, meta, [left, right]}]}
  end

  defp build_op(left, {_kind, location, :"not in"}, right) do
    meta = meta_from_location(location)
    {:not, meta, [{:in, meta, [left, right]}]}
  end

  defp build_op(left, {_kind, location, op}, right) do
    {op, newlines_op(location) ++ meta_from_location(location), [left, right]}
  end

  defp build_unary_op({_kind, {line, column, _}, :"//"}, expr) do
    {outer, inner} =
      if columns() do
        {[{:column, column + 1}], [{:column, column}]}
      else
        {[], []}
      end

    {:/, [{:line, line} | outer], [{:/, [{:line, line} | inner], nil}, expr]}
  end

  defp build_unary_op({_kind, location, op}, expr) do
    {op, meta_from_location(location), [expr]}
  end

  defp build_nullary_op({_kind, location, op}) do
    {op, meta_from_location(location), []}
  end

  defp build_list(left, args, right) do
    {handle_literal(args, left, newlines_pair(left, right)), location(left)}
  end

  defp build_tuple(left, [arg1, arg2], right) do
    handle_literal({arg1, arg2}, left, newlines_pair(left, right))
  end

  defp build_tuple(left, args, right) do
    {:{}, newlines_pair(left, right) ++ meta_from_token(left), args}
  end

  defp build_bit(left, args, right) do
    {:<<>>, newlines_pair(left, right) ++ meta_from_token(left), args}
  end

  defp build_map(left, args, right) do
    {:%{}, newlines_pair(left, right) ++ meta_from_token(left), args}
  end

  defp build_map_update(left, {pipe, struct, map}, right, extra) do
    op = build_op(struct, pipe, append_non_empty(map, extra))
    {:%{}, newlines_pair(left, right) ++ meta_from_token(left), [op]}
  end

  # Blocks

  defp build_block([{:unquote_splicing, _, [_]}] = exprs), do: {:__block__, [], exprs}
  defp build_block([expr]), do: expr
  defp build_block(exprs), do: {:__block__, [], exprs}

  # Newlines
  defp newlines_pair(left, right) do
    if token_metadata() do
      newlines(location(left), [{:closing, meta_from_location(location(right))}])
    else
      []
    end
  end

  defp newlines_op(location) do
    if token_metadata() do
      newlines(location, [])
    else
      []
    end
  end

  defp next_is_eol(token, {_, {_, _, count}}) do
    {line, column, _} = location(token)
    :erlang.setelement(2, token, {line, column, count})
  end

  defp newlines({_, _, count}, meta) when is_integer(count) and count > 0 do
    [{:newlines, count} | meta]
  end

  defp newlines(_, meta), do: meta

  defp annotate_eoe(token, stack) do
    if token_metadata() do
      case {token, stack} do
        {{_, location}, [{:->, stab_meta, [stab_args, {left, meta, right}]} | rest]}
        when is_list(meta) ->
          [
            {:->, stab_meta,
             [
               stab_args,
               {left, [{:end_of_expression, end_of_expression(location)} | meta], right}
             ]}
            | rest
          ]

        {{_, location}, [{left, meta, right} | rest]} when is_list(meta) ->
          [{left, [{:end_of_expression, end_of_expression(location)} | meta], right} | rest]

        _ ->
          stack
      end
    else
      stack
    end
  end

  defp end_of_expression({_, _, count} = location) when is_integer(count) do
    [{:newlines, count} | meta_from_location(location)]
  end

  defp end_of_expression(location) do
    meta_from_location(location)
  end

  # Dots
  defp build_alias({:alias, location, ex_alias}) do
    meta = meta_from_location(location)

    meta_with_extra =
      if token_metadata() do
        [{:last, meta_from_location(location)} | meta]
      else
        meta
      end

    {:__aliases__, meta_with_extra, [ex_alias]}
  end

  defp build_dot_alias(_dot, {:__aliases__, meta, left}, {:alias, segment_location, right}) do
    meta_with_extra =
      if token_metadata() do
        :lists.keystore(:last, 1, meta, {:last, meta_from_location(segment_location)})
      else
        meta
      end

    {:__aliases__, meta_with_extra, left ++ [right]}
  end

  defp build_dot_alias(_dot, atom, right) when is_atom(atom) do
    error_bad_atom(right)
  end

  defp build_dot_alias(dot, expr, {:alias, segment_location, right}) do
    meta = meta_from_token(dot)

    meta_with_extra =
      if token_metadata() do
        [{:last, meta_from_location(segment_location)} | meta]
      else
        meta
      end

    {:__aliases__, meta_with_extra, [expr, right]}
  end

  defp build_dot_container(dot, left, right, extra) do
    meta = meta_from_token(dot)
    {{:., meta, [left, :{}]}, extra ++ meta, right}
  end

  defp build_dot(dot, left, {_, location, _} = right) do
    meta = meta_from_token(dot)
    identifier_location = meta_from_location(location)
    {:., meta, identifier_location, [left, extract_identifier(right)]}
  end

  defp extract_identifier({kind, _, identifier})
       when kind == :identifier and kind == :bracket_identifier and kind == :paren_identifier and
              kind == :do_identifier and kind == :op_identifier,
       do: identifier

  # Identifiers

  defp build_nested_parens(dot, args1, {args2_meta, args2}, {block_meta, block}) do
    identifier = build_parens(dot, args1, {[], []})
    meta = block_meta ++ args2_meta ++ meta(identifier)
    {identifier, meta, append_non_empty(args2, block)}
  end

  defp build_parens(expr, {args_meta, args}, {block_meta, block}) do
    {built_expr, built_meta, built_args} = build_identifier(expr, append_non_empty(args, block))
    {built_expr, block_meta ++ args_meta ++ built_meta, built_args}
  end

  defp build_no_parens_do_block(expr, args, {block_meta, block}) do
    {built_expr, built_meta, built_args} = build_no_parens(expr, args ++ block)
    {built_expr, block_meta ++ built_meta, built_args}
  end

  defp build_no_parens(expr, args) do
    build_identifier(expr, args)
  end

  defp build_identifier({:., meta, identifier_location, dot_args}, nil) do
    {{:., meta, dot_args}, [{:no_parens, true} | identifier_location], []}
  end

  defp build_identifier({:., meta, identifier_location, dot_args}, args) do
    {{:., meta, dot_args}, identifier_location, args}
  end

  defp build_identifier({:., meta, _} = dot, nil) do
    {dot, [{:no_parens, true} | meta], []}
  end

  defp build_identifier({:., meta, _} = dot, args) do
    {dot, meta, args}
  end

  defp build_identifier({:op_identifier, location, identifier}, [arg]) do
    {identifier, [{:ambiguous_op, nil} | meta_from_location(location)], [arg]}
  end

  ## TODO: Either remove ... or make it an operator on v2.0
  defp build_identifier({_, {line, column, _} = location, '...'}, args) when is_list(args) do
    warn(
      {line, column},
      ~c"... is no longer supported as a function call and it must receive no arguments"
    )

    {:..., meta_from_location(location), args}
  end

  defp build_identifier({_, location, identifier}, args) do
    {identifier, meta_from_location(location), args}
  end

  ## Fn

  defp build_fn(fun, stab, ex_end) do
    case check_stab(stab, :none) do
      :stab ->
        meta = newlines_op(location(fun)) ++ meta_from_token_with_closing(fun, ex_end)
        {:fn, meta, collect_stab(stab, [], [])}

      :block ->
        return_error(
          location(fun),
          ~c"expected anonymous functions to be defined with -> inside: ",
          ~c"'fn'"
        )
    end
  end

  # Access

  defp build_access_arg(left, args, right) do
    {args, newlines_pair(left, right) ++ meta_from_token(left)}
  end

  defp build_access(expr, {list, meta}) do
    {{:., meta, [:"Elixir.Access", :get]}, meta, [expr, list]}
  end

  # Interpolation aware

  defp build_sigil({:sigil, location, sigil, parts, modifiers, indentation, delimiter}) do
    meta = meta_from_location(location)
    meta_with_delimiter = [{:delimiter, delimiter} | meta]
    meta_with_indentation = meta_with_indentation(Meta, indentation)

    {:erlang.list_to_atom(~c"sigil_" ++ sigil), meta_with_delimiter,
     [{:<<>>, meta_with_indentation, string_parts(parts)}, modifiers]}
  end

  defp meta_with_indentation(meta, nil), do: meta

  defp meta_with_indentation(meta, indentation) do
    [{:indentation, indentation} | meta]
  end

  defp meta_with_from_brackets({list, meta}) do
    {list, [{:from_brackets, true} | meta]}
  end

  defp build_bin_heredoc({:bin_heredoc, location, indentation, args}) do
    extra_meta =
      if token_metadata() do
        [{:delimiter, <<?", ?", ?">>}, {:indentation, indentation}]
      else
        []
      end

    build_bin_string({:bin_string, location, args}, extra_meta)
  end

  defp build_list_heredoc({:list_heredoc, location, indentation, args}) do
    extra_meta =
      if token_metadata() do
        [{:delimiter, <<?', ?', ?'>>}, {:indentation, indentation}]
      else
        []
      end

    build_list_string({:list_string, location, args}, extra_meta)
  end

  defp build_bin_string({:bin_string, _location, [h]} = token, extra_meta) when is_binary(H) do
    handle_literal(h, token, extra_meta)
  end

  defp build_bin_string({:bin_string, location, args}, extra_meta) do
    meta =
      if token_metadata() do
        extra_meta ++ meta_from_location(location)
      else
        meta_from_location(location)
      end

    {:<<>>, meta, string_parts(args)}
  end

  defp build_list_string({:list_string, _location, [h]} = token, extra_meta) when is_binary(h) do
    handle_literal(:elixir_utils.characters_to_list(h), token, extra_meta)
  end

  defp build_list_string({list_string, location, args}, extra_meta) do
    meta = meta_from_location(location)

    meta_with_extra =
      if token_metadata() do
        extra_meta ++ meta
      else
        meta
      end

    {{:., meta, [:"Elixir.List", :to_charlist]}, meta_with_extra, [charlist_parts(args)]}
  end

  defp build_quoted_atom({_, _Location, [h]} = token, safe, extra_meta) when is_binary(h) do
    op = binary_to_atom_op(safe)
    handle_literal(apply(:erlang, op, [h, :utf8]), token, extra_meta)
  end

  defp build_quoted_atom({_, location, args}, safe, extra_meta) do
    meta = meta_from_location(location)

    meta_with_extra_with_extra =
      if token_metadata() do
        extra_meta ++ meta
      else
        meta
      end

    {{:., meta, [:erlang, binary_to_atom_op(safe)]}, meta_with_extra_with_extra,
     [{:<<>>, meta, string_parts(args)}, :utf8]}
  end

  defp binary_to_atom_op(true), do: :binary_to_existing_atom
  defp binary_to_atom_op(false), do: :binary_to_atom

  defp charlist_parts(parts) do
    Enum.map(parts, &charlist_part/1)
  end

  defp charlist_part(binary) when is_binary(binary) do
    binary
  end

  defp charlist_part({begin, closing, tokens}) do
    form = string_tokens_parse(tokens)
    meta = meta_from_location(begin)

    meta_with_extra =
      if token_metadata() do
        [{:closing, meta_from_location(closing)} | meta]
      else
        meta
      end

    {{:., meta, [:"Elixir.Kernel", :to_string]}, meta_with_extra, [form]}
  end

  defp string_parts(parts) do
    Enum.map(parts, &string_part/1)
  end

  defp string_part(binary) when is_binary(binary), do: binary

  defp string_part({begin, closing, tokens}) do
    form = string_tokens_parse(tokens)
    meta = meta_from_location(begin)

    meta_with_extra_with_extra =
      if token_metadata() do
        [{:closing, meta_from_location(closing)} | meta_from_location(begin)]
      else
        meta_from_location(begin)
      end

    {:"::", meta,
     [
       {{:., meta, [:"Elixir.Kernel", :to_string]}, meta_with_extra_with_extra, [form]},
       {:binary, meta, nil}
     ]}
  end

  defp string_tokens_parse(tokens) do
    case parse(tokens) do
      {:ok, forms} -> forms
      {:error, _} = error -> throw(error)
    end
  end

  defp delimiter(delimiter) do
    if token_metadata() do
      [{:delimiter, delimiter}]
    else
      []
    end
  end

  ## Keywords

  defp check_stab([{:->, _, [_, _]}], _), do: :stab
  defp check_stab([], :none), do: :block
  defp check_stab([_], :none), do: :block
  defp check_stab([_], meta), do: error_invalid_stab(meta)
  defp check_stab([{:->, meta, [_, _]} | t], _), do: check_stab(t, meta)
  defp check_stab([_ | t], maybe_meta), do: check_stab(t, maybe_meta)

  defp build_stab(stab) do
    case check_stab(stab, :none) do
      :block -> build_block(:lists.reverse(stab))
      :stab -> collect_stab(stab, [], [])
    end
  end

  defp build_paren_stab(_before, [{op, _, [_]}] = exprs, _after) when rearrange_uop(op) do
    {:__block__, [], exprs}
  end

  defp build_paren_stab(before, stab, ex_after) do
    case build_stab(stab) do
      {:__block__, meta, block} ->
        {:__block__, meta ++ meta_from_token_with_closing(before, ex_after), block}

      other ->
        other
    end
  end

  defp collect_stab([{:->, meta, [left, right]} | t], exprs, stabs) do
    stab = {:->, meta, [left, build_block([right | exprs])]}
    collect_stab(t, [], [stab | stabs])
  end

  defp collect_stab([h | t], exprs, stabs) do
    collect_stab(t, [h | exprs], stabs)
  end

  defp collect_stab([], [], stabs), do: stabs

  # Every time the parser sees a (unquote_splicing())
  # it assumes that a block is being spliced, wrapping
  # the splicing in a __block__. But in the stab clause,
  # we can have (unquote_splicing(1, 2, 3)) -> :ok, in such
  # case, we don't actually want the block, since it is
  # an arg style call. unwrap_splice unwraps the splice
  # from such blocks.
  defp unwrap_splice([{:__block__, _, [{:unquote_splicing, _, _}] = splice}]), do: splice

  defp unwrap_splice(other), do: other

  defp unwrap_when(args) do
    case :elixir_utils.split_last(args) do
      {start, {:when, meta, [_, _] = closing}} ->
        [{:when, meta, start ++ closing}]

      {_, _} ->
        args
    end
  end

  # Warnings and errors

  defp return_error({line, column, _}, error_message, error_token) do
    return_error([{:line, line}, {:column, column}], [error_message, error_token])
  end

  ## We should prefer to use return_error as it includes
  ## Line and Column but that's not always possible.
  defp return_error_with_meta(Meta, ErrorMessage, ErrorToken) do
    return_error(Meta, [ErrorMessage, ErrorToken])
  end

  defp error_invalid_stab(meta_stab) do
    return_error_with_meta(
      meta_stab,
      ~c"unexpected operator ->. If you want to define multiple clauses, the first expression must use ->.
    Syntax error before: ",
      ~c"'->'"
    )
  end

  defp error_bad_atom(token) do
    return_error(location(token), ~c"atom cannot be followed by an alias.
    If the '.' was meant to be part of the atom's name,
    the atom name must be quoted. Syntax error before: ", ~c"'.'")
  end

  defp bad_keyword(token, context) do
    return_error(
      location(token),
      ~c"unexpected keyword list inside #{:erlang.atom_to_list(context)}.
    Did you mean to write a map (using %{...}) or a list (using [...]) instead?
    Syntax error after: ",
      ~c"'{'"
    )
  end

  defp maybe_bad_keyword_call_follow_up(_token, kw, {:__cursor__, _, []} = expr) do
    :lists.reverse([expr | kw])
  end

  defp maybe_bad_keyword_call_follow_up(token, _kw, _expr) do
    return_error(
      location(token),
      ~c"unexpected expression after keyword list. Keyword lists must always come as the last argument. Therefore, this is not allowed:\n\n
        function_call(1, some: :option, 2)\n\n
    Instead, wrap the keyword in brackets:\n\n
        function_call(1, [some: :option], 2)\n\n
    Syntax error after: ",
      ~c"','"
    )
  end

  defp maybe_bad_keyword_data_follow_up(_token, kw, {:__cursor__, _, []} = expr) do
    :lists.reverse([expr | kw])
  end

  defp maybe_bad_keyword_data_follow_up(token, _kw, _expr) do
    return_error(
      location(token),
      ~c"unexpected expression after keyword list. Keyword lists must always come last in lists and maps. Therefore, this is not allowed:\n\n
        [some: :value, :another]\n
        %{some: :value, another => value}\n\n
    Instead, reorder it to be the last entry:\n\n
        [:another, some: :value]\n
        %{another => value, some: :value}\n\n
    Syntax error after: ",
      ~c"','"
    )
  end

  defp error_no_parens_strict(token) do
    return_error(location(token), ~c"unexpected parentheses. If you are making a
  function call, do not insert spaces between the function name and the
  opening parentheses. Syntax error before: ", ~c"'('")
  end

  defp error_no_parens_many_strict(node) do
    return_error_with_meta(
      meta(node),
      ~c"unexpected comma. Parentheses are required to solve ambiguity in nested calls.\n\n
  This error happens when you have nested function calls without parentheses.
  For example:\n\n
      parent_call a, nested_call b, c, d\n\n
  In the example above, we don't know if the parameters \"c\" and \"d\" apply
  to the function \"parent_call\" or \"nested_call\". You can solve this by
  explicitly adding parentheses:\n\n
      parent_call a, nested_call(b, c, d)\n\n
  Or by adding commas (in case a nested call is not intended):\n\n
      parent_call a, nested_call, b, c, d\n\n
  Elixir cannot compile otherwise. Syntax error before: ",
      ~c"','"
    )
  end

  defp error_no_parens_container_strict(node) do
    return_error_with_meta(
      meta(node),
      ~c"unexpected comma. Parentheses are required to solve ambiguity inside containers.\n\n
  This error may happen when you forget a comma in a list or other container:\n\n
      [a, b c, d]\n\n
  Or when you have ambiguous calls:\n\n
      [function a, b, c]\n\n
  In the example above, we don't know if the values \"b\" and \"c\"
  belongs to the list or the function \"function\". You can solve this by explicitly
  adding parentheses:\n\n
      [one, function(a, b, c)]\n\n
  Elixir cannot compile otherwise. Syntax error before: ",
      ~c"','"
    )
  end

  defp error_too_many_access_syntax(comma) do
    return_error(location(comma), ~c"too many arguments when accessing a value.
  The value[key] notation in Elixir expects either a single argument or a keyword list.
  The following examples are allowed:\n\n
      value[one]\n
      value[one: 1, two: 2]\n
      value[[one, two, three]]\n\n
  These are invalid:\n\n
      value[1, 2, 3]\n
      value[one, two, three]\n\n
  Syntax error after: ", ~c"','")
  end

  defp error_invalid_kw_identifier({_, location, ex_do}) do
    return_error(location, :elixir_tokenizer.invalid_do_error(~c"unexpected keyword: "), ~c"do:")
  end

  defp error_invalid_kw_identifier({_, location, kw}) do
    return_error(location, ~c"syntax error before: ", ~c"'#{:erlang.atom_to_list(KW)}:'")
  end

  ## TODO: Make this an error on v2.0
  defp warn_trailing_comma({:",", {line, column, _}}) do
    warn({line, column}, ~c"trailing commas are not allowed inside function/macro call arguments")
  end

  ## TODO: Make this an error on v2.0
  defp warn_pipe({:arrow_op, {line, column, _}, op}, {_, [_ | _], [_ | _]}) do
    warn(
      {line, column},
      :io_lib.format(
        ~c"parentheses are required when piping into a function call. For example:\n\n
          foo 1 ~ts bar 2 ~ts baz 3\n\n
      is ambiguous and should be written as\n\n
          foo(1) ~ts bar(2) ~ts baz(3)\n\n
      Ambiguous pipe found at:",
        [op, op, op, op]
      )
    )
  end

  defp warn_pipe(_token, _), do: :ok

  ## TODO: Make this an error on v2.0
  defp warn_nested_no_parens_keyword(key, value) when is_atom(key) do
    {:line, line} = :lists.keyfind(:line, 1, meta(value))

    warn(
      line,
      ~c"missing parentheses for expression following \"#{:erlang.atom_to_list(key)}:\" keyword.
    Parentheses are required to solve ambiguity inside keywords.\n\n
    This error happens when you have function calls without parentheses inside keywords.
    For example:\n\n
        function(arg, one: nested_call a, b, c)\n
        function(arg, one: if expr, do: :this, else: :that)\n\n
    In the examples above, we don't know if the arguments \"b\" and \"c\" apply
    to the function \"function\" or \"nested_call\". Or if the keywords \"do\" and
    \"else\" apply to the function \"function\" or \"if\". You can solve this by
    explicitly adding parentheses:\n\n
        function(arg, one: if(expr, do: :this, else: :that))\n
        function(arg, one: nested_call(a, b, c))\n\n
    Ambiguity found at:"
    )
  end

  # Key might not be an atom when using literal_encoder, we just skip the warning
  defp warn_nested_no_parens_keyword(_key, _value), do: :ok

  defp warn_empty_paren({_, {line, column, _}}) do
    warn(
      {line, column},
      ~c"invalid expression ().
    If you want to invoke or define a function, make sure there are
    no spaces between the function name and its arguments. If you wanted
    to pass an empty block or code, pass a value instead, such as a nil or an atom"
    )
  end

  defp warn_empty_stab_clause({:stab_op, {line, column, _}, :->}) do
    warn(
      {line, column},
      ~c"an expression is always required on the right side of ->.
    Please provide a value after ->"
    )
  end

  defp warn(line_column, message) do
    case get(:elixir_parser_warning_file) do
      nil -> :ok
      file -> :elixir_errors.erl_warn(line_column, file, message)
    end
  end
end
