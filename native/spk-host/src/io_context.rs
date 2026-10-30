//! One place that names the path and the operation of an I/O failure. A bare
//! `No such file or directory` surfaced as `spk-host: grain refused: ...` left the
//! integrator hunting for the missing file; every refusal path appends the context
//! instead: `<operation> <path>: <io error>`. The error kind is kept, so callers that
//! match `NotFound` or `ConnectionRefused` still do.
use std::io;
use std::path::Path;

pub(crate) trait IoContext<T> {
    fn ctx(self, operation: &str, path: impl AsRef<Path>) -> io::Result<T>;
}

impl<T> IoContext<T> for io::Result<T> {
    fn ctx(self, operation: &str, path: impl AsRef<Path>) -> io::Result<T> {
        self.map_err(|error| io::Error::new(error.kind(), format!("{operation} {}: {error}", path.as_ref().display())))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::net::UnixStream;

    #[test]
    fn a_missing_socket_names_the_operation_and_the_path() {
        let path = std::env::temp_dir().join(format!("mini-ioctx-{}/operator/mini.sock", std::process::id()));
        let error = UnixStream::connect(&path).ctx("connect operator socket", &path).unwrap_err();
        let text = error.to_string();
        assert!(text.contains("connect operator socket"), "{text}");
        assert!(text.contains(path.to_str().unwrap()), "{text}");
        assert_eq!(error.kind(), io::ErrorKind::NotFound, "the kind survives");
    }

    #[test]
    fn the_broker_connect_path_names_a_missing_socket() {
        let path = std::env::temp_dir().join(format!("mini-ioctx-b-{}/broker.sock", std::process::id()));
        let error = crate::broker::connect_for_test(&path).unwrap_err().to_string();
        assert!(error.contains("inspect broker socket") && error.contains(path.to_str().unwrap()), "{error}");
    }

    #[test]
    fn a_missing_grain_file_open_names_the_path() {
        let path = std::env::temp_dir().join(format!("mini-ioctx-g-{}/resident.json", std::process::id()));
        let error = crate::grain::read_bounded_for_test(&path).unwrap_err().to_string();
        assert!(error.contains("open") && error.contains(path.to_str().unwrap()), "{error}");
    }
}
