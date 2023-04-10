# Used by "mix format"
[
  import_deps: [:ecto, :ecto_sql],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    param: :*,
    internal: :*,
    command: :*
  ],
  line_length: 120
]
