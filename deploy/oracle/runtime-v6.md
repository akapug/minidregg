# Version 6 packaging

Version 6 packages the U6-v2 Oracle candidate and the session-derived tenant bridge.
The pool keeps at most one resident Engine in the packaged class-L configuration
and up to 128 persistent workspaces. The bridge derives the tenant key from
Mini's source-projected session identity; callers do not select that identity.
The required permission description is `Use a session-isolated workspace on a bounded shared Oracle runtime`.

This package requires a fresh grain/workspace root. The pool refuses a legacy
root-level `requests.sqlite3` rather than guessing which tenant owns its existing
history. The earlier signed v5 artifact and retained worlds remain unchanged.
This packaging run does not migrate their state or deploy a replacement.

The data selection is `data-selection-v6.json`, byte-identical to v5. Its 26-file
public-data inventory remains
`32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`.
The fixed `/opt/oracle-data` mount supplies those files read-only. No database was
copied into the SPK or downloaded for packaging. The qualified v5 Linux rootfs,
including Pillow 11.3.0, is unchanged.

The full input candidate's `APPLIANCE.json` is
`65d0391ee109d7f2873391d7f71cb0991d806b922f73c932764169e3cab90dd8`.
The Linux bridge is
`11cb93bcf78fcb4d984e619c21b5311cea6acb00507f4a5053f33014a9776219`;
its maximum GLIBC requirement is 2.34, within the retained rootfs's 2.39.
Package metadata and launcher are exported from Mini commit
`30268be06e4f758ccee58c54dafcfe042cdd6336`.

`runtime-v6-receipt.json` records the signed artifact identity, exact final-member
verification and pinned tools. The producer uses the retained canonical signer
and the existing application key. A separate pinned SPK inspector checks the
signature and every member against the reviewed stage, including empty files,
executable bits and shared-data links. Standard archive limits remain unchanged.

Signing and matching an inventory do not establish Mini admission, permission,
receiving-path behavior or public availability. The Linux pool measurement and
bridge smoke have separate evidence. No receiving or public deployment was
performed by the packaging lane.


The independently verified artifact is 97,205,848 bytes, SHA-256
`383d6fe7eeaee7b54f1ab00c42dc2c2301a520abfee1a2fa6f4b0a903f12ebd9`.
All 15,372 members matched the stage, with 520,269,200 decoded bytes. Both raw and
decoded sizes fit the unchanged standard limits. The raw artifact is retained at
`o7vn/var/oracle-runtime-v6/oracle-runtime-v6.spk`; the stage and independent
post-pack receipt are beside it. No receiving deployment occurred.
