# un-stream-continuity DIAG

Defect: Loaded.extend (Compiler/DurableReceiverCore.lean) sets headTag := none. After the Host adopts
its own exact append (Session.rememberReadback, opened := readback.after from exactCandidate, which was
old.extend ready), the session image has no headTag until the Store grows from outside, so
withOpenedFreshTip refused "requires an opening read". Routes: Host/Main.lean dispatchRouteAdmissionSession
(op154) -> ApplicationRouteAdmission.Attestation.withFreshTip -> withVerifiedFreshTip -> withOpenedFreshTip.
The participant's signed read goes through sessionWalked and never touches headTag.

Fix (ruled by auditor/coordinator): the append path already computes the tag (publishAfter `tagged`).
- Appended gains headTagExact : next.headTag = some entry.tag (pinned by Fresh.appended_headTag).
- exactCandidate takes the tag (ExactReadback.tag := appended.entry.tag) and sets headTag := some tag, so the
  session's adopted successor carries it. 43 call sites updated mechanically.
- withOpenedFreshTip is defined through ApplicationStreamContinuityFresh.decide; the opening tag (carried, else
  read back) is authenticated by Head.verify at the image's height/chain/frontier (Held.authentic). A tag
  that fails is refused as openingUnverified; no tag at all as noOpeningRead; below birth, tipChanged, ...
  each named distinctly. No new op or Store kind.
