# Credo configuration for Calendrical.
#
# Deviations from the defaults are deliberate and documented here
# rather than accumulating as a standing pile of known issues.
%{
  configs: [
    %{
      name: "default",
      strict: true,
      # The house checks: an error tuple holds an exception
      # (`Calendrical.Credo.ErrorTuple`).
      requires: [".credo/checks/*.ex"],
      files: %{
        included: ["lib/", "test/"],
        excluded: []
      },
      checks: %{
        disabled: [
          # The codebase style uses fully-qualified module names at
          # call sites (Localize.Utils.Math.amod/2 and similar) in
          # preference to aliases; this is a deliberate readability
          # choice for a library that touches many Localize modules.
          {Credo.Check.Design.AliasUsage, []}
        ],
        extra: [
          # An error is `{:error, exception}` in the library. Tests assert
          # the atoms Elixir's own Calendar callbacks return, so only `lib/`
          # is checked.
          {Calendrical.Credo.ErrorTuple, files: %{included: ["lib/"]}},

          # Test support fixtures do not need moduledocs.
          {Credo.Check.Readability.ModuleDoc, files: %{excluded: ["test/"]}},

          # The compiler modules build calendars from large quoted
          # blocks; Credo measures the quoted AST as if it were a
          # single function, producing cyclomatic/arity/nesting/quote
          # figures that reflect the generated surface rather than
          # any real function. The additional named files below are
          # acknowledged complexity debt (branchy CLDR-fallback
          # engines and wide internal plumbing), tracked for
          # reduction rather than hidden: interval.ex quarter
          # arithmetic (cc 21), hebrew.ex molad arithmetic, parse.ex,
          # time_zone.ex CLDR scanning, era.ex record building, and
          # wide internal functions in calendrical.ex. Remove a file
          # from these lists after refactoring it.
          {Credo.Check.Refactor.CyclomaticComplexity,
           files: %{
             excluded: [
               "lib/calendrical/compiler/",
               "lib/calendrical/calendars/composite/compiler.ex",
               "lib/calendrical/interval.ex",
               "lib/calendrical/calendars/hebrew.ex"
             ]
           }},
          {Credo.Check.Refactor.FunctionArity,
           files: %{
             excluded: [
               "lib/calendrical/compiler/",
               "lib/calendrical/calendars/composite/compiler.ex",
               "lib/calendrical.ex"
             ]
           }},
          {Credo.Check.Refactor.Nesting,
           files: %{
             excluded: [
               "lib/calendrical/compiler/",
               "lib/calendrical/calendars/composite/compiler.ex",
               "lib/calendrical/parse.ex",
               "lib/calendrical/time_zone.ex",
               "lib/calendrical/era.ex",
               "lib/calendrical.ex",
               "test/"
             ]
           }},
          {Credo.Check.Refactor.LongQuoteBlocks,
           files: %{
             excluded: [
               "lib/calendrical/compiler/",
               "lib/calendrical/calendars/composite/compiler.ex",
               "lib/calendrical/base/",
               "lib/calendrical/calendars/julian.ex"
             ]
           }}
        ]
      }
    }
  ]
}
