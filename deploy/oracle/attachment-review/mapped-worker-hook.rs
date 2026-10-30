// Injected only into an independent test snapshot; mirrors run()'s worker bootstrap.
#[cfg(test)]
pub(crate) fn review_initialize_mapped_worker(operator_uid: u32, operator_gid: u32, app_uid: u32, app_gid: u32) -> std::io::Result<()> {
    let (parent, child) = UnixStream::pair()?;
    let pid = unsafe { libc::fork() };
    if pid < 0 { return Err(io::Error::last_os_error()); }
    if pid == 0 {
        drop(parent);
        let status = match worker(child, Identity { uid: app_uid, gid: app_gid }) { Ok(()) => 0, Err(e) => { eprintln!("mapped review worker: {e}"); 1 } };
        unsafe { libc::_exit(status) }
    }
    drop(child);
    drop_identity(Identity { uid: operator_uid, gid: operator_gid })?;
    install_parser_namespace_filter()?;
    parent.set_read_timeout(Some(TIMEOUT))?;
    parent.set_write_timeout(Some(TIMEOUT))?;
    LAUNCH.set(Mutex::new(Some(Client { stream: parent, start: String::new(), pid: 0, worker: pid })))
        .map_err(|_| refused("review worker already initialized"))?;
    Ok(())
}
