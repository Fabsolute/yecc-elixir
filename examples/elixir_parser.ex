defmodule ElixirParser do
  use Yecc

  root :grammar

  expect 3

  nonterminals [
    :grammar,
    :expr_list,
    :expr,
    :container_expr,
    :block_expr,
    :access_expr,
    :no_parens_expr,
    :no_parens_zero_expr,
    :no_parens_one_expr,
    :no_parens_one_ambig_expr,
    :bracket_expr,
    :bracket_at_expr,
    :bracket_arg,
    :matched_expr,
    :unmatched_expr,
    :unmatched_op_expr,
    :matched_op_expr,
    :no_parens_op_expr,
    :no_parens_many_expr,
    :comp_op_eol,
    :at_op_eol,
    :unary_op_eol,
    :and_op_eol,
    :or_op_eol,
    :capture_op_eol,
    :dual_op_eol,
    :mult_op_eol,
    :power_op_eol,
    :concat_op_eol,
    :xor_op_eol,
    :pipe_op_eol,
    :stab_op_eol,
    :arrow_op_eol,
    :match_op_eol,
    :when_op_eol,
    :in_op_eol,
    :in_match_op_eol,
    :type_op_eol,
    :rel_op_eol,
    :range_op_eol,
    :ternary_op_eol,
    :open_paren,
    :close_paren,
    :empty_paren,
    :eoe,
    :list,
    :list_args,
    :open_bracket,
    :close_bracket,
    :tuple,
    :open_curly,
    :close_curly,
    :bitstring,
    :open_bit,
    :close_bit,
    :map,
    :map_op,
    :map_close,
    :map_args,
    :struct_expr,
    :struct_op,
    :assoc_op_eol,
    :assoc_expr,
    :assoc_base,
    :assoc_update,
    :assoc_update_kw,
    :assoc,
    :container_args_base,
    :container_args,
    :call_args_parens_expr,
    :call_args_parens_base,
    :call_args_parens,
    :parens_call,
    :call_args_no_parens_one,
    :call_args_no_parens_ambig,
    :call_args_no_parens_expr,
    :call_args_no_parens_comma_expr,
    :call_args_no_parens_all,
    :call_args_no_parens_many,
    :call_args_no_parens_many_strict,
    :stab,
    :stab_eoe,
    :stab_expr,
    :stab_op_eol_and_expr,
    :stab_parens_many,
    :kw_eol,
    :kw_base,
    :kw_data,
    :kw_call,
    :call_args_no_parens_kw_expr,
    :call_args_no_parens_kw,
    :dot_op,
    :dot_alias,
    :dot_bracket_identifier,
    :dot_call_identifier,
    :dot_identifier,
    :dot_op_identifier,
    :dot_do_identifier,
    :dot_paren_identifier,
    :do_block,
    :fn_eoe,
    :do_eoe,
    :end_eoe,
    :block_eoe,
    :block_item,
    :block_list
  ]

  terminals [
    :identifier,
    :kw_identifier,
    :kw_identifier_safe,
    :kw_identifier_unsafe,
    :bracket_identifier,
    :paren_identifier,
    :do_identifier,
    :block_identifier,
    :op_identifier,
    :fn,
    :end,
    :alias,
    :atom,
    :atom_quoted,
    :atom_safe,
    :atom_unsafe,
    :bin_string,
    :list_string,
    :sigil,
    :bin_heredoc,
    :list_heredoc,
    :comp_op,
    :at_op,
    :unary_op,
    :and_op,
    :or_op,
    :arrow_op,
    :match_op,
    :in_op,
    :in_match_op,
    :type_op,
    :dual_op,
    :mult_op,
    :power_op,
    :concat_op,
    :range_op,
    :xor_op,
    :pipe_op,
    :stab_op,
    :when_op,
    :capture_int,
    :capture_op,
    :assoc_op,
    :rel_op,
    :ternary_op,
    :dot_call_op,
    true,
    false,
    nil,
    :do,
    :eol,
    :";",
    :",",
    :.,
    :"(",
    :")",
    :"[",
    :"]",
    :"{",
    :"}",
    :"<<",
    :">>",
    :%{},
    :%,
    :int,
    :flt,
    :char
  ]

  left :do, 5
  right :stab_op_eol, 10
  left :",", 20
  left :in_match_op_eol, 40
  right :when_op_eol, 50
  right :type_op_eol, 60
  right :pipe_op_eol, 70
  right :assoc_op_eol, 80
  nonassoc :capture_op_eol, 90
  right :match_op_eol, 100
  left :or_op_eol, 120
  left :and_op_eol, 130
  left :comp_op_eol, 140
  left :rel_op_eol, 150
  left :arrow_op_eol, 160
  left :in_op_eol, 170
  left :xor_op_eol, 180
  right :ternary_op_eol, 190
  right :concat_op_eol, 200
  right :range_op_eol, 200
  left :dual_op_eol, 210
  left :mult_op_eol, 220
  left :power_op_eol, 230
  nonassoc :unary_op_eol, 300
  left :dot_call_op, 310
  left :dot_op, 310
  nonassoc :at_op_eol, 320
  nonassoc :dot_identifier, 330

  defr grammar({:eoe, eoe}), do: {:__block__, meta_from_token(eoe), []}
  defr grammar({:expr_list, expr_list}), do: build_block(reverse(expr_list))
  defr grammar(:eoe, {:expr_list, expr_list}), do: build_block(reverse(expr_list))
  defr grammar({:expr_list, expr_list}, :eoe), do: build_block(reverse(expr_list))
  defr grammar(:eoe, {:expr_list, expr_list}, :eoe), do: build_block(reverse(expr_list))
  defr grammar(:__empty__), do: {:__block__, [], []}

  defr expr_list({:expr, expr}), do: [expr]

  defr expr_list({:expr_list, expr_list}, {:eoe, eoe}, {:expr, expr}) do
    [expr | annotate_eoe(eoe, expr_list)]
  end

  defr expr({:matched_expr, matched_expr}), do: matched_expr
  defr expr({:no_parens_expr, no_parens_expr}), do: no_parens_expr
  defr expr({:unmatched_expr, unmatched_expr}), do: unmatched_expr

  defr matched_expr({:matched_expr, matched_expr}, {:matched_op_expr, matched_op_expr}) do
    build_op(matched_expr, matched_op_expr)
  end

  defr matched_expr({:unary_op_eol, unary_op_eol}, {:matched_expr, matched_expr}) do
    build_unary_op(unary_op_eol, matched_expr)
  end

  defr matched_expr({:at_op_eol, at_op_eol}, {:matched_expr, matched_expr}) do
    build_unary_op(at_op_eol, matched_expr)
  end

  defr matched_expr({:capture_op_eol, capture_op_eol}, {:matched_expr, matched_expr}) do
    build_unary_op(capture_op_eol, matched_expr)
  end

  defr matched_expr({:no_parens_one_expr, no_parens_one_expr}), do: no_parens_one_expr
  defr matched_expr({:no_parens_zero_expr, no_parens_zero_expr}), do: no_parens_zero_expr
  defr matched_expr({:access_expr, access_expr}), do: access_expr

  defr matched_expr(:access_expr, {:kw_identifier, kw_identifier}) do
    error_invalid_kw_identifier(kw_identifier)
  end

  defr unmatched_expr({:matched_expr, matched_expr}, {:unmatched_op_expr, unmatched_op_expr}) do
    build_op(matched_expr, unmatched_op_expr)
  end

  defr unmatched_expr({:unmatched_expr, unmatched_expr}, {:matched_op_expr, matched_op_expr}) do
    build_op(unmatched_expr, matched_op_expr)
  end

  defr unmatched_expr({:unmatched_expr, unmatched_expr}, {:unmatched_op_expr, unmatched_op_expr}) do
    build_op(unmatched_expr, unmatched_op_expr)
  end

  defr unmatched_expr({:unmatched_expr, unmatched_expr}, {:no_parens_op_expr, no_parens_op_expr}) do
    warn_no_parens_after_do_op(no_parens_op_expr)
    build_op(unmatched_expr, no_parens_op_expr)
  end

  defr unmatched_expr({:unary_op_eol, unary_op_eol}, {:expr, expr}) do
    build_unary_op(unary_op_eol, expr)
  end

  defr unmatched_expr({:at_op_eol, at_op_eol}, {:expr, expr}), do: build_unary_op(at_op_eol, expr)

  defr unmatched_expr({:capture_op_eol, capture_op_eol}, {:expr, expr}) do
    build_unary_op(capture_op_eol, expr)
  end

  defr unmatched_expr({:block_expr, block_expr}), do: block_expr

  defr no_parens_expr({:matched_expr, matched_expr}, {:no_parens_op_expr, no_parens_op_expr}) do
    build_op(matched_expr, no_parens_op_expr)
  end

  defr no_parens_expr({:unary_op_eol, unary_op_eol}, {:no_parens_expr, no_parens_expr}) do
    build_unary_op(unary_op_eol, no_parens_expr)
  end

  defr no_parens_expr({:at_op_eol, at_op_eol}, {:no_parens_expr, no_parens_expr}) do
    build_unary_op(at_op_eol, no_parens_expr)
  end

  defr no_parens_expr({:capture_op_eol, capture_op_eol}, {:no_parens_expr, no_parens_expr}) do
    build_unary_op(capture_op_eol, no_parens_expr)
  end

  defr no_parens_expr({:no_parens_one_ambig_expr, no_parens_one_ambig_expr}) do
    no_parens_one_ambig_expr
  end

  defr no_parens_expr({:no_parens_many_expr, no_parens_many_expr}), do: no_parens_many_expr

  defr block_expr(
         {:dot_call_identifier, dot_call_identifier},
         {:call_args_parens, call_args_parens},
         {:do_block, do_block}
       ) do
    build_parens(dot_call_identifier, call_args_parens, do_block)
  end

  defr block_expr(
         {:dot_call_identifier, dot_call_identifier},
         {:call_args_parens, call_args_parens},
         {:call_args_parens, call_args_parens},
         {:do_block, do_block}
       ) do
    build_nested_parens(dot_call_identifier, call_args_parens, call_args_parens, do_block)
  end

  defr block_expr({:dot_do_identifier, dot_do_identifier}, {:do_block, do_block}) do
    build_no_parens_do_block(dot_do_identifier, [], do_block)
  end

  defr block_expr(
         {:dot_op_identifier, dot_op_identifier},
         {:call_args_no_parens_all, call_args_no_parens_all},
         {:do_block, do_block}
       ) do
    build_no_parens_do_block(dot_op_identifier, call_args_no_parens_all, do_block)
  end

  defr block_expr(
         {:dot_identifier, dot_identifier},
         {:call_args_no_parens_all, call_args_no_parens_all},
         {:do_block, do_block}
       ) do
    build_no_parens_do_block(dot_identifier, call_args_no_parens_all, do_block)
  end

  defr matched_op_expr({:match_op_eol, match_op_eol}, {:matched_expr, matched_expr}) do
    {match_op_eol, matched_expr}
  end

  defr matched_op_expr({:dual_op_eol, dual_op_eol}, {:matched_expr, matched_expr}) do
    {dual_op_eol, matched_expr}
  end

  defr matched_op_expr({:mult_op_eol, mult_op_eol}, {:matched_expr, matched_expr}) do
    {mult_op_eol, matched_expr}
  end

  defr matched_op_expr({:power_op_eol, power_op_eol}, {:matched_expr, matched_expr}) do
    {power_op_eol, matched_expr}
  end

  defr matched_op_expr({:concat_op_eol, concat_op_eol}, {:matched_expr, matched_expr}) do
    {concat_op_eol, matched_expr}
  end

  defr matched_op_expr({:range_op_eol, range_op_eol}, {:matched_expr, matched_expr}) do
    {range_op_eol, matched_expr}
  end

  defr matched_op_expr({:ternary_op_eol, ternary_op_eol}, {:matched_expr, matched_expr}) do
    {ternary_op_eol, matched_expr}
  end

  defr matched_op_expr({:xor_op_eol, xor_op_eol}, {:matched_expr, matched_expr}) do
    {xor_op_eol, matched_expr}
  end

  defr matched_op_expr({:and_op_eol, and_op_eol}, {:matched_expr, matched_expr}) do
    {and_op_eol, matched_expr}
  end

  defr matched_op_expr({:or_op_eol, or_op_eol}, {:matched_expr, matched_expr}) do
    {or_op_eol, matched_expr}
  end

  defr matched_op_expr({:in_op_eol, in_op_eol}, {:matched_expr, matched_expr}) do
    {in_op_eol, matched_expr}
  end

  defr matched_op_expr({:in_match_op_eol, in_match_op_eol}, {:matched_expr, matched_expr}) do
    {in_match_op_eol, matched_expr}
  end

  defr matched_op_expr({:type_op_eol, type_op_eol}, {:matched_expr, matched_expr}) do
    {type_op_eol, matched_expr}
  end

  defr matched_op_expr({:when_op_eol, when_op_eol}, {:matched_expr, matched_expr}) do
    {when_op_eol, matched_expr}
  end

  defr matched_op_expr({:pipe_op_eol, pipe_op_eol}, {:matched_expr, matched_expr}) do
    {pipe_op_eol, matched_expr}
  end

  defr matched_op_expr({:comp_op_eol, comp_op_eol}, {:matched_expr, matched_expr}) do
    {comp_op_eol, matched_expr}
  end

  defr matched_op_expr({:rel_op_eol, rel_op_eol}, {:matched_expr, matched_expr}) do
    {rel_op_eol, matched_expr}
  end

  defr matched_op_expr({:arrow_op_eol, arrow_op_eol}, {:matched_expr, matched_expr}) do
    {arrow_op_eol, matched_expr}
  end

  defr matched_op_expr({:arrow_op_eol, arrow_op_eol}, {:no_parens_one_expr, no_parens_one_expr}) do
    warn_pipe(arrow_op_eol, no_parens_one_expr)
    {arrow_op_eol, no_parens_one_expr}
  end

  defr unmatched_op_expr({:match_op_eol, match_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {match_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:dual_op_eol, dual_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {dual_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:mult_op_eol, mult_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {mult_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:power_op_eol, power_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {power_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:concat_op_eol, concat_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {concat_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:range_op_eol, range_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {range_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:ternary_op_eol, ternary_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {ternary_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:xor_op_eol, xor_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {xor_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:and_op_eol, and_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {and_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:or_op_eol, or_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {or_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:in_op_eol, in_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {in_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:in_match_op_eol, in_match_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {in_match_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:type_op_eol, type_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {type_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:when_op_eol, when_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {when_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:pipe_op_eol, pipe_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {pipe_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:comp_op_eol, comp_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {comp_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:rel_op_eol, rel_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {rel_op_eol, unmatched_expr}
  end

  defr unmatched_op_expr({:arrow_op_eol, arrow_op_eol}, {:unmatched_expr, unmatched_expr}) do
    {arrow_op_eol, unmatched_expr}
  end

  defr no_parens_op_expr({:match_op_eol, match_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {match_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:dual_op_eol, dual_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {dual_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:mult_op_eol, mult_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {mult_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:power_op_eol, power_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {power_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:concat_op_eol, concat_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {concat_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:range_op_eol, range_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {range_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:ternary_op_eol, ternary_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {ternary_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:xor_op_eol, xor_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {xor_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:and_op_eol, and_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {and_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:or_op_eol, or_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {or_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:in_op_eol, in_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {in_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:in_match_op_eol, in_match_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {in_match_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:type_op_eol, type_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {type_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:when_op_eol, when_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {when_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:pipe_op_eol, pipe_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {pipe_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:comp_op_eol, comp_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {comp_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:rel_op_eol, rel_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {rel_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr({:arrow_op_eol, arrow_op_eol}, {:no_parens_expr, no_parens_expr}) do
    {arrow_op_eol, no_parens_expr}
  end

  defr no_parens_op_expr(
         {:arrow_op_eol, arrow_op_eol},
         {:no_parens_one_ambig_expr, no_parens_one_ambig_expr}
       ) do
    warn_pipe(arrow_op_eol, no_parens_one_ambig_expr)
    {arrow_op_eol, no_parens_one_ambig_expr}
  end

  defr no_parens_op_expr(
         {:arrow_op_eol, arrow_op_eol},
         {:no_parens_many_expr, no_parens_many_expr}
       ) do
    warn_pipe(arrow_op_eol, no_parens_many_expr)
    {arrow_op_eol, no_parens_many_expr}
  end

  defr no_parens_op_expr(
         {:when_op_eol, when_op_eol},
         {:call_args_no_parens_kw, call_args_no_parens_kw}
       ) do
    {when_op_eol, call_args_no_parens_kw}
  end

  defr no_parens_one_ambig_expr(
         {:dot_op_identifier, dot_op_identifier},
         {:call_args_no_parens_ambig, call_args_no_parens_ambig}
       ) do
    build_no_parens(dot_op_identifier, call_args_no_parens_ambig)
  end

  defr no_parens_one_ambig_expr(
         {:dot_identifier, dot_identifier},
         {:call_args_no_parens_ambig, call_args_no_parens_ambig}
       ) do
    build_no_parens(dot_identifier, call_args_no_parens_ambig)
  end

  defr no_parens_many_expr(
         {:dot_op_identifier, dot_op_identifier},
         {:call_args_no_parens_many_strict, call_args_no_parens_many_strict}
       ) do
    build_no_parens(dot_op_identifier, call_args_no_parens_many_strict)
  end

  defr no_parens_many_expr(
         {:dot_identifier, dot_identifier},
         {:call_args_no_parens_many_strict, call_args_no_parens_many_strict}
       ) do
    build_no_parens(dot_identifier, call_args_no_parens_many_strict)
  end

  defr no_parens_one_expr(
         {:dot_op_identifier, dot_op_identifier},
         {:call_args_no_parens_one, call_args_no_parens_one}
       ) do
    build_no_parens(dot_op_identifier, call_args_no_parens_one)
  end

  defr no_parens_one_expr(
         {:dot_identifier, dot_identifier},
         {:call_args_no_parens_one, call_args_no_parens_one}
       ) do
    build_no_parens(dot_identifier, call_args_no_parens_one)
  end

  defr no_parens_zero_expr({:dot_do_identifier, dot_do_identifier}) do
    build_no_parens(dot_do_identifier, nil)
  end

  defr no_parens_zero_expr({:dot_identifier, dot_identifier}) do
    build_no_parens(dot_identifier, nil)
  end

  defr access_expr({:bracket_at_expr, bracket_at_expr}), do: bracket_at_expr
  defr access_expr({:bracket_expr, bracket_expr}), do: bracket_expr

  defr access_expr({:capture_int, capture_int}, {:int, int}) do
    build_unary_op(capture_int, number_value(int))
  end

  defr access_expr({:fn_eoe, fn_eoe}, {:stab, stab}, {:end_eoe, end_eoe}) do
    build_fn(fn_eoe, stab, end_eoe)
  end

  defr access_expr({:open_paren, open_paren}, {:stab, stab}, {:close_paren, close_paren}) do
    build_paren_stab(open_paren, stab, close_paren)
  end

  defr access_expr({:open_paren, open_paren}, {:stab, stab}, :";", {:close_paren, close_paren}) do
    build_paren_stab(open_paren, stab, close_paren)
  end

  defr access_expr(
         {:open_paren, open_paren},
         :";",
         {:stab, stab},
         :";",
         {:close_paren, close_paren}
       ) do
    build_paren_stab(open_paren, stab, close_paren)
  end

  defr access_expr({:open_paren, open_paren}, :";", {:stab, stab}, {:close_paren, close_paren}) do
    build_paren_stab(open_paren, stab, close_paren)
  end

  defr access_expr({:open_paren, open_paren}, :";", {:close_paren, close_paren}) do
    build_paren_stab(open_paren, [], close_paren)
  end

  defr access_expr({:empty_paren, empty_paren}) do
    warn_empty_paren(empty_paren)
    {:__block__, [], []}
  end

  defr access_expr({:int, int}), do: handle_number(number_value(int), int, exprs(int))
  defr access_expr({:flt, flt}), do: handle_number(number_value(flt), flt, exprs(flt))
  defr access_expr({:char, char}), do: handle_number(exprs(char), char, number_value(char))
  defr access_expr({:list, list}), do: element(1, list)
  defr access_expr({:map, map}), do: map
  defr access_expr({:tuple, tuple}), do: tuple
  defr access_expr({true, ex_true}), do: handle_literal(id(ex_true), ex_true)
  defr access_expr({false, ex_false}), do: handle_literal(id(ex_false), ex_false)
  defr access_expr({nil, ex_nil}), do: handle_literal(id(ex_nil), ex_nil)
  defr access_expr({:bin_string, bin_string}), do: build_bin_string(bin_string, delimiter(<<?">>))

  defr access_expr({:list_string, list_string}) do
    build_list_string(list_string, delimiter(<<?'>>))
  end

  defr access_expr({:bin_heredoc, bin_heredoc}), do: build_bin_heredoc(bin_heredoc)
  defr access_expr({:list_heredoc, list_heredoc}), do: build_list_heredoc(list_heredoc)
  defr access_expr({:bitstring, bitstring}), do: bitstring
  defr access_expr({:sigil, sigil}), do: build_sigil(sigil)
  defr access_expr({:atom, atom}), do: handle_literal(exprs(atom), atom)

  defr access_expr({:atom_quoted, atom_quoted}) do
    handle_literal(exprs(atom_quoted), atom_quoted, delimiter(<<?">>))
  end

  defr access_expr({:atom_safe, atom_safe}) do
    build_quoted_atom(atom_safe, true, delimiter(<<?">>))
  end

  defr access_expr({:atom_unsafe, atom_unsafe}) do
    build_quoted_atom(atom_unsafe, false, delimiter(<<?">>))
  end

  defr access_expr({:dot_alias, dot_alias}), do: dot_alias
  defr access_expr({:parens_call, parens_call}), do: parens_call
  defr access_expr({:range_op, range_op}), do: build_nullary_op(range_op)

  defr parens_call(
         {:dot_call_identifier, dot_call_identifier},
         {:call_args_parens, call_args_parens}
       ) do
    build_parens(dot_call_identifier, call_args_parens, {[], []})
  end

  defr parens_call(
         {:dot_call_identifier, dot_call_identifier},
         {:call_args_parens, call_args_parens},
         {:call_args_parens, call_args_parens}
       ) do
    build_nested_parens(dot_call_identifier, call_args_parens, call_args_parens, {[], []})
  end

  defr bracket_arg(
         {:open_bracket, open_bracket},
         {:kw_data, kw_data},
         {:close_bracket, close_bracket}
       ) do
    build_access_arg(open_bracket, kw_data, close_bracket)
  end

  defr bracket_arg(
         {:open_bracket, open_bracket},
         {:container_expr, container_expr},
         {:close_bracket, close_bracket}
       ) do
    build_access_arg(open_bracket, container_expr, close_bracket)
  end

  defr bracket_arg(
         {:open_bracket, open_bracket},
         {:container_expr, container_expr},
         :",",
         {:close_bracket, close_bracket}
       ) do
    build_access_arg(open_bracket, container_expr, close_bracket)
  end

  defr bracket_arg(
         :open_bracket,
         :container_expr,
         {:",", pn_comma},
         :container_args,
         :close_bracket
       ) do
    error_too_many_access_syntax(pn_comma)
  end

  defr bracket_expr(
         {:dot_bracket_identifier, dot_bracket_identifier},
         {:bracket_arg, bracket_arg}
       ) do
    build_access(build_no_parens(dot_bracket_identifier, nil), bracket_arg)
  end

  defr bracket_expr({:access_expr, access_expr}, {:bracket_arg, bracket_arg}) do
    build_access(access_expr, meta_with_from_brackets(bracket_arg))
  end

  defr bracket_at_expr(
         {:at_op_eol, at_op_eol},
         {:dot_bracket_identifier, dot_bracket_identifier},
         {:bracket_arg, bracket_arg}
       ) do
    build_access(
      build_unary_op(at_op_eol, build_no_parens(dot_bracket_identifier, nil)),
      bracket_arg
    )
  end

  defr bracket_at_expr(
         {:at_op_eol, at_op_eol},
         {:access_expr, access_expr},
         {:bracket_arg, bracket_arg}
       ) do
    build_access(build_unary_op(at_op_eol, access_expr), bracket_arg)
  end

  defr do_block({:do_eoe, do_eoe}, {:end, ex_end}) do
    {do_end_meta(do_eoe, ex_end), [[{handle_literal(:do, do_eoe), {:__block__, [], []}}]]}
  end

  defr do_block({:do_eoe, do_eoe}, {:stab, stab}, {:end_eoe, end_eoe}) do
    {do_end_meta(do_eoe, end_eoe), [[{handle_literal(:do, do_eoe), build_stab(stab)}]]}
  end

  defr do_block({:do_eoe, do_eoe}, {:block_list, block_list}, {:end, ex_end}) do
    {do_end_meta(do_eoe, ex_end),
     [[{handle_literal(:do, do_eoe), {:__block__, [], []}} | block_list]]}
  end

  defr do_block(
         {:do_eoe, do_eoe},
         {:stab_eoe, stab_eoe},
         {:block_list, block_list},
         {:end, ex_end}
       ) do
    {do_end_meta(do_eoe, ex_end),
     [[{handle_literal(:do, do_eoe), build_stab(stab_eoe)} | block_list]]}
  end

  defr eoe({:eol, eol}), do: eol
  defr eoe({:";", pn_semicolon}), do: pn_semicolon
  defr eoe({:eol, eol}, :";"), do: eol

  defr fn_eoe({:fn, ex_fn}), do: ex_fn
  defr fn_eoe({:fn, ex_fn}, {:eoe, eoe}), do: next_is_eol(ex_fn, eoe)

  defr do_eoe({:do, ex_do}), do: ex_do
  defr do_eoe({:do, ex_do}, :eoe), do: ex_do

  defr end_eoe({:end, ex_end}), do: ex_end
  defr end_eoe(:eoe, {:end, ex_end}), do: ex_end

  defr block_eoe({:block_identifier, block_identifier}), do: block_identifier
  defr block_eoe({:block_identifier, block_identifier}, :eoe), do: block_identifier

  defr stab({:stab_expr, stab_expr}), do: [stab_expr]

  defr stab({:stab, stab}, {:eoe, eoe}, {:stab_expr, stab_expr}) do
    [stab_expr | annotate_eoe(eoe, stab)]
  end

  defr stab_eoe({:stab, stab}), do: stab
  defr stab_eoe({:stab, stab}, :eoe), do: stab

  defr stab_expr({:expr, expr}), do: expr

  defr stab_expr({:stab_op_eol_and_expr, stab_op_eol_and_expr}) do
    build_op([], stab_op_eol_and_expr)
  end

  defr stab_expr(:empty_paren, {:stab_op_eol_and_expr, stab_op_eol_and_expr}) do
    build_op([], stab_op_eol_and_expr)
  end

  defr stab_expr(
         :empty_paren,
         {:when_op, when_op},
         {:expr, expr},
         {:stab_op_eol_and_expr, stab_op_eol_and_expr}
       ) do
    build_op([{:when, meta_from_token(when_op), [expr]}], stab_op_eol_and_expr)
  end

  defr stab_expr(
         {:call_args_no_parens_all, call_args_no_parens_all},
         {:stab_op_eol_and_expr, stab_op_eol_and_expr}
       ) do
    build_op(unwrap_when(unwrap_splice(call_args_no_parens_all)), stab_op_eol_and_expr)
  end

  defr stab_expr(
         {:stab_parens_many, stab_parens_many},
         {:stab_op_eol_and_expr, stab_op_eol_and_expr}
       ) do
    build_op(unwrap_splice(stab_parens_many), stab_op_eol_and_expr)
  end

  defr stab_expr(
         {:stab_parens_many, stab_parens_many},
         {:when_op, when_op},
         {:expr, expr},
         {:stab_op_eol_and_expr, stab_op_eol_and_expr}
       ) do
    build_op(
      [{:when, meta_from_token(when_op), unwrap_splice(stab_parens_many) ++ [expr]}],
      stab_op_eol_and_expr
    )
  end

  defr stab_op_eol_and_expr({:stab_op_eol, stab_op_eol}, {:expr, expr}), do: {stab_op_eol, expr}

  defr stab_op_eol_and_expr({:stab_op_eol, stab_op_eol}) do
    warn_empty_stab_clause(stab_op_eol)
    {stab_op_eol, handle_literal(nil, stab_op_eol)}
  end

  defr block_item({:block_eoe, block_eoe}, {:stab_eoe, stab_eoe}) do
    {handle_literal(exprs(block_eoe), block_eoe), build_stab(stab_eoe)}
  end

  defr block_item({:block_eoe, block_eoe}) do
    {handle_literal(exprs(block_eoe), block_eoe), {:__block__, [], []}}
  end

  defr block_list({:block_item, block_item}), do: [block_item]

  defr block_list({:block_item, block_item}, {:block_list, block_list}) do
    [block_item | block_list]
  end

  defr open_paren({:"(", pn_left_paren}), do: pn_left_paren
  defr open_paren({:"(", pn_left_paren}, {:eol, eol}), do: next_is_eol(pn_left_paren, eol)

  defr close_paren({:")", pn_right_paren}), do: pn_right_paren
  defr close_paren(:eol, {:")", pn_right_paren}), do: pn_right_paren

  defr empty_paren({:open_paren, open_paren}, :")"), do: open_paren

  defr open_bracket({:"[", pn_left_bracket}), do: pn_left_bracket
  defr open_bracket({:"[", pn_left_bracket}, {:eol, eol}), do: next_is_eol(pn_left_bracket, eol)

  defr close_bracket({:"]", pn_right_bracket}), do: pn_right_bracket
  defr close_bracket(:eol, {:"]", pn_right_bracket}), do: pn_right_bracket

  defr open_bit({:"<<", pn_left_shift}), do: pn_left_shift
  defr open_bit({:"<<", pn_left_shift}, {:eol, eol}), do: next_is_eol(pn_left_shift, eol)

  defr close_bit({:">>", pn_right_shift}), do: pn_right_shift
  defr close_bit(:eol, {:">>", pn_right_shift}), do: pn_right_shift

  defr open_curly({:"{", pn_left_brace}), do: pn_left_brace
  defr open_curly({:"{", pn_left_brace}, {:eol, eol}), do: next_is_eol(pn_left_brace, eol)

  defr close_curly({:"}", pn_right_brace}), do: pn_right_brace
  defr close_curly(:eol, {:"}", pn_right_brace}), do: pn_right_brace

  defr unary_op_eol({:unary_op, unary_op}), do: unary_op
  defr unary_op_eol({:unary_op, unary_op}, :eol), do: unary_op
  defr unary_op_eol({:dual_op, dual_op}), do: dual_op
  defr unary_op_eol({:dual_op, dual_op}, :eol), do: dual_op
  defr unary_op_eol({:ternary_op, ternary_op}), do: ternary_op
  defr unary_op_eol({:ternary_op, ternary_op}, :eol), do: ternary_op

  defr capture_op_eol({:capture_op, capture_op}), do: capture_op
  defr capture_op_eol({:capture_op, capture_op}, :eol), do: capture_op

  defr at_op_eol({:at_op, at_op}), do: at_op
  defr at_op_eol({:at_op, at_op}, :eol), do: at_op

  defr match_op_eol({:match_op, match_op}), do: match_op
  defr match_op_eol({:match_op, match_op}, {:eol, eol}), do: next_is_eol(match_op, eol)

  defr dual_op_eol({:dual_op, dual_op}), do: dual_op
  defr dual_op_eol({:dual_op, dual_op}, {:eol, eol}), do: next_is_eol(dual_op, eol)

  defr mult_op_eol({:mult_op, mult_op}), do: mult_op
  defr mult_op_eol({:mult_op, mult_op}, {:eol, eol}), do: next_is_eol(mult_op, eol)

  defr power_op_eol({:power_op, power_op}), do: power_op
  defr power_op_eol({:power_op, power_op}, {:eol, eol}), do: next_is_eol(power_op, eol)

  defr concat_op_eol({:concat_op, concat_op}), do: concat_op
  defr concat_op_eol({:concat_op, concat_op}, {:eol, eol}), do: next_is_eol(concat_op, eol)

  defr range_op_eol({:range_op, range_op}), do: range_op
  defr range_op_eol({:range_op, range_op}, {:eol, eol}), do: next_is_eol(range_op, eol)

  defr ternary_op_eol({:ternary_op, ternary_op}), do: ternary_op
  defr ternary_op_eol({:ternary_op, ternary_op}, {:eol, eol}), do: next_is_eol(ternary_op, eol)

  defr xor_op_eol({:xor_op, xor_op}), do: xor_op
  defr xor_op_eol({:xor_op, xor_op}, {:eol, eol}), do: next_is_eol(xor_op, eol)

  defr pipe_op_eol({:pipe_op, pipe_op}), do: pipe_op
  defr pipe_op_eol({:pipe_op, pipe_op}, {:eol, eol}), do: next_is_eol(pipe_op, eol)

  defr and_op_eol({:and_op, and_op}), do: and_op
  defr and_op_eol({:and_op, and_op}, {:eol, eol}), do: next_is_eol(and_op, eol)

  defr or_op_eol({:or_op, or_op}), do: or_op
  defr or_op_eol({:or_op, or_op}, {:eol, eol}), do: next_is_eol(or_op, eol)

  defr in_op_eol({:in_op, in_op}), do: in_op
  defr in_op_eol({:in_op, in_op}, {:eol, eol}), do: next_is_eol(in_op, eol)

  defr in_match_op_eol({:in_match_op, in_match_op}), do: in_match_op

  defr in_match_op_eol({:in_match_op, in_match_op}, {:eol, eol}),
    do: next_is_eol(in_match_op, eol)

  defr type_op_eol({:type_op, type_op}), do: type_op
  defr type_op_eol({:type_op, type_op}, {:eol, eol}), do: next_is_eol(type_op, eol)

  defr when_op_eol({:when_op, when_op}), do: when_op
  defr when_op_eol({:when_op, when_op}, {:eol, eol}), do: next_is_eol(when_op, eol)

  defr stab_op_eol({:stab_op, stab_op}), do: stab_op
  defr stab_op_eol({:stab_op, stab_op}, {:eol, eol}), do: next_is_eol(stab_op, eol)

  defr comp_op_eol({:comp_op, comp_op}), do: comp_op
  defr comp_op_eol({:comp_op, comp_op}, {:eol, eol}), do: next_is_eol(comp_op, eol)

  defr rel_op_eol({:rel_op, rel_op}), do: rel_op
  defr rel_op_eol({:rel_op, rel_op}, {:eol, eol}), do: next_is_eol(rel_op, eol)

  defr arrow_op_eol({:arrow_op, arrow_op}), do: arrow_op
  defr arrow_op_eol({:arrow_op, arrow_op}, {:eol, eol}), do: next_is_eol(arrow_op, eol)

  defr dot_op({:., pn_dot}), do: pn_dot
  defr dot_op({:., pn_dot}, :eol), do: pn_dot

  defr dot_identifier({:identifier, identifier}), do: identifier

  defr dot_identifier({:matched_expr, matched_expr}, {:dot_op, dot_op}, {:identifier, identifier}) do
    build_dot(dot_op, matched_expr, identifier)
  end

  defr dot_alias({:alias, alias}), do: build_alias(alias)

  defr dot_alias({:matched_expr, matched_expr}, {:dot_op, dot_op}, {:alias, alias}) do
    build_dot_alias(dot_op, matched_expr, alias)
  end

  defr dot_alias({:matched_expr, matched_expr}, {:dot_op, dot_op}, :open_curly, :"}") do
    build_dot_container(dot_op, matched_expr, [], [])
  end

  defr dot_alias(
         {:matched_expr, matched_expr},
         {:dot_op, dot_op},
         {:open_curly, open_curly},
         {:container_args, container_args},
         {:close_curly, close_curly}
       ) do
    build_dot_container(
      dot_op,
      matched_expr,
      container_args,
      newlines_pair(open_curly, close_curly)
    )
  end

  defr dot_op_identifier({:op_identifier, op_identifier}), do: op_identifier

  defr dot_op_identifier(
         {:matched_expr, matched_expr},
         {:dot_op, dot_op},
         {:op_identifier, op_identifier}
       ) do
    build_dot(dot_op, matched_expr, op_identifier)
  end

  defr dot_do_identifier({:do_identifier, do_identifier}), do: do_identifier

  defr dot_do_identifier(
         {:matched_expr, matched_expr},
         {:dot_op, dot_op},
         {:do_identifier, do_identifier}
       ) do
    build_dot(dot_op, matched_expr, do_identifier)
  end

  defr dot_bracket_identifier({:bracket_identifier, bracket_identifier}), do: bracket_identifier

  defr dot_bracket_identifier(
         {:matched_expr, matched_expr},
         {:dot_op, dot_op},
         {:bracket_identifier, bracket_identifier}
       ) do
    build_dot(dot_op, matched_expr, bracket_identifier)
  end

  defr dot_paren_identifier({:paren_identifier, paren_identifier}), do: paren_identifier

  defr dot_paren_identifier(
         {:matched_expr, matched_expr},
         {:dot_op, dot_op},
         {:paren_identifier, paren_identifier}
       ) do
    build_dot(dot_op, matched_expr, paren_identifier)
  end

  defr dot_call_identifier({:dot_paren_identifier, dot_paren_identifier}) do
    dot_paren_identifier
  end

  defr dot_call_identifier({:matched_expr, matched_expr}, {:dot_call_op, dot_call_op}) do
    {:., meta_from_token(dot_call_op), [matched_expr]}
  end

  defr call_args_no_parens_expr({:matched_expr, matched_expr}), do: matched_expr

  defr call_args_no_parens_expr({:no_parens_expr, no_parens_expr}) do
    error_no_parens_many_strict(no_parens_expr)
  end

  defr call_args_no_parens_comma_expr(
         {:matched_expr, matched_expr},
         :",",
         {:call_args_no_parens_expr, call_args_no_parens_expr}
       ) do
    [call_args_no_parens_expr, matched_expr]
  end

  defr call_args_no_parens_comma_expr(
         {:call_args_no_parens_comma_expr, call_args_no_parens_comma_expr},
         :",",
         {:call_args_no_parens_expr, call_args_no_parens_expr}
       ) do
    [call_args_no_parens_expr | call_args_no_parens_comma_expr]
  end

  defr call_args_no_parens_all({:call_args_no_parens_one, call_args_no_parens_one}) do
    call_args_no_parens_one
  end

  defr call_args_no_parens_all({:call_args_no_parens_ambig, call_args_no_parens_ambig}) do
    call_args_no_parens_ambig
  end

  defr call_args_no_parens_all({:call_args_no_parens_many, call_args_no_parens_many}) do
    call_args_no_parens_many
  end

  defr call_args_no_parens_one({:call_args_no_parens_kw, call_args_no_parens_kw}) do
    [call_args_no_parens_kw]
  end

  defr call_args_no_parens_one({:matched_expr, matched_expr}), do: [matched_expr]

  defr call_args_no_parens_ambig({:no_parens_expr, no_parens_expr}), do: [no_parens_expr]

  defr call_args_no_parens_many(
         {:matched_expr, matched_expr},
         :",",
         {:call_args_no_parens_kw, call_args_no_parens_kw}
       ) do
    [matched_expr, call_args_no_parens_kw]
  end

  defr call_args_no_parens_many({:call_args_no_parens_comma_expr, call_args_no_parens_comma_expr}) do
    reverse(call_args_no_parens_comma_expr)
  end

  defr call_args_no_parens_many(
         {:call_args_no_parens_comma_expr, call_args_no_parens_comma_expr},
         :",",
         {:call_args_no_parens_kw, call_args_no_parens_kw}
       ) do
    reverse([call_args_no_parens_kw | call_args_no_parens_comma_expr])
  end

  defr call_args_no_parens_many_strict({:call_args_no_parens_many, call_args_no_parens_many}) do
    call_args_no_parens_many
  end

  defr call_args_no_parens_many_strict(
         {:open_paren, open_paren},
         :call_args_no_parens_kw,
         :close_paren
       ) do
    error_no_parens_strict(open_paren)
  end

  defr call_args_no_parens_many_strict(
         {:open_paren, open_paren},
         :call_args_no_parens_many,
         :close_paren
       ) do
    error_no_parens_strict(open_paren)
  end

  defr stab_parens_many(
         :open_paren,
         {:call_args_no_parens_kw, call_args_no_parens_kw},
         :close_paren
       ) do
    [call_args_no_parens_kw]
  end

  defr stab_parens_many(
         :open_paren,
         {:call_args_no_parens_many, call_args_no_parens_many},
         :close_paren
       ) do
    call_args_no_parens_many
  end

  defr container_expr({:matched_expr, matched_expr}), do: matched_expr
  defr container_expr({:unmatched_expr, unmatched_expr}), do: unmatched_expr

  defr container_expr({:no_parens_expr, no_parens_expr}) do
    error_no_parens_container_strict(no_parens_expr)
  end

  defr container_args_base({:container_expr, container_expr}), do: [container_expr]

  defr container_args_base(
         {:container_args_base, container_args_base},
         :",",
         {:container_expr, container_expr}
       ) do
    [container_expr | container_args_base]
  end

  defr container_args({:container_args_base, container_args_base}) do
    reverse(container_args_base)
  end

  defr container_args({:container_args_base, container_args_base}, :",") do
    reverse(container_args_base)
  end

  defr container_args({:container_args_base, container_args_base}, :",", {:kw_data, kw_data}) do
    reverse([kw_data | container_args_base])
  end

  defr call_args_parens_expr({:matched_expr, matched_expr}), do: matched_expr
  defr call_args_parens_expr({:unmatched_expr, unmatched_expr}), do: unmatched_expr

  defr call_args_parens_expr({:no_parens_expr, no_parens_expr}) do
    error_no_parens_many_strict(no_parens_expr)
  end

  defr call_args_parens_base({:call_args_parens_expr, call_args_parens_expr}) do
    [call_args_parens_expr]
  end

  defr call_args_parens_base(
         {:call_args_parens_base, call_args_parens_base},
         :",",
         {:call_args_parens_expr, call_args_parens_expr}
       ) do
    [call_args_parens_expr | call_args_parens_base]
  end

  defr call_args_parens({:open_paren, open_paren}, {:")", pn_right_paren}) do
    {newlines_pair(open_paren, pn_right_paren), []}
  end

  defr call_args_parens(
         {:open_paren, open_paren},
         {:no_parens_expr, no_parens_expr},
         {:close_paren, close_paren}
       ) do
    {newlines_pair(open_paren, close_paren), [no_parens_expr]}
  end

  defr call_args_parens(
         {:open_paren, open_paren},
         {:kw_call, kw_call},
         {:close_paren, close_paren}
       ) do
    {newlines_pair(open_paren, close_paren), [kw_call]}
  end

  defr call_args_parens(
         {:open_paren, open_paren},
         {:call_args_parens_base, call_args_parens_base},
         {:close_paren, close_paren}
       ) do
    {newlines_pair(open_paren, close_paren), reverse(call_args_parens_base)}
  end

  defr call_args_parens(
         {:open_paren, open_paren},
         {:call_args_parens_base, call_args_parens_base},
         :",",
         {:kw_call, kw_call},
         {:close_paren, close_paren}
       ) do
    {newlines_pair(open_paren, close_paren), reverse([kw_call | call_args_parens_base])}
  end

  defr kw_eol({:kw_identifier, kw_identifier}) do
    handle_literal(exprs(kw_identifier), kw_identifier, [{format, keyword}])
  end

  defr kw_eol({:kw_identifier, kw_identifier}, :eol) do
    handle_literal(exprs(kw_identifier), kw_identifier, [{format, keyword}])
  end

  defr kw_eol({:kw_identifier_safe, kw_identifier_safe}) do
    build_quoted_atom(kw_identifier_safe, true, [{format, keyword}])
  end

  defr kw_eol({:kw_identifier_safe, kw_identifier_safe}, :eol) do
    build_quoted_atom(kw_identifier_safe, true, [{format, keyword}])
  end

  defr kw_eol({:kw_identifier_unsafe, kw_identifier_unsafe}) do
    build_quoted_atom(kw_identifier_unsafe, false, [{format, keyword}])
  end

  defr kw_eol({:kw_identifier_unsafe, kw_identifier_unsafe}, :eol) do
    build_quoted_atom(kw_identifier_unsafe, false, [{format, keyword}])
  end

  defr kw_base({:kw_eol, kw_eol}, {:container_expr, container_expr}) do
    [{kw_eol, container_expr}]
  end

  defr kw_base({:kw_base, kw_base}, :",", {:kw_eol, kw_eol}, {:container_expr, container_expr}) do
    [{kw_eol, container_expr} | kw_base]
  end

  defr kw_call({:kw_base, kw_base}), do: reverse(kw_base)

  defr kw_call({:kw_base, kw_base}, {:",", pn_comma}) do
    warn_trailing_comma(pn_comma)
    reverse(kw_base)
  end

  defr kw_call({:kw_base, kw_base}, {:",", pn_comma}, {:matched_expr, matched_expr}) do
    maybe_bad_keyword_call_follow_up(pn_comma, kw_base, matched_expr)
  end

  defr kw_data({:kw_base, kw_base}), do: reverse(kw_base)
  defr kw_data({:kw_base, kw_base}, :","), do: reverse(kw_base)

  defr kw_data({:kw_base, kw_base}, {:",", pn_comma}, {:matched_expr, matched_expr}) do
    maybe_bad_keyword_data_follow_up(pn_comma, kw_base, matched_expr)
  end

  defr call_args_no_parens_kw_expr({:kw_eol, kw_eol}, {:matched_expr, matched_expr}) do
    {kw_eol, matched_expr}
  end

  defr call_args_no_parens_kw_expr({:kw_eol, kw_eol}, {:no_parens_expr, no_parens_expr}) do
    warn_nested_no_parens_keyword(kw_eol, no_parens_expr)
    {kw_eol, no_parens_expr}
  end

  defr call_args_no_parens_kw({:call_args_no_parens_kw_expr, call_args_no_parens_kw_expr}) do
    [call_args_no_parens_kw_expr]
  end

  defr call_args_no_parens_kw(
         {:call_args_no_parens_kw_expr, call_args_no_parens_kw_expr},
         :",",
         {:call_args_no_parens_kw, call_args_no_parens_kw}
       ) do
    [call_args_no_parens_kw_expr | call_args_no_parens_kw]
  end

  defr call_args_no_parens_kw(
         {:call_args_no_parens_kw_expr, call_args_no_parens_kw_expr},
         {:",", pn_comma},
         {:matched_expr, matched_expr}
       ) do
    maybe_bad_keyword_call_follow_up(pn_comma, [call_args_no_parens_kw_expr], matched_expr)
  end

  defr list_args({:kw_data, kw_data}), do: kw_data
  defr list_args({:container_args_base, container_args_base}), do: reverse(container_args_base)

  defr list_args({:container_args_base, container_args_base}, :",") do
    reverse(container_args_base)
  end

  defr list_args({:container_args_base, container_args_base}, :",", {:kw_data, kw_data}) do
    reverse(container_args_base, kw_data)
  end

  defr list({:open_bracket, open_bracket}, {:"]", pn_right_bracket}) do
    build_list(open_bracket, [], pn_right_bracket)
  end

  defr list(
         {:open_bracket, open_bracket},
         {:list_args, list_args},
         {:close_bracket, close_bracket}
       ) do
    build_list(open_bracket, list_args, close_bracket)
  end

  defr tuple({:open_curly, open_curly}, {:"}", pn_right_brace}) do
    build_tuple(open_curly, [], pn_right_brace)
  end

  defr tuple({:open_curly, open_curly}, :kw_data, :"}"), do: bad_keyword(open_curly, tuple)

  defr tuple(
         {:open_curly, open_curly},
         {:container_args, container_args},
         {:close_curly, close_curly}
       ) do
    build_tuple(open_curly, container_args, close_curly)
  end

  defr bitstring({:open_bit, open_bit}, {:">>", pn_right_shift}) do
    build_bit(open_bit, [], pn_right_shift)
  end

  defr bitstring({:open_bit, open_bit}, :kw_data, :">>"), do: bad_keyword(open_bit, bitstring)

  defr bitstring(
         {:open_bit, open_bit},
         {:container_args, container_args},
         {:close_bit, close_bit}
       ) do
    build_bit(open_bit, container_args, close_bit)
  end

  defr assoc_op_eol({:assoc_op, assoc_op}), do: assoc_op
  defr assoc_op_eol({:assoc_op, assoc_op}, :eol), do: assoc_op

  defr assoc_expr({:matched_expr, matched_expr}, :assoc_op_eol, {:matched_expr, matched_expr}) do
    {matched_expr, matched_expr}
  end

  defr assoc_expr(
         {:unmatched_expr, unmatched_expr},
         :assoc_op_eol,
         {:unmatched_expr, unmatched_expr}
       ) do
    {unmatched_expr, unmatched_expr}
  end

  defr assoc_expr({:matched_expr, matched_expr}, :assoc_op_eol, {:unmatched_expr, unmatched_expr}) do
    {matched_expr, unmatched_expr}
  end

  defr assoc_expr({:unmatched_expr, unmatched_expr}, :assoc_op_eol, {:matched_expr, matched_expr}) do
    {unmatched_expr, matched_expr}
  end

  defr assoc_expr({:dot_identifier, dot_identifier}), do: build_identifier(dot_identifier, nil)
  defr assoc_expr({:no_parens_one_expr, no_parens_one_expr}), do: no_parens_one_expr
  defr assoc_expr({:parens_call, parens_call}), do: parens_call

  defr assoc_update(
         {:matched_expr, matched_expr},
         {:pipe_op_eol, pipe_op_eol},
         {:assoc_expr, assoc_expr}
       ) do
    {pipe_op_eol, matched_expr, [assoc_expr]}
  end

  defr assoc_update(
         {:unmatched_expr, unmatched_expr},
         {:pipe_op_eol, pipe_op_eol},
         {:assoc_expr, assoc_expr}
       ) do
    {pipe_op_eol, unmatched_expr, [assoc_expr]}
  end

  defr assoc_update_kw(
         {:matched_expr, matched_expr},
         {:pipe_op_eol, pipe_op_eol},
         {:kw_data, kw_data}
       ) do
    {pipe_op_eol, matched_expr, kw_data}
  end

  defr assoc_update_kw(
         {:unmatched_expr, unmatched_expr},
         {:pipe_op_eol, pipe_op_eol},
         {:kw_data, kw_data}
       ) do
    {pipe_op_eol, unmatched_expr, kw_data}
  end

  defr assoc_base({:assoc_expr, assoc_expr}), do: [assoc_expr]

  defr assoc_base({:assoc_base, assoc_base}, :",", {:assoc_expr, assoc_expr}) do
    [assoc_expr | assoc_base]
  end

  defr assoc({:assoc_base, assoc_base}), do: reverse(assoc_base)
  defr assoc({:assoc_base, assoc_base}, :","), do: reverse(assoc_base)

  defr map_op({:%{}, pn_map}), do: pn_map
  defr map_op({:%{}, pn_map}, :eol), do: pn_map

  defr map_close({:kw_data, kw_data}, {:close_curly, close_curly}), do: {kw_data, close_curly}
  defr map_close({:assoc, assoc}, {:close_curly, close_curly}), do: {assoc, close_curly}

  defr map_close(
         {:assoc_base, assoc_base},
         :",",
         {:kw_data, kw_data},
         {:close_curly, close_curly}
       ) do
    {reverse(assoc_base, kw_data), close_curly}
  end

  defr map_args({:open_curly, open_curly}, {:"}", pn_right_brace}) do
    build_map(open_curly, [], pn_right_brace)
  end

  defr map_args({:open_curly, open_curly}, {:map_close, map_close}) do
    build_map(open_curly, element(1, map_close), element(2, map_close))
  end

  defr map_args(
         {:open_curly, open_curly},
         {:assoc_update, assoc_update},
         {:close_curly, close_curly}
       ) do
    build_map_update(open_curly, assoc_update, close_curly, [])
  end

  defr map_args(
         {:open_curly, open_curly},
         {:assoc_update, assoc_update},
         :",",
         {:close_curly, close_curly}
       ) do
    build_map_update(open_curly, assoc_update, close_curly, [])
  end

  defr map_args(
         {:open_curly, open_curly},
         {:assoc_update, assoc_update},
         :",",
         {:map_close, map_close}
       ) do
    build_map_update(open_curly, assoc_update, element(2, map_close), element(1, map_close))
  end

  defr map_args(
         {:open_curly, open_curly},
         {:assoc_update_kw, assoc_update_kw},
         {:close_curly, close_curly}
       ) do
    build_map_update(open_curly, assoc_update_kw, close_curly, [])
  end

  defr struct_op({:%, pn_struct}), do: pn_struct

  defr struct_expr({:atom, atom}), do: handle_literal(exprs(atom), atom, [])

  defr struct_expr({:atom_quoted, atom_quoted}) do
    handle_literal(exprs(atom_quoted), atom_quoted, delimiter(<<?">>))
  end

  defr struct_expr({:dot_alias, dot_alias}), do: dot_alias
  defr struct_expr({:dot_identifier, dot_identifier}), do: build_identifier(dot_identifier, nil)

  defr struct_expr({:at_op_eol, at_op_eol}, {:struct_expr, struct_expr}) do
    build_unary_op(at_op_eol, struct_expr)
  end

  defr struct_expr({:unary_op_eol, unary_op_eol}, {:struct_expr, struct_expr}) do
    build_unary_op(unary_op_eol, struct_expr)
  end

  defr struct_expr({:parens_call, parens_call}), do: parens_call

  defr map(:map_op, {:map_args, map_args}), do: map_args

  defr map({:struct_op, struct_op}, {:struct_expr, struct_expr}, {:map_args, map_args}) do
    {:%, meta_from_token(struct_op), [struct_expr, map_args]}
  end

  defr map({:struct_op, struct_op}, {:struct_expr, struct_expr}, :eol, {:map_args, map_args}) do
    {:%, meta_from_token(struct_op), [struct_expr, map_args]}
  end

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
      ~c"unexpected expression after keyword list. Keyword lists must always come as the last argument. Therefore, this is not allowed:


        function_call(1, some: :option, 2)


    Instead, wrap the keyword in brackets:


        function_call(1, [some: :option], 2)


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
      ~c"unexpected expression after keyword list. Keyword lists must always come last in lists and maps. Therefore, this is not allowed:


        [some: :value, :another]

        %{some: :value, another => value}


    Instead, reorder it to be the last entry:


        [:another, some: :value]

        %{another => value, some: :value}


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
      ~c"unexpected comma. Parentheses are required to solve ambiguity in nested calls.


  This error happens when you have nested function calls without parentheses.
  For example:


      parent_call a, nested_call b, c, d


  In the example above, we don't know if the parameters \"c\" and \"d\" apply
  to the function \"parent_call\" or \"nested_call\". You can solve this by
  explicitly adding parentheses:


      parent_call a, nested_call(b, c, d)


  Or by adding commas (in case a nested call is not intended):


      parent_call a, nested_call, b, c, d


  Elixir cannot compile otherwise. Syntax error before: ",
      ~c"','"
    )
  end

  defp error_no_parens_container_strict(node) do
    return_error_with_meta(
      meta(node),
      ~c"unexpected comma. Parentheses are required to solve ambiguity inside containers.


  This error may happen when you forget a comma in a list or other container:


      [a, b c, d]


  Or when you have ambiguous calls:


      [function a, b, c]


  In the example above, we don't know if the values \"b\" and \"c\"
  belongs to the list or the function \"function\". You can solve this by explicitly
  adding parentheses:


      [one, function(a, b, c)]


  Elixir cannot compile otherwise. Syntax error before: ",
      ~c"','"
    )
  end

  defp error_too_many_access_syntax(comma) do
    return_error(location(comma), ~c"too many arguments when accessing a value.
  The value[key] notation in Elixir expects either a single argument or a keyword list.
  The following examples are allowed:


      value[one]

      value[one: 1, two: 2]

      value[[one, two, three]]


  These are invalid:


      value[1, 2, 3]

      value[one, two, three]


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
        ~c"parentheses are required when piping into a function call. For example:


          foo 1 ~ts bar 2 ~ts baz 3


      is ambiguous and should be written as


          foo(1) ~ts bar(2) ~ts baz(3)


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
    Parentheses are required to solve ambiguity inside keywords.


    This error happens when you have function calls without parentheses inside keywords.
    For example:


        function(arg, one: nested_call a, b, c)

        function(arg, one: if expr, do: :this, else: :that)


    In the examples above, we don't know if the arguments \"b\" and \"c\" apply
    to the function \"function\" or \"nested_call\". Or if the keywords \"do\" and
    \"else\" apply to the function \"function\" or \"if\". You can solve this by
    explicitly adding parentheses:


        function(arg, one: if(expr, do: :this, else: :that))

        function(arg, one: nested_call(a, b, c))


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
