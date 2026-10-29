//! A JSON read is data for a renderer, not a transcript to abbreviate.
pub(crate) const MAX_CAPTURE: usize = 8 * 1024 * 1024;
const TEXT_LIMIT: usize = 64 * 1024;

pub(crate) fn text(bytes: Vec<u8>) -> String {
    let mut s = String::from_utf8_lossy(&bytes).into_owned();
    if s.len() > TEXT_LIMIT {
        let mut end = TEXT_LIMIT;
        while !s.is_char_boundary(end) { end -= 1; }
        s.truncate(end);
        s.push_str("\n…");
    }
    s
}

pub(crate) fn structured(bytes: Vec<u8>) -> Result<String, &'static str> {
    if bytes.len() > MAX_CAPTURE {
        return Err("error: structured read reply exceeds 8 MiB; narrow the request\n");
    }
    String::from_utf8(bytes).map_err(|_| "error: structured read reply is not UTF-8\n")
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn structured_catalogue_survives_the_transcript_limit() {
        let reply = format!("{{\"description\":\"{}\"}}", "a".repeat(70_000));
        assert!(structured(reply.as_bytes().to_vec()).unwrap() == reply, "the renderer must receive the entire JSON value");
    }
    #[test]
    fn oversized_structured_reply_is_explained_not_truncated() {
        assert!(structured(vec![b'a'; MAX_CAPTURE + 1]) == Err("error: structured read reply exceeds 8 MiB; narrow the request\n"));
    }
    #[test]
    fn transcript_limit_keeps_utf8_intact() {
        assert_eq!(text("€".repeat(30_000).into_bytes()), format!("{}\n…", "€".repeat(TEXT_LIMIT / 3)));
    }
}
