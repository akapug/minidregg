/-
# TokenCensus.SelfTest — the census instrument detects what it claims to

A planted forgery for EVERY private constructor (and a planted call for every
restricted minting function) must be flagged by the census' own checks.  This tests
the instrument, not the tree: the merge gate builds it only when `TokenCensus.Core`,
this module or the plant script change.
-/
import TokenCensus

namespace Minidregg.TokenCensus

-- each plant runs from a fresh heartbeat count (`perConstant`); no unbounded `maxHeartbeats 0`
#assert_token_census_plants Minidregg.TokenCensus.table

end Minidregg.TokenCensus
