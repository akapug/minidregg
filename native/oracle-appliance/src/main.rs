use std::{os::fd::FromRawFd, time::Duration};

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut args = std::env::args().skip(1);
    if args.next().as_deref() != Some("--port") {
        return Err(
            "usage: minidregg-oracle-appliance --port PORT (connected Sandstorm socket on fd3)"
                .into(),
        );
    }
    let port: u16 = args.next().ok_or("missing port")?.parse()?;
    if args.next().is_some() {
        return Err("unexpected argument".into());
    }
    let config = minidregg_oracle_appliance::Config::new(port, Duration::from_secs(130))?;
    // fd3 is handed to the app by the resident; ownership passes to this process.
    if unsafe { libc::fcntl(3, libc::F_GETFD) } < 0 {
        return Err("fd3 must be a connected Sandstorm Unix socket".into());
    }
    let stream = unsafe { std::os::unix::net::UnixStream::from_raw_fd(3) };
    stream.peer_addr()?;
    stream.set_nonblocking(true)?;
    let stream = tokio::net::UnixStream::from_std(stream)?;
    tokio::task::LocalSet::new()
        .run_until(minidregg_oracle_appliance::connection(stream, config))
        .await?;
    Ok(())
}
