# Public-data attachment adversarial checks

This independent test crate calls the same native custody functions as the resident. It is not a substitute for the real signed-SPK admission and Linux sandbox journey: it exercises declaration parsing, publication, and reopening only.

Run on Linux in an independent source snapshot after the custody module is integrated. Set `ATTACHMENT_REVIEW_ROOT` to an existing directory owned by the current operator, mode 0700, with protected ancestry; set `CARGO_TARGET_DIR` to that snapshot's own build directory. For example:

```sh
ATTACHMENT_REVIEW_ROOT=/path/to/private-review-dir \
CARGO_TARGET_DIR=/path/to/independent-cargo-target \
cargo test --manifest-path deploy/oracle/attachment-review/Cargo.toml --test contract
```

Each test creates and removes only its uniquely named child of the supplied directory. The suite changes the permissions and contents of its own published fixtures to model an operator-side mutation. The operator is otherwise trusted to protect published bytes; this suite does not prove protection against that operator. Mounting, fd replacement, signed package identity, lifecycle recovery, and cross-grain isolation need their own receiving-path tests.
