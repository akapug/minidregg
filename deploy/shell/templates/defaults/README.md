# Default laws, emitted from `Kernel/DefaultLaw.lean`

Written by `scripts/gen-default-laws.sh`; `--check` refuses a drift. Do not edit by hand.

| template | placeholder | installs on | Lean |
|---|---|---|---|
| `law.account.json` | `@OWNER` = the owner's subject id (decimal) | member accounts (`fleet.rs`, shell provisioning, `genesis.sh` sponsor/clock `accountPredicate`), tills (`credit-permit-all.json`), Hermes budget accounts | `DefaultLaw.accountLaw` |
| `law.room.json` | `@FOUNDER` = the founder's subject id | the private room cell (`roomkey.rs` `ROOM_LAW`) | `DefaultLaw.roomLaw` |

Substitute the placeholder for the decimal subject before parsing, as `roomkey.rs` does for `law.keys.json`'s `@FOUNDER`.
Theorems: `account_step_needs_owner`, `room_governance_needs_founder`; teeth against permit-all:
`permitAll_admits_stranger_transfer` / `accountLaw_refuses_stranger_transfer`.
