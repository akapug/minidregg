//! Every shell verb as a form, DERIVED from the shell's own verb table (`shell::command_catalog`:
//! `shell.rs`, `chat.rs`, `hermes.rs`, `story.rs`), never written per verb (ember 2026-10-27:
//! "everything that can be done over ssh and commands can also be done visually & via the web
//! interface"; docs/DEMO-EXPERIENCE-2026-10-27.md §1a). A verb's `usage` is its grammar: one
//! alternative per ` | `, literal words, UPPERCASE placeholders (optional in `[…]`), `--flags`
//! with or without a value. Each alternative renders as one form; its fields become the words of
//! one shell line, run as the member (`body::verb`), and the ending is the one outcome partial.
//! A new verb is visual the day its row enters the table. Bespoke pages (document, board, room,
//! receipt, grants, keys) sit beside this; they do not replace it.

use super::*;

#[derive(Debug, Clone, PartialEq)]
pub(super) enum Kind {
    /// A proposal id (`ID`): a fresh one is offered.
    Id,
    /// A reference name: a picker over this workspace's references (free text allowed).
    Ref,
    /// Free text, JSON or `@FILE`: a textarea, delivered through `HOME/requests` as `@FILE`.
    Text,
    Number,
    /// `a|b|c` of literals: a select.
    Choice(Vec<String>),
    Word,
}

#[derive(Debug, Clone, PartialEq)]
pub(super) enum Tok {
    Lit(String),
    Arg { name: String, optional: bool, kind: Kind },
    /// `--flag` (bare: a checkbox) or `--flag VALUE` (a field; the flag is sent when filled).
    Flag { name: String, value: Option<(String, Kind)>, optional: bool },
}

#[derive(Debug, Clone, PartialEq)]
pub(super) struct Alt {
    pub tokens: Vec<Tok>,
}

impl Alt {
    pub fn literals(&self) -> String {
        self.tokens.iter().filter_map(|t| if let Tok::Lit(l) = t { Some(l.as_str()) } else { None }).collect::<Vec<_>>().join(" ")
    }

    /// A proposal: its first placeholder is the proposal `ID`; `submit ID` is offered after it.
    pub fn proposes(&self, operation: &str) -> bool {
        operation.contains("propose") && self.tokens.iter().any(|t| matches!(t, Tok::Arg { kind: Kind::Id, .. }))
    }
}

/// Whether the alternative at `index` of `usage` is a WORLD TRANSITION (a proposal, a submit, a
/// birth, a payment) rather than a read or a local verb, read from the `operation` segment that
/// names it (the segments align with the usage alternatives; a verb with one segment applies it
/// to every alternative). Interim: the structured command grammar (A0) carries this as data.
pub(super) fn transition(usage: &str, operation: &str, index: usize, literals: &str) -> bool {
    let segments: Vec<&str> = operation.split(" | ").collect();
    let alternatives_count = usage.split(" | ").count();
    let segment = if segments.len() == alternatives_count {
        segments.get(index).copied().unwrap_or(operation)
    } else {
        // Fewer segments than alternatives (`doc`): the segment that names this subcommand
        // (`doc-show`, or the word inside `propose (payload document: append, edit, …)`).
        let mut words = literals.split(' ');
        let verb = words.next().unwrap_or("");
        match words.next() {
            Some(sub) => segments
                .iter()
                .find(|seg| seg.contains(&format!("{verb}-{sub}")) || seg.starts_with(sub) || seg.contains(&format!(" {sub},")) || seg.contains(&format!(" {sub})")) || seg.contains(&format!(": {sub}")))
                .copied()
                .unwrap_or(operation),
            None => operation,
        }
    };
    let lower = segment.to_ascii_lowercase();
    let read = lower.starts_with("local") || lower.contains("signed read") || lower.contains("signed view") || lower.contains("signed tail") || lower.contains("--action list") || lower.contains("--action read") || lower.contains("--action describe") || lower.contains("--action inspect") || lower.contains("--action can") || lower.contains("--action recover") || lower.contains("dry-run") || lower.contains("--format") || lower.contains("doc-show") || lower.contains("doc-history") || lower.contains("doc-diff") || lower.contains("--action status") || lower.contains("--action balance") || lower.contains("--action tariff") && !lower.contains("--set") || lower.starts_with("who") || lower.starts_with("describe") || lower.starts_with("chat:") || lower.starts_with("current app admission") || lower.contains("--action search") || lower.contains("--action key-status");
    // Anything the segment does not name as a read or a local verb is a world transition: the
    // safe default for a verb that may write (its exit 0 is then "admitted" only when it is).
    !read
}

/// Split a usage into alternatives (` | ` between them; a `|` inside a word is a choice).
pub(super) fn alternatives(usage: &str) -> Vec<Alt> {
    usage.split(" | ").map(|alt| Alt { tokens: tokens(alt) }).filter(|a| !a.tokens.is_empty()).collect()
}

/// Group a usage alternative into raw words: bracket groups and quoted spans stay whole.
fn raw_words(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut word = String::new();
    let mut depth = 0usize;
    let mut quoted = false;
    for c in text.chars() {
        match c {
            '"' => {
                quoted = !quoted;
                word.push(c);
            }
            '[' if !quoted => {
                depth += 1;
                word.push(c);
            }
            ']' if !quoted && depth > 0 => {
                depth -= 1;
                word.push(c);
            }
            c if c.is_whitespace() && depth == 0 && !quoted => {
                if !word.is_empty() {
                    out.push(std::mem::take(&mut word));
                }
            }
            c => word.push(c),
        }
    }
    if !word.is_empty() {
        out.push(word);
    }
    out
}

fn is_literal(word: &str) -> bool {
    !word.is_empty() && word.bytes().all(|b| b.is_ascii_lowercase() || b == b'-' || b == b'/') && !word.starts_with('-')
}

fn kind_of(name: &str) -> Kind {
    let base = name.split(['|', '[']).next().unwrap_or(name).trim_end_matches("...");
    if name.contains("JSON") || name.contains("@FILE") || name.contains("@-") || name.starts_with('"') || base == "TEXT" || base == "INDEX-DOC" {
        return Kind::Text;
    }
    if base == "ID" {
        return Kind::Id;
    }
    if matches!(
        base,
        "REF" | "ROOM" | "BOARD" | "DOCUMENT" | "MARKET" | "JOB" | "PARENT" | "SOURCE" | "KIND" | "NAME" | "NEXT" | "TARGET" | "ACCOUNT-REF" | "FACTORY-REF" | "CATALOG" | "ROOM/NAME" | "ATTEMPT" | "PROGRAM" | "PROGRAM-ID" | "SCENE" | "TASK" | "SHARED" | "INDEX"
    ) {
        return Kind::Ref;
    }
    if matches!(base, "N" | "AMOUNT" | "COST" | "MAX-COST" | "PRICE" | "QTY" | "LINE" | "SECONDS" | "HEIGHT" | "H" | "H1" | "H2" | "FUNDING" | "OFFSET" | "SUPPLY" | "B" | "P" | "A" | "EPOCH" | "REVISION" | "ATOM") {
        return Kind::Number;
    }
    if name.contains('|') && name.split('|').all(|w| !w.is_empty() && w.bytes().all(|b| b.is_ascii_lowercase() || b == b'-')) {
        return Kind::Choice(name.split('|').map(str::to_owned).collect());
    }
    Kind::Word
}

fn tokens(alt: &str) -> Vec<Tok> {
    let mut out = Vec::new();
    for raw in raw_words(alt) {
        let (inner, optional) = match raw.strip_prefix('[').and_then(|r| r.strip_suffix(']')) {
            Some(inner) => (inner.to_owned(), true),
            None => (raw.clone(), false),
        };
        // A bracket may hold `--flag VALUE`, `--flag: a note`, or `a|b`; outside brackets a raw
        // word is one token (a quoted span stays whole).
        let pieces: Vec<&str> = if optional { inner.split_whitespace().collect() } else { vec![inner.as_str()] };
        let mut parts = pieces.into_iter();
        let Some(first) = parts.next() else { continue };
        if first.starts_with('-') {
            let name = first.trim_end_matches(':').to_owned();
            let rest: Vec<&str> = parts.collect();
            let value = match rest.first() {
                Some(v) if !first.ends_with(':') && (v.chars().any(|c| c.is_ascii_uppercase()) || v.contains('|') || v.starts_with('@')) => Some(((*v).to_owned(), kind_of(v))),
                _ => None,
            };
            out.push(Tok::Flag { name, value, optional });
            continue;
        }
        if is_literal(first) {
            out.push(Tok::Lit(first.to_owned()));
            // `[FIELDS|open]`: a literal choice inside brackets is still one optional field.
            continue;
        }
        if first.contains('|') && first.split('|').all(is_literal) {
            out.push(Tok::Arg { name: first.to_owned(), optional, kind: Kind::Choice(first.split('|').map(str::to_owned).collect()) });
            continue;
        }
        out.push(Tok::Arg { name: first.to_owned(), optional, kind: kind_of(first) });
        // `[A B]`: further placeholders in one optional group are each optional.
        for more in parts {
            if more.starts_with('-') {
                out.push(Tok::Flag { name: more.to_owned(), value: None, optional: true });
            } else if is_literal(more) {
                out.push(Tok::Lit(more.to_owned()));
            } else {
                out.push(Tok::Arg { name: more.to_owned(), optional: true, kind: kind_of(more) });
            }
        }
    }
    out
}

// ---------------------------------------------------------------- rendering

/// `/verb`: every verb of the shell, as the shell lists it.
pub(super) fn index(site: &Site) -> Page {
    let mut rows = String::new();
    for v in crate::shell::command_catalog() {
        rows.push_str(&format!(
            "<tr><td><a href=\"/verb/{n}\">{n}</a></td><td><code>{}</code></td><td class=\"note\">{}</td></tr>\n",
            escape(v.usage),
            escape(&clip(v.operation, 160)),
            n = escape(v.name)
        ));
    }
    let note = if site.front.read_only {
        "<p class=note>The public reader runs no verb; with a session every one of these is a form.</p>"
    } else {
        "<p>Every verb of <code>mini shell</code>, as a form: the same words, the same Host, the same decoded outcome. Derived from the shell's verb table, so a verb is here the day it exists.</p>\
         <p class=note>Interim: these forms are read from each verb's usage string. The structured command grammar (one data structure per verb: subcommands, typed arguments, reference kinds, uploads, confirmations, outcome schema) that the shell's parsing, help, completion and this page will all consume replaces them verb by verb (docs/DEMO-EXPERIENCE-2026-10-27.md A0).</p>"
    };
    Page { status: 200, title: "Commands".into(), stamp: Stamp::None, body: format!("{note}\n<table><thead><tr><th>verb</th><th>usage</th><th>operation</th></tr></thead><tbody>{rows}</tbody></table>") }
}

fn clip(text: &str, n: usize) -> String {
    if text.chars().count() <= n { text.to_owned() } else { format!("{}…", text.chars().take(n).collect::<String>()) }
}

/// `/verb/NAME`: one form per alternative of the verb's usage.
pub(super) fn page(site: &Site, name: &str) -> Page {
    let Some(verb) = crate::shell::command_catalog().find(|v| v.name == name) else {
        return simple(404, "No such verb", &format!("the shell has no verb {name}"));
    };
    let alts = alternatives(verb.usage);
    let refs = site.names();
    let mut body = format!(
        "<p><code>{}</code></p><p class=note>{}</p>\n<datalist id=\"refs\">{}</datalist>\n",
        escape(verb.usage),
        escape(verb.operation),
        refs.iter().map(|r| format!("<option value=\"{}\">", escape(r))).collect::<String>()
    );
    if site.front.read_only {
        body.push_str("<p class=note>The public reader runs no verb.</p>");
        return Page { status: 200, title: name.to_owned(), stamp: Stamp::None, body };
    }
    for (i, alt) in alts.iter().enumerate() {
        body.push_str(&form(name, i, alt, verb.operation, &format!("/verb/{}", escape(name)), ""));
    }
    Page { status: 200, title: name.to_owned(), stamp: Stamp::None, body }
}

/// The form of one verb alternative, by the literal words that name it (`"doc append"`), posted
/// to `action` with `hidden` fields before its own: the tour embeds the real forms this way.
pub(super) fn form_for(name: &str, literals: &str, action: &str, hidden: &str) -> Option<String> {
    let verb = crate::shell::command_catalog().find(|v| v.name == name)?;
    let alts = alternatives(verb.usage);
    let (index, alt) = alts.iter().enumerate().find(|(_, a)| a.literals() == literals)?;
    Some(form(name, index, alt, verb.operation, action, hidden))
}

fn form(name: &str, index: usize, alt: &Alt, operation: &str, action: &str, hidden: &str) -> String {
    let mut out = format!(
        "<section class=\"verb-form\"><h2><code>{}</code></h2><form method=\"post\" action=\"{action}\">{hidden}<input type=\"hidden\" name=\"alt\" value=\"{index}\"><div class=\"fields\">",
        escape(&alt.literals()),
    );
    let _ = name;
    for (i, tok) in alt.tokens.iter().enumerate() {
        let field = format!("a{i}");
        match tok {
            Tok::Lit(_) => {}
            Tok::Arg { name, optional, kind } => out.push_str(&input(&field, name, *optional, kind)),
            Tok::Flag { name, value: None, .. } => {
                out.push_str(&format!("<label class=\"check\"><input type=\"checkbox\" name=\"{field}\" value=\"on\"> <code>{}</code></label>", escape(name)));
            }
            Tok::Flag { name, value: Some((placeholder, kind)), .. } => {
                out.push_str(&input(&field, &format!("{name} {placeholder}"), true, kind));
            }
        }
    }
    if alt.proposes(operation) {
        out.push_str("<label class=\"check\"><input type=\"checkbox\" name=\"submit\" value=\"on\" checked> and <code>submit ID</code> at once</label>");
    }
    out.push_str("</div><p><button>Run</button></p></form></section>\n");
    out
}

fn input(field: &str, label: &str, optional: bool, kind: &Kind) -> String {
    let req = if optional { "" } else { " required" };
    let shown = format!("{}{}", escape(label), if optional { " <span class=note>(optional)</span>" } else { "" });
    match kind {
        Kind::Text => format!("<label for=\"{field}\">{shown}</label><textarea id=\"{field}\" name=\"{field}\" maxlength=\"4096\"{req}></textarea>"),
        Kind::Choice(options) => format!(
            "<label for=\"{field}\">{shown}</label><select id=\"{field}\" name=\"{field}\">{}{}</select>",
            if optional { "<option value=\"\">—</option>" } else { "" },
            options.iter().map(|o| format!("<option>{}</option>", escape(o))).collect::<String>()
        ),
        Kind::Ref => format!("<label for=\"{field}\">{shown}</label><input id=\"{field}\" name=\"{field}\" type=\"text\" list=\"refs\" autocomplete=\"off\"{req}>"),
        Kind::Id => format!("<label for=\"{field}\">{shown}</label><input id=\"{field}\" name=\"{field}\" type=\"text\" value=\"{}\" pattern=\"[A-Za-z0-9-]+\"{req}>", super::body::fresh_id()),
        Kind::Number => format!("<label for=\"{field}\">{shown}</label><input id=\"{field}\" name=\"{field}\" type=\"text\" inputmode=\"numeric\"{req}>"),
        Kind::Word => format!("<label for=\"{field}\">{shown}</label><input id=\"{field}\" name=\"{field}\" type=\"text\"{req}>"),
    }
}

// ---------------------------------------------------------------- running

/// POST `/verb/NAME`: the chosen alternative's fields become one shell line (plus `submit ID`
/// when asked), run as the member.
pub(super) fn post(site: &Site, name: &str, form: &std::collections::BTreeMap<String, String>) -> Page {
    let Some(verb) = crate::shell::command_catalog().find(|v| v.name == name) else {
        return simple(404, "No such verb", &format!("the shell has no verb {name}"));
    };
    let alts = alternatives(verb.usage);
    let Some(alt) = form.get("alt").and_then(|a| a.parse::<usize>().ok()).and_then(|i| alts.get(i)) else {
        return simple(400, name, "which alternative of the usage?");
    };
    let field = |i: usize| form.get(&format!("a{i}")).map(|v| v.trim().to_owned()).unwrap_or_default();
    let mut words: Vec<String> = Vec::new();
    let mut id = String::new();
    let mut files = 0usize;
    for (i, tok) in alt.tokens.iter().enumerate() {
        match tok {
            Tok::Lit(l) => words.push(l.clone()),
            Tok::Arg { name: label, optional, kind } => {
                let value = field(i);
                if value.is_empty() {
                    if *optional {
                        continue;
                    }
                    return simple(400, name, &format!("{label} is required"));
                }
                if matches!(kind, Kind::Id) && id.is_empty() {
                    id = value.clone();
                }
                match kind {
                    Kind::Text if !(value.starts_with('@') && !value.contains('\n')) => {
                        files += 1;
                        let stamp = if id.is_empty() { super::body::fresh_id() } else { id.clone() };
                        match super::body::text_file(site, &format!("{stamp}-{files}"), &value) {
                            Some(file) => words.push(format!("@{file}")),
                            None => return simple(400, name, &format!("{label} must be 1..4096 bytes")),
                        }
                    }
                    _ => words.push(super::body::quote(&value)),
                }
            }
            Tok::Flag { name: flag, value: None, .. } => {
                if field(i) == "on" {
                    words.push(flag.clone());
                }
            }
            Tok::Flag { name: flag, value: Some(_), .. } => {
                let value = field(i);
                if !value.is_empty() {
                    words.push(flag.clone());
                    words.push(super::body::quote(&value));
                }
            }
        }
    }
    let mut lines = vec![words.join(" ")];
    let index = form.get("alt").and_then(|a| a.parse::<usize>().ok()).unwrap_or(0);
    let mut is_transition = transition(verb.usage, verb.operation, index, &alt.literals());
    if form.get("submit").map(String::as_str) == Some("on") && alt.proposes(verb.operation) && !id.is_empty() {
        // The tour's lost-reply switch rides on the submit line (DEMO-EXPERIENCE A11).
        let lose = if form.get("lose").map(String::as_str) == Some("on") { " --lose-reply-once" } else { "" };
        lines.push(format!("submit {id}{lose}"));
        is_transition = true;
    }
    let next: Vec<(String, String)> = vec![(format!("{name} again"), format!("/verb/{name}")), ("all commands".into(), "/verb".into())];
    let refs: Vec<(&str, &str)> = next.iter().map(|(a, b)| (a.as_str(), b.as_str())).collect();
    super::body::act_as(site, &alt.literals(), lines, &id, &refs, is_transition)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_catalog_usage_parses_into_literal_led_alternatives() {
        let mut verbs = 0;
        for v in crate::shell::command_catalog() {
            verbs += 1;
            let alts = alternatives(v.usage);
            assert!(!alts.is_empty(), "{}", v.name);
            for alt in &alts {
                assert!(matches!(alt.tokens.first(), Some(Tok::Lit(_))), "{}: {:?}", v.name, alt);
            }
        }
        assert!(verbs > 60, "{verbs} verbs");
    }

    #[test]
    fn grammar_shapes_render_and_assemble() {
        let alts = alternatives("delegate ID REF RECIPIENT VERB[,VERB...] MAX-COST");
        assert_eq!(alts.len(), 1);
        let t = &alts[0].tokens;
        assert_eq!(t[0], Tok::Lit("delegate".into()));
        assert_eq!(t[1], Tok::Arg { name: "ID".into(), optional: false, kind: Kind::Id });
        assert_eq!(t[2], Tok::Arg { name: "REF".into(), optional: false, kind: Kind::Ref });
        assert_eq!(t[5], Tok::Arg { name: "MAX-COST".into(), optional: false, kind: Kind::Number });
        assert!(alts[0].proposes("mini workspace --action propose (action delegate)"));
        let room = alternatives("room new NAME [--law open|realm] [--referee SUBJECT] [--in PARENT] | room new NAME --private [--in PARENT]");
        assert_eq!(room.len(), 2);
        assert_eq!(room[0].tokens[3], Tok::Flag { name: "--law".into(), value: Some(("open|realm".into(), Kind::Choice(vec!["open".into(), "realm".into()]))), optional: true });
        assert_eq!(room[1].tokens[3], Tok::Flag { name: "--private".into(), value: None, optional: false });
        let law = alternatives("law ID REF \"CLAUSE; CLAUSE; …\"|PREDICATE-JSON|@FILE [--allow-unsatisfiable] | law show REF");
        assert_eq!(law[0].tokens[3], Tok::Arg { name: "\"CLAUSE; CLAUSE; …\"|PREDICATE-JSON|@FILE".into(), optional: false, kind: Kind::Text });
        assert_eq!(law[0].tokens[4], Tok::Flag { name: "--allow-unsatisfiable".into(), value: None, optional: true });
        assert_eq!(law[1].literals(), "law show");
        let chat = alternatives("chat new ROOM [--private: devnet quality; privacy not audited] | tail [-n N] [--since HEIGHT]");
        assert_eq!(chat[0].tokens[3], Tok::Flag { name: "--private".into(), value: None, optional: true });
        assert_eq!(chat[1].tokens[1], Tok::Flag { name: "-n".into(), value: Some(("N".into(), Kind::Number)), optional: true });
        let create = alternatives("create NAME STORAGE LAW|PREDICATE-JSON|@FILE [FIELDS|open] [--in ROOM]");
        assert_eq!(create[0].tokens[4], Tok::Arg { name: "FIELDS|open".into(), optional: true, kind: Kind::Word });
        let html = form("delegate", 0, &alts[0], "propose", "/verb/delegate", "");
        assert!(form_for("doc", "doc append", "/tour/3", "<input type=\"hidden\" name=\"verb\" value=\"doc\">").unwrap().contains("action=\"/tour/3\""));
        assert!(form_for("doc", "doc nope", "/x", "").is_none());
        let doc = crate::shell::command_catalog().find(|v| v.name == "doc").unwrap();
        let show = alternatives(doc.usage).iter().position(|a| a.literals() == "doc show").unwrap();
        let append = alternatives(doc.usage).iter().position(|a| a.literals() == "doc append").unwrap();
        assert!(!transition(doc.usage, doc.operation, show, "doc show"), "doc show is a read");
        assert!(transition(doc.usage, doc.operation, append, "doc append"), "doc append proposes");
        for (name, is) in [("whoami", false), ("help", false), ("history", false), ("can", false), ("inspect", false), ("refs", false), ("submit", true), ("delegate", true), ("create", true), ("retry", true)] {
            let v = crate::shell::command_catalog().find(|v| v.name == name).unwrap();
            assert_eq!(transition(v.usage, v.operation, 0, name), is, "{name}: {}", v.operation);
        }
        assert!(html.contains("name=\"a1\"") && html.contains("list=\"refs\"") && html.contains("name=\"submit\""), "{html}");
    }
}
