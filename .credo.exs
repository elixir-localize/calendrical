# Credo configuration for Calendrical.
#
# Deviations from the defaults are deliberate and documented here
# rather than accumulating as a standing pile of known issues.
%{
  configs: [
    %{
      name: "default",
      strict: true,
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
          # Test support fixtures do not need moduledocs.
          {Credo.Check.Readability.ModuleDoc, files: %{excluded: ["test/"]}},

          # The compiler modules build calendars from large quoted
          # blocks; Credo measures the quoted AST as if it were a
          # single function, producing cyclomatic/arity/nesting/quote
          # figures that reflect the generated surface rather than
          # any real function. The parser modules carry genuinely
          # branchy CLDR-fallback logic that is tracked separately.
          # The additional named files below are acknowledged
          # complexity debt (branchy CLDR-fallback engines and wide
          # internal plumbing), tracked for reduction rather than
          # hidden: interval.ex quarter arithmetic (cc 21),
          # hebrew.ex molad arithmetic, the parser engines,
          # time_zone.ex CLDR scanning, era.ex record building, and
          # two wide internal functions in calendrical.ex and
          # base/week.ex. Remove a file from these lists after
          # refactoring it (date/parser.ex has been decomposed and
          # remains excluded only for depth-3 nesting).
          {Credo.Check.Refactor.CyclomaticComplexity,
           files: %{
             excluded: [
               "lib/calendrical/compiler/",
               "lib/calendrical/behaviour.ex",
               "lib/calendrical/calendars/composite/compiler.ex",
               "lib/calendrical/time/parser.ex",
               "lib/calendrical/interval.ex",
               "lib/calendrical/calendars/hebrew.ex"
             ]
           }},
          {Credo.Check.Refactor.FunctionArity,
           files: %{
             excluded: [
               "lib/calendrical/compiler/",
               "lib/calendrical/calendars/composite/compiler.ex",
               "lib/calendrical.ex",
               "lib/calendrical/base/week.ex"
             ]
           }},
          {Credo.Check.Refactor.Nesting,
           files: %{
             excluded: [
               "lib/calendrical/compiler/",
               "lib/calendrical/calendars/composite/compiler.ex",
               "lib/calendrical/date/parser.ex",
               "lib/calendrical/time/parser.ex",
               "lib/calendrical/datetime/parser.ex",
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
