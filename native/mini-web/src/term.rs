//! The terminal bridge: a pty master the helper handed over, pumped to and from one WebSocket at
//! a time. A 64 KiB replay ring and a 60 s grace after a socket drops let a reload rejoin the same
//! shell. Dropping the master is what ends the shell (SIGHUP from the kernel); the helper reaps it.

use std::collections::{HashMap, VecDeque};
use std::fs::File;
use std::io::{Read, Write};
use std::net::TcpStream;
use std::os::fd::{AsRawFd, OwnedFd};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use crate::ws::{write_frame, Frame};

pub const RING: usize = 64 * 1024;
pub const GRACE: Duration = Duration::from_secs(60);

pub struct Terminal {
    pub id: String,
    /// The session (its SHA-256 prefix) that may attach.
    pub owner: String,
    pub pid: u32,
    master: File,
    ring: Mutex<VecDeque<u8>>,
    sink: Mutex<Option<TcpStream>>,
    detached_at: Mutex<Option<Instant>>,
    exited: AtomicBool,
    pub created: Instant,
}

impl Terminal {
    /// Replay what the browser missed, then make this socket the sink.
    pub fn attach(&self, stream: TcpStream) -> std::io::Result<()> {
        let mut stream = stream;
        let replay: Vec<u8> = self.ring.lock().unwrap().iter().copied().collect();
        if !replay.is_empty() {
            write_frame(&mut stream, &Frame::Binary(replay))?;
        }
        if self.exited.load(Ordering::Acquire) {
            let _ = write_frame(&mut stream, &Frame::Close(1000, "exited".into()));
        }
        *self.sink.lock().unwrap() = Some(stream);
        *self.detached_at.lock().unwrap() = None;
        Ok(())
    }

    pub fn detach(&self) {
        *self.sink.lock().unwrap() = None;
        *self.detached_at.lock().unwrap() = Some(Instant::now());
    }

    pub fn attached(&self) -> bool {
        self.sink.lock().unwrap().is_some()
    }

    pub fn input(&self, bytes: &[u8]) -> std::io::Result<()> {
        (&self.master).write_all(bytes)
    }

    pub fn resize(&self, cols: u16, rows: u16) {
        mini_web_spawn::spawn::set_window_size(self.master.as_raw_fd(), cols, rows);
    }

    pub fn exited(&self) -> bool {
        self.exited.load(Ordering::Acquire)
    }

    fn pump(self: &Arc<Self>) {
        let mut buffer = [0u8; 4096];
        loop {
            let n = match (&self.master).read(&mut buffer) {
                Ok(0) | Err(_) => {
                    self.exited.store(true, Ordering::Release);
                    if let Some(sink) = self.sink.lock().unwrap().as_mut() {
                        let _ = write_frame(sink, &Frame::Close(1000, "exited".into()));
                    }
                    return;
                }
                Ok(n) => n,
            };
            {
                let mut ring = self.ring.lock().unwrap();
                ring.extend(&buffer[..n]);
                while ring.len() > RING {
                    ring.pop_front();
                }
            }
            let mut sink = self.sink.lock().unwrap();
            if let Some(stream) = sink.as_mut() {
                if write_frame(stream, &Frame::Binary(buffer[..n].to_vec())).is_err() {
                    *sink = None;
                    *self.detached_at.lock().unwrap() = Some(Instant::now());
                }
            }
        }
    }
}

#[derive(Default)]
pub struct Terminals {
    inner: Mutex<HashMap<String, Arc<Terminal>>>,
}

impl Terminals {
    pub fn create(&self, owner: &str, pid: u32, master: OwnedFd) -> Arc<Terminal> {
        let id = mini_web_spawn::new_token().unwrap_or_else(|_| format!("t{pid}"));
        let terminal = Arc::new(Terminal {
            id: id.clone(),
            owner: owner.to_owned(),
            pid,
            master: File::from(master),
            ring: Mutex::new(VecDeque::new()),
            sink: Mutex::new(None),
            detached_at: Mutex::new(Some(Instant::now())),
            exited: AtomicBool::new(false),
            created: Instant::now(),
        });
        self.inner.lock().unwrap().insert(id, terminal.clone());
        let pumped = terminal.clone();
        let _ = std::thread::Builder::new().name("mini-web-pty".into()).spawn(move || pumped.pump());
        terminal
    }

    pub fn get(&self, id: &str, owner: &str) -> Option<Arc<Terminal>> {
        self.inner.lock().unwrap().get(id).filter(|t| t.owner == owner).cloned()
    }

    pub fn of(&self, owner: &str) -> Vec<Arc<Terminal>> {
        let mut out: Vec<_> = self.inner.lock().unwrap().values().filter(|t| t.owner == owner).cloned().collect();
        out.sort_by_key(|t| t.created);
        out
    }

    /// Drop every terminal of a session (logout, revoke): the masters close, the shells hang up.
    pub fn end(&self, owner: &str) {
        let mut inner = self.inner.lock().unwrap();
        let ids: Vec<String> = inner.values().filter(|t| t.owner == owner).map(|t| t.id.clone()).collect();
        for id in ids {
            if let Some(t) = inner.remove(&id) {
                unsafe { libc::kill(t.pid as i32, libc::SIGHUP) };
            }
        }
    }

    pub fn close(&self, id: &str, owner: &str) -> bool {
        let mut inner = self.inner.lock().unwrap();
        match inner.get(id) {
            Some(t) if t.owner == owner => {
                let t = inner.remove(id).unwrap();
                unsafe { libc::kill(t.pid as i32, libc::SIGHUP) };
                true
            }
            _ => false,
        }
    }

    /// Exited terminals and terminals detached past the grace go.
    pub fn sweep(&self) {
        let mut inner = self.inner.lock().unwrap();
        inner.retain(|_, t| {
            if t.exited() && !t.attached() {
                return false;
            }
            match *t.detached_at.lock().unwrap() {
                Some(at) if at.elapsed() > GRACE => {
                    unsafe { libc::kill(t.pid as i32, libc::SIGHUP) };
                    false
                }
                _ => true,
            }
        });
    }
}
