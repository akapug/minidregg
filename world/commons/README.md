# world/commons: the resident service commons

`ResidentServiceCommons.obend` is the lifecycle (quote, reserve, start, uncertain, deliver, accept, cancel) as
pure transitions and as an Activity; `CommonsScenarios.obend` holds the named scenario, the Gen-1 laws and the
negative controls over it, imported qualified (`preview-cohort.json`, 64 rows). Only the lifecycle module is
published natively. Design: `docs/BEND-RESIDENT-SERVICE-COMMONS.md`.
Native: admitted on the activity route on candidate 0ce31391, scenario `commons` of `native/resource-client/world-activity-admit.py`, 20/20 rows (every refusal row confirms its refusal); run `scripts/world-native-admit.sh commons --route activity --scenario commons --method world/commons/ResidentServiceCommons.obend --entry lifecycle`. Evidence: `docs/evidence/2026-10-27-world-native/commons/` (`verdicts.txt`, `results.json`).
