# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    right: 2,
    left: 2,
    nonassoc: 2,
    unary: 2,
    nonterminals: 1,
    terminals: 1,
    root: 1,
    expect: 1,
    defr: 2
  ]
]
