//! RFC 6455, server side, the part a pty bridge needs: the accept key, framing with client
//! masks, fragmentation reassembly, ping/pong and close. No extensions, no subprotocols.

use std::io::{self, Read, Write};

/// A frame larger than this is a protocol violation here (the terminal sends keystrokes).
pub const MAX_FRAME: usize = 1 << 20;

pub fn accept_key(client_key: &str) -> String {
    let digest = ring::digest::digest(&ring::digest::SHA1_FOR_LEGACY_USE_ONLY, format!("{client_key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11").as_bytes());
    base64(digest.as_ref())
}

fn base64(bytes: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::new();
    for chunk in bytes.chunks(3) {
        let mut n = 0u32;
        for (i, b) in chunk.iter().enumerate() {
            n |= (*b as u32) << (16 - 8 * i);
        }
        for i in 0..4 {
            if i <= chunk.len() {
                out.push(ALPHABET[((n >> (18 - 6 * i)) & 63) as usize] as char);
            } else {
                out.push('=');
            }
        }
    }
    out
}

#[derive(Debug, Clone, PartialEq)]
pub enum Frame {
    Text(String),
    Binary(Vec<u8>),
    Ping(Vec<u8>),
    Pong(Vec<u8>),
    Close(u16, String),
}

fn read_exact(stream: &mut impl Read, n: usize) -> io::Result<Vec<u8>> {
    let mut buffer = vec![0u8; n];
    stream.read_exact(&mut buffer)?;
    Ok(buffer)
}

/// One message (continuation frames reassembled). Client frames must be masked.
pub fn read_frame(stream: &mut impl Read) -> io::Result<Frame> {
    let mut message: Vec<u8> = Vec::new();
    let mut opcode = 0u8;
    loop {
        let head = read_exact(stream, 2)?;
        let fin = head[0] & 0x80 != 0;
        let op = head[0] & 0x0f;
        let masked = head[1] & 0x80 != 0;
        let mut length = (head[1] & 0x7f) as usize;
        if length == 126 {
            let ext = read_exact(stream, 2)?;
            length = u16::from_be_bytes([ext[0], ext[1]]) as usize;
        } else if length == 127 {
            let ext = read_exact(stream, 8)?;
            let n = u64::from_be_bytes(ext.try_into().unwrap());
            if n > MAX_FRAME as u64 {
                return Err(io::Error::new(io::ErrorKind::InvalidData, "frame too large"));
            }
            length = n as usize;
        }
        if length > MAX_FRAME || message.len() + length > MAX_FRAME {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "frame too large"));
        }
        if !masked {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "client frame is not masked"));
        }
        let mask = read_exact(stream, 4)?;
        let mut payload = read_exact(stream, length)?;
        for (i, b) in payload.iter_mut().enumerate() {
            *b ^= mask[i % 4];
        }
        match op {
            0x8 => {
                let code = if payload.len() >= 2 { u16::from_be_bytes([payload[0], payload[1]]) } else { 1005 };
                let reason = if payload.len() > 2 { String::from_utf8_lossy(&payload[2..]).into_owned() } else { String::new() };
                return Ok(Frame::Close(code, reason));
            }
            0x9 => return Ok(Frame::Ping(payload)),
            0xa => return Ok(Frame::Pong(payload)),
            0x0 => {
                if opcode == 0 {
                    return Err(io::Error::new(io::ErrorKind::InvalidData, "continuation without a start"));
                }
                message.extend_from_slice(&payload);
            }
            0x1 | 0x2 => {
                if opcode != 0 {
                    return Err(io::Error::new(io::ErrorKind::InvalidData, "a new message inside a fragmented one"));
                }
                opcode = op;
                message = payload;
            }
            _ => return Err(io::Error::new(io::ErrorKind::InvalidData, "reserved opcode")),
        }
        if fin {
            return Ok(match opcode {
                0x1 => Frame::Text(String::from_utf8(message).map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "text frame is not UTF-8"))?),
                _ => Frame::Binary(message),
            });
        }
    }
}

/// Server frames are unmasked.
pub fn write_frame(stream: &mut impl Write, frame: &Frame) -> io::Result<()> {
    let (op, payload): (u8, Vec<u8>) = match frame {
        Frame::Text(t) => (0x1, t.as_bytes().to_vec()),
        Frame::Binary(b) => (0x2, b.clone()),
        Frame::Ping(b) => (0x9, b.clone()),
        Frame::Pong(b) => (0xa, b.clone()),
        Frame::Close(code, reason) => {
            let mut p = code.to_be_bytes().to_vec();
            p.extend_from_slice(reason.as_bytes());
            (0x8, p)
        }
    };
    let mut head = vec![0x80 | op];
    let n = payload.len();
    if n < 126 {
        head.push(n as u8);
    } else if n < 65536 {
        head.push(126);
        head.extend_from_slice(&(n as u16).to_be_bytes());
    } else {
        head.push(127);
        head.extend_from_slice(&(n as u64).to_be_bytes());
    }
    stream.write_all(&head)?;
    stream.write_all(&payload)?;
    stream.flush()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accept_key_matches_rfc_6455_example() {
        assert_eq!(accept_key("dGhlIHNhbXBsZSBub25jZQ=="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=");
    }

    fn masked(op: u8, payload: &[u8], fin: bool) -> Vec<u8> {
        let mask = [1u8, 2, 3, 4];
        let mut out = vec![(if fin { 0x80 } else { 0 }) | op];
        if payload.len() < 126 {
            out.push(0x80 | payload.len() as u8);
        } else {
            out.push(0x80 | 126);
            out.extend_from_slice(&(payload.len() as u16).to_be_bytes());
        }
        out.extend_from_slice(&mask);
        out.extend(payload.iter().enumerate().map(|(i, b)| b ^ mask[i % 4]));
        out
    }

    #[test]
    fn frames_read_masked_and_reassemble() {
        let mut bytes = masked(0x1, b"hel", false);
        bytes.extend(masked(0x0, b"lo", true));
        assert_eq!(read_frame(&mut &bytes[..]).unwrap(), Frame::Text("hello".into()));
        let big = vec![7u8; 300];
        let bytes = masked(0x2, &big, true);
        assert_eq!(read_frame(&mut &bytes[..]).unwrap(), Frame::Binary(big));
        let mut close = 1000u16.to_be_bytes().to_vec();
        close.extend_from_slice(b"bye");
        assert_eq!(read_frame(&mut &masked(0x8, &close, true)[..]).unwrap(), Frame::Close(1000, "bye".into()));
        let unmasked = [0x81u8, 0x01, b'x'];
        assert!(read_frame(&mut &unmasked[..]).is_err());
        let mut out = Vec::new();
        write_frame(&mut out, &Frame::Binary(vec![1, 2, 3])).unwrap();
        assert_eq!(out, vec![0x82, 3, 1, 2, 3]);
    }
}
