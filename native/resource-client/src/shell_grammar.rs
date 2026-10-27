//! A0: the structured command grammar (docs/WEB-FRONTEND-2026-10-27.md §6; DEMO-EXPERIENCE A0).
//! ONE description of a verb, as data, that the shell's parsing, `help`, Tab completion and the
//! web body's forms all consume: its leaves (`doc append`), each leaf's typed positional
//! arguments, its flags (and which ones are dangerous and need an explicit confirmation), its
//! effect (local, a read, a proposal, a transition) and the words of its operation. The `usage`
//! and `operation` strings the rest of the shell still reads are RENDERED from here, by one
//! printer, so help cannot drift from the parser; the parser arm of a converted verb takes typed
//! values from [`parse`] instead of counting words. Verbs land here one by one (`doc` first);
//! until a verb is here its hand-written `Verb` row and arity checks stand.

use crate::workspace::validate_ref_name;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Kind {
    /// A proposal or attempt id: 1..64 letters, digits or hyphens.
    Id,
    /// A reference name of this workspace (`lab/index` allowed).
    Ref,
    /// A subject number.
    Subject,
    /// A decimal number (a line, a height, a count, a relation).
    Number,
    /// Text given inline or as `@FILE` under `HOME/requests` (1..4096 bytes).
    TextOrFile,
    /// `@FILE` under `HOME/requests`, only.
    File,
    /// `@FILE` or `@-` (standard input).
    FileOrStdin,
    /// A law: a quoted clause list, predicate JSON, `@FILE`, or a stock name.
    Law,
    /// One of these literal words.
    Choice(&'static [&'static str]),
    /// Any single word.
    Word,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Effect {
    /// Decided by the client alone: no Host call.
    Local,
    /// A signed read or view: an answer, never an admission.
    Read,
    /// A proposal, retained under its id; `submit ID` is the transition.
    Propose,
    /// A world transition the client submits itself.
    Transition,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Arg {
    pub name: &'static str,
    pub kind: Kind,
    pub optional: bool,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Flag {
    pub name: &'static str,
    /// A flag with a value names its placeholder and kind; without one it is a switch.
    pub value: Option<(&'static str, Kind)>,
    /// A dangerous switch (`--i-know`, `--freeze-roster`): the form asks for an explicit tick.
    pub dangerous: bool,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Leaf {
    /// The literal words that name the leaf, the verb first.
    pub path: &'static [&'static str],
    pub args: &'static [Arg],
    pub flags: &'static [Flag],
    pub effect: Effect,
    /// The words of the operation (what `help VERB` prints after `=`).
    pub about: &'static str,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Grammar {
    pub verb: &'static str,
    pub leaves: &'static [Leaf],
}

const fn arg(name: &'static str, kind: Kind) -> Arg {
    Arg { name, kind, optional: false }
}
const fn opt(name: &'static str, kind: Kind) -> Arg {
    Arg { name, kind, optional: true }
}
const fn switch(name: &'static str) -> Flag {
    Flag { name, value: None, dangerous: false }
}
const fn valued(name: &'static str, placeholder: &'static str, kind: Kind) -> Flag {
    Flag { name, value: Some((placeholder, kind)), dangerous: false }
}

const JSON_OR_HTML: &[Flag] = &[switch("--json"), switch("--html")];

/// `doc`: the forty leaves of the document verb.
pub static DOC: Grammar = Grammar {
    verb: "doc",
    leaves: &[
        Leaf { path: &["doc", "app-export", "capture"], args: &[arg("ID", Kind::Id), arg("@FILE", Kind::File)], flags: &[], effect: Effect::Transition, about: "mini workspace --action app-document --op capture (the app's export binding from HOME/requests)" },
        Leaf { path: &["doc", "app-export"], args: &[arg("publish|status|recover", Kind::Choice(&["publish", "status", "recover"])), arg("ID", Kind::Id)], flags: &[], effect: Effect::Transition, about: "mini workspace --action app-document --op publish|status|recover" },
        Leaf { path: &["doc", "app-export", "rebase"], args: &[arg("ID", Kind::Id), arg("NEXT", Kind::Id)], flags: &[], effect: Effect::Transition, about: "mini workspace --action app-document --op rebase --next NEXT" },
        Leaf { path: &["doc", "search"], args: &[arg("QUERY", Kind::Word), arg("NAME[,NAME...]|@held", Kind::Word), opt("OFFSET", Kind::Number), opt("CURSOR", Kind::Word)], flags: &[], effect: Effect::Read, about: "mini workspace --action doc-search (OFFSET and CURSOR together continue a page)" },
        Leaf { path: &["doc", "hit"], args: &[arg("NAME", Kind::Ref), arg("DOCUMENT", Kind::Word), arg("ATOM", Kind::Number), arg("REVISION", Kind::Number)], flags: &[], effect: Effect::Read, about: "mini workspace --action doc-search-follow" },
        Leaf { path: &["doc", "device"], args: &[], flags: &[], effect: Effect::Local, about: "mini workspace --action doc-device" },
        Leaf { path: &["doc", "share"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), arg("SUBJECT", Kind::Subject), arg("@DEVICE", Kind::File), arg("@INVITATION", Kind::File)], flags: &[], effect: Effect::Transition, about: "mini workspace --action doc-share (the device record and the invitation under HOME/requests)" },
        Leaf { path: &["doc", "accept"], args: &[arg("NAME", Kind::Ref), arg("CATALOG", Kind::Ref), arg("@INVITATION", Kind::File)], flags: &[], effect: Effect::Transition, about: "mini workspace --action doc-accept" },
        Leaf { path: &["doc", "revoke"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), arg("SUBJECT", Kind::Subject)], flags: &[], effect: Effect::Transition, about: "mini workspace --action doc-revoke" },
        Leaf { path: &["doc", "membership-recover"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), opt("@INVITATION", Kind::File)], flags: &[], effect: Effect::Transition, about: "mini workspace --action doc-membership-recover" },
        Leaf { path: &["doc", "protect"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Transition, about: "mini workspace --action doc-protect" },
        Leaf { path: &["doc", "protect-current"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Transition, about: "mini workspace --action doc-protect-current" },
        Leaf { path: &["doc", "protect-recover"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Transition, about: "mini workspace --action doc-protect-recover" },
        Leaf { path: &["doc", "epoch-export"], args: &[arg("NAME", Kind::Ref), arg("@FILE", Kind::File)], flags: &[], effect: Effect::Local, about: "mini workspace --action doc-epoch-export (the bundle to HOME/requests/FILE)" },
        Leaf { path: &["doc", "epoch-import"], args: &[arg("NAME", Kind::Ref), arg("CATALOG", Kind::Ref), arg("@FILE", Kind::File)], flags: &[], effect: Effect::Transition, about: "mini workspace --action doc-epoch-import" },
        Leaf { path: &["doc", "context"], args: &[arg("NAME", Kind::Ref), opt("MAX-ROWS", Kind::Number), opt("MAX-BYTES", Kind::Number)], flags: &[], effect: Effect::Read, about: "mini workspace --action doc-context (a bounded context of the document for a reviewer)" },
        Leaf { path: &["doc", "review"], args: &[arg("ID", Kind::Id), arg("@CONTEXT", Kind::File), arg("@REQUEST", Kind::File)], flags: &[], effect: Effect::Transition, about: "mini workspace --action context-review" },
        Leaf { path: &["doc", "new"], args: &[arg("NAME", Kind::Ref), opt("draft|note|index|LAW", Kind::Law)], flags: &[valued("--in", "ROOM", Kind::Ref)], effect: Effect::Transition, about: "mini workspace --action doc-new (a content cell and its document; the law stock or your own)" },
        Leaf { path: &["doc", "show"], args: &[arg("NAME", Kind::Ref)], flags: &[valued("--at", "H", Kind::Number), switch("--raw"), switch("--json"), switch("--html")], effect: Effect::Read, about: "doc-show [--at H] [--format raw|json|html]" },
        Leaf { path: &["doc", "outline"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "doc-outline" },
        Leaf { path: &["doc", "history"], args: &[arg("NAME", Kind::Ref)], flags: JSON_OR_HTML, effect: Effect::Read, about: "doc-history" },
        Leaf { path: &["doc", "diff"], args: &[arg("NAME", Kind::Ref), arg("H1", Kind::Number), arg("H2", Kind::Number)], flags: JSON_OR_HTML, effect: Effect::Read, about: "doc-diff" },
        Leaf { path: &["doc", "pull"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "doc-pull (the document to HOME, line by line, for a later push)" },
        Leaf { path: &["doc", "push"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), arg("@FILE|@-", Kind::FileOrStdin)], flags: &[], effect: Effect::Transition, about: "doc-push (propose payload document: push, then submit)" },
        Leaf { path: &["doc", "append"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), arg("TEXT|@FILE", Kind::TextOrFile)], flags: &[], effect: Effect::Propose, about: "propose (payload document: append)" },
        Leaf { path: &["doc", "edit"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), arg("LINE", Kind::Number), arg("TEXT|@FILE", Kind::TextOrFile)], flags: &[], effect: Effect::Propose, about: "propose (payload document: edit)" },
        Leaf { path: &["doc", "insert"], args: &[arg("NAME", Kind::Ref), arg("N", Kind::Number), arg("TEXT|@FILE", Kind::TextOrFile)], flags: &[], effect: Effect::Transition, about: "doc-insert" },
        Leaf { path: &["doc", "move"], args: &[arg("NAME", Kind::Ref), arg("FROM", Kind::Number), arg("TO", Kind::Number)], flags: &[], effect: Effect::Transition, about: "doc-move" },
        Leaf { path: &["doc", "remove"], args: &[arg("NAME", Kind::Ref), arg("N", Kind::Number)], flags: &[], effect: Effect::Transition, about: "doc-remove" },
        Leaf { path: &["doc", "mark"], args: &[arg("NAME", Kind::Ref), arg("LINE", Kind::Number), arg("bold|italic|code|heading|link", Kind::Choice(&["bold", "italic", "code", "heading", "link"])), opt("TARGET", Kind::Word)], flags: &[], effect: Effect::Transition, about: "mark" },
        Leaf { path: &["doc", "unmark"], args: &[arg("NAME", Kind::Ref), arg("MARK", Kind::Word), opt("KIND", Kind::Word)], flags: &[], effect: Effect::Transition, about: "unmark (MARK, or LINE KIND)" },
        Leaf { path: &["doc", "annotate"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), arg("LINE", Kind::Number), arg("TEXT|@FILE", Kind::TextOrFile)], flags: &[], effect: Effect::Propose, about: "propose (payload document: annotate)" },
        Leaf { path: &["doc", "link"], args: &[arg("ID", Kind::Id), arg("FROM", Kind::Ref), arg("TO", Kind::Ref), opt("RELATION", Kind::Number)], flags: &[], effect: Effect::Propose, about: "propose (payload document: link)" },
        Leaf { path: &["doc", "links"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "doc-links (the Host's link index)" },
        Leaf { path: &["doc", "backlinks"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "doc-backlinks (the Host's link index)" },
        Leaf { path: &["doc", "range"], args: &[arg("NAME", Kind::Ref), arg("FROM", Kind::Number), arg("TO", Kind::Number)], flags: &[], effect: Effect::Transition, about: "doc-range (createRun)" },
        Leaf { path: &["doc", "transclude"], args: &[arg("NAME", Kind::Ref), arg("SOURCE", Kind::Ref), arg("FROM", Kind::Number), arg("TO", Kind::Number), opt("snapshot|live", Kind::Choice(&["snapshot", "live"])), opt("at", Kind::Choice(&["at"])), opt("N", Kind::Number)], flags: &[], effect: Effect::Transition, about: "transclude (--from-line --to-line)" },
        Leaf { path: &["doc", "transclusions"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "transclusions" },
        Leaf { path: &["doc", "follow"], args: &[arg("NAME", Kind::Ref), arg("T", Kind::Word)], flags: &[], effect: Effect::Read, about: "follow" },
    ],
};

const fn dangerous(name: &'static str) -> Flag {
    Flag { name, value: None, dangerous: true }
}

/// `room`: a room's names, its birth, its roster, its keys (private rooms), its economy.
pub static ROOM: Grammar = Grammar {
    verb: "room",
    leaves: &[
        Leaf { path: &["room", "index"], args: &[arg("ID", Kind::Id), arg("ROOM", Kind::Ref), arg("INDEX-DOC", Kind::Ref)], flags: &[], effect: Effect::Transition, about: "mini workspace --action shared-name --op attach (the room's index document)" },
        Leaf { path: &["room", "bind"], args: &[arg("ID", Kind::Id), arg("ROOM", Kind::Ref), arg("NAME", Kind::Id), arg("TARGET", Kind::Word)], flags: &[], effect: Effect::Transition, about: "shared-name --op bind" },
        Leaf { path: &["room", "rename"], args: &[arg("ID", Kind::Id), arg("ROOM", Kind::Ref), arg("NAME", Kind::Id), arg("NEW-NAME", Kind::Word)], flags: &[], effect: Effect::Transition, about: "shared-name --op rename" },
        Leaf { path: &["room", "unbind"], args: &[arg("ID", Kind::Id), arg("ROOM", Kind::Ref), arg("NAME", Kind::Id)], flags: &[], effect: Effect::Transition, about: "shared-name --op unbind" },
        Leaf { path: &["room", "resolve"], args: &[arg("ROOM/NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "shared-name --op resolve" },
        Leaf { path: &["room", "new"], args: &[arg("NAME", Kind::Ref)], flags: &[valued("--law", "open|realm", Kind::Choice(&["open", "realm"])), valued("--referee", "SUBJECT", Kind::Subject), valued("--in", "PARENT", Kind::Ref), switch("--private"), valued("--template", "T|@FILE", Kind::Word), valued("--concierge", "SUBJECT", Kind::Subject), valued("--period", "N", Kind::Number)], effect: Effect::Transition, about: "mini workspace --action create (storage declared, the room's law, --room-template LAW); --private: the private room's law, its keys cell and your own wrap [DEVNET QUALITY; PRIVACY NOT AUDITED]; --template: the template's lines, each one typed line, in order; --concierge: the room's lines, then `room concierge`" },
        Leaf { path: &["room", "welcome"], args: &[arg("NAME", Kind::Id), arg("SUBJECT", Kind::Subject)], flags: &[valued("--template", "T|@FILE", Kind::Word)], effect: Effect::Transition, about: "the template's member lines" },
        Leaf { path: &["room", "template", "list"], args: &[], flags: &[], effect: Effect::Local, about: "local: the room templates" },
        Leaf { path: &["room", "template", "show"], args: &[arg("T|@FILE", Kind::Word), opt("member", Kind::Choice(&["member"]))], flags: &[], effect: Effect::Local, about: "local: print the template file (its room lines, or its member lines)" },
        Leaf { path: &["room", "invite"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), arg("SUBJECT", Kind::Subject), opt("DECLARATION|KEY-ID|@FILE", Kind::Word)], flags: &[switch("--past"), dangerous("--i-know"), valued("--verbs", "V,...", Kind::Word), valued("--fields", "F,...", Kind::Word), valued("--max-delta", "F=N,...", Kind::Word), valued("--max-cost", "N", Kind::Number)], effect: Effect::Propose, about: "propose (action delegate, room: true; private: room-key --op invite, which also releases the room key to the invitee's hybrid X25519 + ML-KEM-768 key in one keys write)" },
        Leaf { path: &["room", "kick"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref), arg("SUBJECT", Kind::Subject)], flags: &[], effect: Effect::Propose, about: "room-kick: one revoke per standing grant SUBJECT holds under NAME (the Host's signed who view), proposed; `submit ID` submits them all (private: room-key --op kick = every revoke + rotate + rewrap, submitted)" },
        Leaf { path: &["room", "seal"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Ref)], flags: &[dangerous("--freeze-roster")], effect: Effect::Propose, about: "propose (action install-policy, `sealed`): sealing a room freezes its membership forever, so it needs --freeze-roster" },
        Leaf { path: &["room", "rotate"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Id)], flags: &[], effect: Effect::Transition, about: "room-key --op rotate" },
        Leaf { path: &["room", "transition"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Id), arg("NEXTFILE", Kind::Word)], flags: &[], effect: Effect::Transition, about: "room-key --op transition (founder: hand the room to your next signing key before rotate-key)" },
        Leaf { path: &["room", "register"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Id)], flags: &[], effect: Effect::Transition, about: "room-key --op register (publish my current encryption key as my record)" },
        Leaf { path: &["room", "rewrap"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Id), arg("SUBJECT", Kind::Subject)], flags: &[], effect: Effect::Transition, about: "room-key --op rewrap" },
        Leaf { path: &["room", "keys"], args: &[arg("NAME", Kind::Id)], flags: &[], effect: Effect::Local, about: "room-key --op list (local)" },
        Leaf { path: &["room", "leave"], args: &[arg("ID", Kind::Id), arg("NAME", Kind::Id)], flags: &[], effect: Effect::Propose, about: "propose (action renounce, leave: your room grant)" },
        Leaf { path: &["room", "members"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "who" },
        Leaf { path: &["room", "list"], args: &[], flags: &[], effect: Effect::Local, about: "local: references that are rooms" },
        Leaf { path: &["room", "ls"], args: &[opt("ROOM", Kind::Ref)], flags: &[valued("--since", "H", Kind::Number), switch("--import"), switch("--json")], effect: Effect::Read, about: "chat: the Host's signed since view under the room grant, with the roster's streams and my names (--import names the rest ROOM-cell-ID)" },
        Leaf { path: &["room", "law"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "describe" },
        Leaf { path: &["room", "status"], args: &[arg("NAME", Kind::Ref)], flags: &[], effect: Effect::Read, about: "mini credit --action status (my window, the tariff, the till; adopts a newer window from HOME/inbox)" },
        Leaf { path: &["room", "renew"], args: &[arg("NAME", Kind::Ref), arg("SUBJECT", Kind::Subject)], flags: &[valued("--for", "N", Kind::Number), valued("--until", "H", Kind::Number)], effect: Effect::Transition, about: "mini credit --action renew (one delegation under the room with notAfter; copy in HOME/outbox/SUBJECT)" },
        Leaf { path: &["room", "concierge"], args: &[arg("NAME", Kind::Id), arg("SUBJECT", Kind::Subject)], flags: &[valued("--period", "N", Kind::Number), valued("--fund", "N", Kind::Number)], effect: Effect::Transition, about: "mini credit --action install (the till, the runner account, the tariff's account fields, the concierge's grants; program in HOME/concierge/NAME.json)" },
    ],
};

pub static GRAMMARS: &[&Grammar] = &[&DOC, &ROOM];

pub fn grammar(verb: &str) -> Option<&'static Grammar> {
    GRAMMARS.iter().copied().find(|g| g.verb == verb)
}

/// The usage line, rendered: one alternative per leaf, in the table's own notation.
pub fn usage(g: &Grammar) -> String {
    g.leaves.iter().map(leaf_usage).collect::<Vec<_>>().join(" | ")
}

pub fn leaf_usage(leaf: &Leaf) -> String {
    let mut words: Vec<String> = leaf.path.iter().map(|w| w.to_string()).collect();
    for a in leaf.args {
        words.push(if a.optional { format!("[{}]", a.name) } else { a.name.to_owned() });
    }
    for f in leaf.flags {
        words.push(match f.value {
            Some((placeholder, _)) => format!("[{} {placeholder}]", f.name),
            None => format!("[{}]", f.name),
        });
    }
    words.join(" ")
}

/// The operation words, rendered: one segment per leaf, aligned with the usage.
pub fn operation(g: &Grammar) -> String {
    g.leaves.iter().map(|l| l.about).collect::<Vec<_>>().join(" | ")
}

/// A leaf's words, typed: positional values by argument index (None when an optional one was
/// not given), and the flags that were present with their values.
#[derive(Debug)]
pub struct Parsed<'a> {
    pub leaf: &'static Leaf,
    pub args: Vec<Option<&'a str>>,
    pub flags: Vec<(&'static str, Option<&'a str>)>,
}

impl<'a> Parsed<'a> {
    pub fn arg(&self, i: usize) -> &'a str {
        self.args.get(i).copied().flatten().unwrap_or("")
    }
    pub fn flag(&self, name: &str) -> Option<Option<&'a str>> {
        self.flags.iter().find(|(n, _)| *n == name).map(|(_, v)| *v)
    }
    pub fn has(&self, name: &str) -> bool {
        self.flag(name).is_some()
    }
    /// Every value a repeatable valued flag was given (`--referee 9 --referee 12`).
    pub fn values(&self, name: &str) -> Vec<&'a str> {
        self.flags.iter().filter(|(n, _)| *n == name).filter_map(|(_, v)| *v).collect()
    }
}

/// The leaf the words name (the longest literal path that matches), its arguments checked by
/// kind and count, its flags recognized. A wrong shape (no leaf, a missing or extra word, an
/// unknown flag) answers the verb's whole usage, as the shell's `usage:` ending has always
/// done; a word of the wrong kind answers the typed message that names the argument.
pub fn parse<'a>(g: &'static Grammar, words: &'a [String]) -> Result<Parsed<'a>, String> {
    let leaf = g
        .leaves
        .iter()
        .filter(|l| l.path.len() <= words.len() && l.path.iter().zip(words).all(|(p, w)| p == w))
        .max_by_key(|l| l.path.len())
        .ok_or_else(|| usage(g))?;
    let rest = &words[leaf.path.len()..];
    let mut args: Vec<Option<&'a str>> = Vec::new();
    let mut flags: Vec<(&'static str, Option<&'a str>)> = Vec::new();
    let mut i = 0;
    while i < rest.len() {
        let w = rest[i].as_str();
        if let Some(f) = leaf.flags.iter().find(|f| f.name == w) {
            match f.value {
                Some((placeholder, kind)) => {
                    let v = rest.get(i + 1).map(String::as_str).ok_or_else(|| usage(g))?;
                    check(kind, v, placeholder)?;
                    flags.push((f.name, Some(v)));
                    i += 2;
                }
                None => {
                    flags.push((f.name, None));
                    i += 1;
                }
            }
            continue;
        }
        if w.starts_with("--") && w.len() > 2 {
            return Err(usage(g));
        }
        let position = args.len();
        let Some(a) = leaf.args.get(position) else {
            return Err(usage(g));
        };
        // An optional literal choice (`at`) that does not match lets the next argument take the word.
        if a.optional && matches!(a.kind, Kind::Choice(_)) && check(a.kind, w, a.name).is_err() {
            args.push(None);
            continue;
        }
        check(a.kind, w, a.name)?;
        args.push(Some(w));
        i += 1;
    }
    for a in &leaf.args[args.len()..] {
        if !a.optional {
            return Err(usage(g));
        }
        args.push(None);
    }
    Ok(Parsed { leaf, args, flags })
}

/// One value against its kind; the message names the argument.
pub fn check(kind: Kind, value: &str, name: &str) -> Result<(), String> {
    let ok = match kind {
        Kind::Id => !value.is_empty() && value.len() <= 64 && value.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-'),
        Kind::Ref => validate_ref_name(value).is_ok(),
        Kind::Subject | Kind::Number => !value.is_empty() && value.len() <= 40 && value.bytes().all(|b| b.is_ascii_digit()),
        Kind::TextOrFile => !value.is_empty() && (!value.starts_with('@') || is_session_file(&value[1..])),
        Kind::File => value.strip_prefix('@').is_some_and(is_session_file),
        Kind::FileOrStdin => value == "@-" || value.strip_prefix('@').is_some_and(is_session_file),
        Kind::Law => !value.is_empty(),
        Kind::Choice(options) => options.contains(&value),
        Kind::Word => !value.is_empty(),
    };
    if ok {
        Ok(())
    } else {
        Err(match kind {
            Kind::Id => format!("{name} must be 1..64 ASCII letters, digits or hyphens"),
            Kind::Ref => format!("{name} must be 1..64 ASCII letters, digits or hyphens, or such segments joined by '/' (lab/index)"),
            Kind::Subject | Kind::Number => format!("{name} must be a decimal number"),
            Kind::TextOrFile => format!("{name}: text, or @FILE naming a file in HOME/requests"),
            Kind::File => format!("{name} must be @FILE, a file in HOME/requests"),
            Kind::FileOrStdin => format!("{name} must be @FILE (HOME/requests) or @- (standard input)"),
            Kind::Choice(options) => format!("{name} must be one of {}, not {value:?}", options.join("|")),
            Kind::Law | Kind::Word => format!("{name} is required"),
        })
    }
}

/// `session_file`'s rule: a bare file name under HOME/requests.
pub fn is_session_file(value: &str) -> bool {
    !value.is_empty() && value.len() <= 64 && !value.starts_with('.') && value.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.'))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn words(line: &str) -> Vec<String> {
        line.split(' ').map(str::to_owned).collect()
    }

    #[test]
    fn the_doc_usage_renders_every_leaf_once_and_parses_its_own_examples() {
        let u = usage(&DOC);
        assert_eq!(u.split(" | ").count(), DOC.leaves.len());
        assert!(u.starts_with("doc app-export capture ID @FILE | doc app-export publish|status|recover ID | doc app-export rebase ID NEXT"));
        assert!(u.contains("doc append ID NAME TEXT|@FILE") && u.contains("doc show NAME [--at H] [--raw] [--json] [--html]"));
        assert_eq!(operation(&DOC).split(" | ").count(), DOC.leaves.len());
        let w = words("doc append w-1 paper hello");
        let p = parse(&DOC, &w).unwrap();
        assert_eq!(p.leaf.path, ["doc", "append"]);
        assert_eq!((p.arg(0), p.arg(1), p.arg(2)), ("w-1", "paper", "hello"));
        assert_eq!(p.leaf.effect, Effect::Propose);
        let w = words("doc show paper --at 7 --json");
        let p = parse(&DOC, &w).unwrap();
        assert_eq!(p.flag("--at"), Some(Some("7")));
        assert!(p.has("--json") && !p.has("--html"));
        let w = words("doc transclude page wall 1 3 live at 9");
        let p = parse(&DOC, &w).unwrap();
        assert_eq!((p.arg(4), p.arg(5), p.arg(6)), ("live", "at", "9"));
        let w = words("doc transclude page wall 1 3");
        let p = parse(&DOC, &w).unwrap();
        assert_eq!(p.args[4], None);
        let w = words("doc app-export capture op-1 @binding.json");
        let p = parse(&DOC, &w).unwrap();
        assert_eq!(p.leaf.path, ["doc", "app-export", "capture"]);
        let w = words("doc app-export status op-1");
        let p = parse(&DOC, &w).unwrap();
        assert_eq!(p.leaf.path, ["doc", "app-export"]);
        assert_eq!(p.arg(0), "status");
        // A wrong shape answers the whole usage; a wrong kind names the argument.
        assert_eq!(parse(&DOC, &words("doc append w-1")).unwrap_err(), usage(&DOC));
        assert_eq!(parse(&DOC, &words("doc append w-1 paper a b")).unwrap_err(), usage(&DOC));
        assert_eq!(parse(&DOC, &words("doc nothing")).unwrap_err(), usage(&DOC));
        assert_eq!(parse(&DOC, &words("doc show paper --bogus")).unwrap_err(), usage(&DOC));
        assert!(parse(&DOC, &words("doc mark paper 2 underline")).unwrap_err().contains("not \"underline\""));
        assert!(parse(&DOC, &words("doc edit w-1 paper x text")).unwrap_err().contains("LINE must be a decimal"));
        assert!(parse(&DOC, &words("doc push w-1 paper plain")).unwrap_err().contains("@FILE"));
        // room: one leaf for `room new` with its switches and repeatable flags; dangerous switches.
        let w = words("room new tide --law realm --referee 9 --referee 12 --in lab");
        let p = parse(&ROOM, &w).unwrap();
        assert_eq!(p.values("--referee"), ["9", "12"]);
        assert_eq!(p.flag("--law"), Some(Some("realm")));
        let w = words("room seal s1 lab --freeze-roster");
        assert!(parse(&ROOM, &w).unwrap().has("--freeze-roster"));
        assert!(ROOM.leaves.iter().any(|l| l.flags.iter().any(|f| f.dangerous && f.name == "--i-know")));
        let w = words("room template show workroom member");
        let p = parse(&ROOM, &w).unwrap();
        assert_eq!((p.leaf.path, p.arg(0), p.arg(1)), (&["room", "template", "show"][..], "workroom", "member"));
        assert_eq!(parse(&ROOM, &words("room leave lab")).unwrap_err(), usage(&ROOM));
    }
}
