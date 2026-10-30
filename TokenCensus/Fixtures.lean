/-
# TokenCensus.Fixtures -- the token census over the recorded-run library

`Fixtures` (recorded native runs replayed in Lean) is imported by no umbrella and
no whole-tree census, so that a stale recording cannot hide the census verdict
(`TokenCensus` elaborates without it). Its modules still must not define an
unlisted private constructor or mint, cast into, or call a restricted minter of a
census token from abroad: this module runs checks 1, 2, 5 and 6 over the
`Fixtures` modules only, against the same table (`#assert_token_census_within`).
Its plant is `scripts/kn2/plant-token-census-v2.sh scoped-unlisted`.
-/
import TokenCensus.Core
import TokenCensus.Table
import Fixtures

namespace Minidregg.TokenCensus

#assert_token_census_within Minidregg.TokenCensus.table Fixtures

end Minidregg.TokenCensus
