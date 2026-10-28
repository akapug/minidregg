//! Verify genuine signed SPKs without retaining the compressed or decoded archive in RAM.
//!
//! The input is copied to a private anonymous snapshot, then liblzma decodes into another
//! anonymous file with independent dictionary/output limits. A read-only mapping is used
//! only to validate Cap'n Proto pointers and build a bounded index. File contents are not
//! copied while indexing. The mapping is dropped before returning; extraction uses 64 KiB
//! positional reads. The caller owns protected staging and atomic publication.

use capnp::{
    message::{Reader, ReaderOptions},
    serialize::{BufferSegments, SegmentLengthsBuilder},
};
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use sha2::{Digest, Sha256, Sha512};
use std::{
    collections::BTreeSet,
    fs::{File, OpenOptions},
    io::{self, Read, Seek, SeekFrom, Write},
    os::unix::fs::{FileExt, MetadataExt, OpenOptionsExt, PermissionsExt},
    path::{Component, Path, PathBuf},
};

#[allow(clippy::all)]
pub mod archive_capnp {
    include!(concat!(env!("OUT_DIR"), "/archive_capnp.rs"));
}

const MAGIC: [u8; 8] = [0x8f, 0xc6, 0xcd, 0xef, 0x45, 0x1a, 0xea, 0x96];
/// Absolute ceiling over every profile's `Limits::capnp_segments`: no import profile can
/// admit a segment table past it.
const MAX_SEGMENTS: u32 = 4096;
const MAX_SIGNATURE: usize = 64 * 1024;
const MAX_MANIFEST: usize = 1024 * 1024;
const MAX_CONFIG: usize = 64 * 1024;
const MAX_NAME_BYTES: usize = 16 * 1024 * 1024;
const MAX_FILES: usize = 100_000;
const MAX_DEPTH: usize = 64;

/// Selected by a trusted caller, never by package metadata. Output also bounds
/// the sum of extracted member lengths, so pointer aliasing cannot amplify disk use.
#[derive(Clone, Copy, Debug)]
pub struct Limits {
    pub raw_bytes: u64,
    pub decoded_bytes: u64,
    pub decoder_memory_bytes: u64,
    /// Bound on Cap'n Proto segments in one message, enforced before the library reader
    /// (`serialize::read_message_from_flat_slice` refuses everything past 512 segments,
    /// its fixed `SEGMENTS_COUNT_LIMIT`, which class-L market archives legitimately
    /// exceed: the IPython package's 667 MiB decoded archive is 583 segments). The
    /// segment table is parsed under this bound and decoded through `BufferSegments`,
    /// whose reader path carries no count limit of its own. `standard-v1` keeps the
    /// library's 512; the large profiles take the absolute ceiling, which covers their
    /// decoded bound many times over at the observed builder density.
    pub capnp_segments: u32,
    /// The intake's wall-clock cap, the most `wall_seconds` can grant.
    pub wall_cap_seconds: u64,
}

/// The intake's wall clock grows with the work: a fixed floor for the process and the
/// signature, then a per-MiB allowance for decoding and writing the archive. The ingest unit runs
/// at one CPU (`CPUQuota=100%`), where xz decoding, hashing and writing the up-to-3x decoded tree
/// take about 1 s per raw MiB. The allowance is three times that, so a shared, loaded build or
/// demo box still finishes. The bound stays proportional to the bytes the profile already
/// admitted, so a package cannot buy more time than its own size, and the profile's cap still
/// holds.
pub const WALL_FLOOR_SECONDS: u64 = 60;
pub const WALL_SECONDS_PER_MIB: u64 = 3;

impl Limits {
    pub const DEFAULT: Self = Self {
        raw_bytes: 256 * 1024 * 1024,
        decoded_bytes: 768 * 1024 * 1024,
        decoder_memory_bytes: 128 * 1024 * 1024,
        capnp_segments: 512,
        wall_cap_seconds: 900,
    };
    /// `market-large-v1`, for the market's class L apps (a bundled database or runtime: Wekan's
    /// mongod and Meteor bundle decode past 768 MiB). It raises only the raw and decoded byte bounds:
    /// raw 512 MiB, decoded 2 GiB. The parser is the same streaming verifier with the same
    /// 128 MiB decoder memory, so its memory use does not grow. The decoded bound is enforced
    /// twice: here, as the sum of extracted member lengths (so aliased members cannot amplify
    /// it), and as the ingest unit's `LimitFSIZE`. One image is kept per package hash per
    /// store, so a store's image disk is at most 2 GiB times the number of distinct large
    /// packages its operator's market admits. The operator selects the profile; package
    /// metadata never does.
    pub const MARKET_LARGE: Self = Self {
        raw_bytes: 512 * 1024 * 1024,
        decoded_bytes: 2 * 1024 * 1024 * 1024,
        decoder_memory_bytes: 128 * 1024 * 1024,
        capnp_segments: MAX_SEGMENTS,
        wall_cap_seconds: 1800,
    };
    pub const OPERATOR_APPLIANCE: Self = Self {
        raw_bytes: 8 * 1024 * 1024 * 1024,
        decoded_bytes: 20 * 1024 * 1024 * 1024,
        decoder_memory_bytes: 128 * 1024 * 1024,
        capnp_segments: MAX_SEGMENTS,
        wall_cap_seconds: 1800,
    };

    /// The intake wall clock for a raw package of `raw_len` bytes: the floor plus the per-MiB
    /// allowance, at most the profile's cap.
    pub fn wall_seconds(&self, raw_len: u64) -> u64 {
        let mib = raw_len.div_ceil(1024 * 1024);
        WALL_FLOOR_SECONDS
            .saturating_add(mib.saturating_mul(WALL_SECONDS_PER_MIB))
            .min(self.wall_cap_seconds)
    }
}

/// Operator policy names are stable and never read from the signed archive.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum ImportProfile {
    #[default]
    Standard,
    MarketLarge,
    OperatorAppliance,
}
impl ImportProfile {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Standard => "standard-v1",
            Self::MarketLarge => "market-large-v1",
            Self::OperatorAppliance => "operator-appliance-v1",
        }
    }
    pub fn limits(self) -> Limits {
        match self {
            Self::Standard => Limits::DEFAULT,
            Self::MarketLarge => Limits::MARKET_LARGE,
            Self::OperatorAppliance => Limits::OPERATOR_APPLIANCE,
        }
    }
}
impl std::str::FromStr for ImportProfile {
    type Err = io::Error;
    fn from_str(name: &str) -> io::Result<Self> {
        match name {
            "standard-v1" => Ok(Self::Standard),
            "market-large-v1" => Ok(Self::MarketLarge),
            "operator-appliance-v1" => Ok(Self::OperatorAppliance),
            _ => Err(invalid("unknown SPK import profile")),
        }
    }
}

#[derive(Debug)]
pub enum EntryKind {
    Directory,
    Symlink(String),
    Regular { executable: bool },
}
#[derive(Debug)]
pub struct Entry {
    pub path: PathBuf,
    pub kind: EntryKind,
    offset: u64,
    length: u64,
}
impl Entry {
    pub fn len(&self) -> u64 {
        self.length
    }
    pub fn is_empty(&self) -> bool {
        self.length == 0
    }
}

pub struct VerifiedPackage {
    raw: File,
    decoded: File,
    entries: Vec<Entry>,
    pub raw_sha256: [u8; 32],
    pub raw_length: u64,
    pub public_key: [u8; 32],
    pub manifest_bytes: Vec<u8>,
    pub bridge_config_bytes: Option<Vec<u8>>,
    /// Exact optional signed public-data declaration; semantic validation is host-owned.
    pub data_config_bytes: Option<Vec<u8>>,
    pub manifest: sandstorm_package::SpkManifest,
}
impl VerifiedPackage {
    pub fn entries(&self) -> &[Entry] {
        &self.entries
    }
    /// Copies exactly the verified input snapshot, regardless of changes to its source path.
    pub fn copy_raw(&self, out: &mut impl Write) -> io::Result<()> {
        copy_range(&self.raw, 0, self.raw_length, out)
    }
    /// Entries are selected by index so a caller cannot supply an entry from another package.
    pub fn copy_member(&self, index: usize, out: &mut impl Write) -> io::Result<()> {
        let entry = self
            .entries
            .get(index)
            .ok_or_else(|| invalid("unknown package member"))?;
        if !matches!(entry.kind, EntryKind::Regular { .. }) {
            return Err(invalid("member is not a file"));
        }
        copy_range(&self.decoded, entry.offset, entry.length, out)
    }
}
fn invalid(message: impl std::fmt::Display) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message.to_string())
}
fn copy_range(
    file: &File,
    mut offset: u64,
    mut length: u64,
    out: &mut impl Write,
) -> io::Result<()> {
    let mut buffer = [0u8; 64 * 1024];
    while length != 0 {
        let amount = length.min(buffer.len() as u64) as usize;
        file.read_exact_at(&mut buffer[..amount], offset)?;
        out.write_all(&buffer[..amount])?;
        offset += amount as u64;
        length -= amount as u64;
    }
    Ok(())
}

/// `scratch` must be a caller-owned protected directory with space for raw + decoded
/// bytes. Anonymous temporary files are dropped on every failure. No image is published.
pub fn verify(path: &Path, scratch: &Path, limits: Limits) -> io::Result<VerifiedPackage> {
    let mut input = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
        .open(path)?;
    let metadata = input.metadata()?;
    if !metadata.is_file() || metadata.len() > limits.raw_bytes {
        return Err(invalid("SPK input exceeds raw bound or is not regular"));
    }
    check_workspace(
        scratch,
        metadata.len().saturating_add(limits.decoded_bytes),
        limits,
    )?;
    let mut raw = tempfile::tempfile_in(scratch)?;
    let mut raw_hash = Sha256::new();
    let mut buffer = [0u8; 64 * 1024];
    let mut raw_length = 0u64;
    loop {
        let n = input.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        raw_length = raw_length
            .checked_add(n as u64)
            .ok_or_else(|| invalid("raw size overflow"))?;
        if raw_length > limits.raw_bytes {
            return Err(invalid("SPK exceeds raw bound"));
        }
        raw_hash.update(&buffer[..n]);
        raw.write_all(&buffer[..n])?;
    }
    if raw_length != metadata.len() {
        return Err(invalid("SPK length changed during snapshot"));
    }
    raw.seek(SeekFrom::Start(0))?;
    let mut magic = [0u8; 8];
    raw.read_exact(&mut magic)?;
    if magic != MAGIC {
        return Err(invalid("bad SPK magic"));
    }
    let stream =
        xz2::stream::Stream::new_stream_decoder(limits.decoder_memory_bytes, 0).map_err(invalid)?;
    let mut decoder = xz2::read::XzDecoder::new_stream(&raw, stream);
    let mut decoded = tempfile::tempfile_in(scratch)?;
    let mut decoded_length = 0u64;
    loop {
        let n = decoder.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        decoded_length = decoded_length
            .checked_add(n as u64)
            .ok_or_else(|| invalid("decoded size overflow"))?;
        if decoded_length > limits.decoded_bytes {
            return Err(invalid("SPK exceeds decoded bound"));
        }
        decoded.write_all(&buffer[..n])?;
    }
    if decoder.total_in() != raw_length - 8 {
        return Err(invalid("trailing bytes after XZ stream"));
    }
    drop(decoder);
    // SAFETY: this anonymous file is private to this function. No descriptor or path
    // escapes, and it is never mutated or truncated during the mapping's lifetime.
    let mapping = unsafe { memmap2::MmapOptions::new().map(&decoded)? };
    let segments = segment_bound(&limits);
    let sig_length = frame_length(&mapping, MAX_SIGNATURE as u64, segments)?;
    let options = ReaderOptions {
        traversal_limit_in_words: Some(MAX_SIGNATURE / 8),
        nesting_limit: 16,
    };
    let sig_message = read_bounded_message(&mapping[..sig_length], segments, options)?;
    let signature = sig_message
        .get_root::<archive_capnp::signature::Reader>()
        .map_err(invalid)?;
    let public_key: [u8; 32] = signature
        .get_public_key()
        .map_err(invalid)?
        .try_into()
        .map_err(|_| invalid("invalid public key length"))?;
    let combined = signature.get_signature().map_err(invalid)?;
    if combined.len() != 128 {
        return Err(invalid("invalid combined signature length"));
    }
    let mut archive_hash = Sha512::new();
    decoded.seek(SeekFrom::Start(sig_length as u64))?;
    loop {
        let n = decoded.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        archive_hash.update(&buffer[..n]);
    }
    let hash = archive_hash.finalize();
    if hash.as_slice() != &combined[64..] {
        return Err(invalid("archive hash mismatch"));
    }
    let sig = Signature::from_slice(&combined[..64]).map_err(invalid)?;
    VerifyingKey::from_bytes(&public_key)
        .map_err(invalid)?
        .verify(&hash, &sig)
        .map_err(invalid)?;
    let archive_bytes = &mapping[sig_length..];
    if frame_length(archive_bytes, limits.decoded_bytes, segments)? != archive_bytes.len() {
        return Err(invalid("trailing bytes after archive message"));
    }
    let words = usize::try_from(limits.decoded_bytes / 8)
        .map_err(|_| invalid("profile exceeds address space"))?;
    let message = read_bounded_message(
        archive_bytes,
        segments,
        ReaderOptions {
            traversal_limit_in_words: Some(words.saturating_add(MAX_NAME_BYTES)),
            nesting_limit: 160,
        },
    )?;
    let archive = message
        .get_root::<archive_capnp::archive::Reader>()
        .map_err(invalid)?;
    let mut index = Index {
        entries: Vec::new(),
        names: 0,
        data: 0,
        max_data: limits.decoded_bytes,
        base: mapping.as_ptr() as usize,
    };
    index.walk(archive.get_files().map_err(invalid)?, Path::new(""), 0)?;
    let member = |name: &str, max: usize| -> io::Result<Option<Vec<u8>>> {
        match index
            .entries
            .iter()
            .find(|entry| entry.path == Path::new(name))
        {
            None => Ok(None),
            Some(entry)
                if matches!(entry.kind, EntryKind::Regular { .. })
                    && entry.length != 0
                    && entry.length <= max as u64 =>
            {
                Ok(Some(
                    mapping[entry.offset as usize..(entry.offset + entry.length) as usize].to_vec(),
                ))
            }
            Some(_) => Err(invalid(format!("invalid or oversized {name}"))),
        }
    };
    let manifest_bytes = member("sandstorm-manifest", MAX_MANIFEST)?
        .ok_or_else(|| invalid("missing signed manifest"))?;
    let bridge_config_bytes = member("sandstorm-http-bridge-config", MAX_CONFIG)?;
    let data_config_bytes = member("minidregg-data.json", 4096)?;
    // Reuse Bread's manifest decoder and intrinsic signing-key App ID derivation.
    // This tiny projection contains only already-verified metadata, never archive data.
    let projection = sandstorm_package::Spk {
        public_key,
        archive: sandstorm_package::Archive {
            files: vec![sandstorm_package::File::regular(
                "sandstorm-manifest",
                manifest_bytes.clone(),
            )],
        },
    };
    let manifest = sandstorm_package::SpkManifest::from_spk(&projection).map_err(invalid)?;
    Ok(VerifiedPackage {
        raw,
        decoded,
        entries: index.entries,
        raw_sha256: raw_hash.finalize().into(),
        raw_length,
        public_key,
        manifest_bytes,
        bridge_config_bytes,
        data_config_bytes,
        manifest,
    })
}

/// For qualification and resident verification, make a private scratch directory in
/// the operator's temporary filesystem. Returned anonymous files outlive the directory.
pub fn verify_in_private_temp(path: &Path, limits: Limits) -> io::Result<VerifiedPackage> {
    let scratch = tempfile::tempdir()?;
    verify(path, scratch.path(), limits)
}

/// Make anonymous spools below an explicitly selected persistent directory. Every
/// ancestor must be controlled by root/current operator and not writable by others.
pub fn verify_in_private_temp_at(
    path: &Path,
    parent: &Path,
    limits: Limits,
) -> io::Result<VerifiedPackage> {
    verify_in_private_temp_at_with_root_custody(path, parent, limits, |_, meta| meta.uid() == 0)
}

/// A host that changes user namespaces must supply its held pre-entry root
/// provenance here. The predicate cannot be inferred from an overflow UID.
/// All ordinary operator, type, no-symlink and mode checks remain mandatory.
pub fn verify_in_private_temp_at_with_root_custody(
    path: &Path,
    parent: &Path,
    limits: Limits,
    root_owned: impl Fn(&Path, &std::fs::Metadata) -> bool,
) -> io::Result<VerifiedPackage> {
    if !parent.is_absolute() {
        return Err(invalid("scratch parent must be absolute"));
    }
    for ancestor in parent.ancestors() {
        let meta = std::fs::symlink_metadata(ancestor)?;
        if !meta.is_dir()
            || meta.file_type().is_symlink()
            || (!root_owned(ancestor, &meta) && meta.uid() != unsafe { libc::geteuid() })
            || meta.permissions().mode() & 0o022 != 0
        {
            return Err(invalid("scratch parent custody refused"));
        }
    }
    verify(path, parent, limits)
}

/// Conservative available-space preflight, not a reservation against other writers
/// or filesystem quotas. The caller includes publication copies in `minimum_bytes`.
/// Large profiles refuse Linux memory-backed filesystems: their spools would consume
/// the decoder's cgroup memory instead of persistent disk.
pub fn check_workspace(scratch: &Path, minimum_bytes: u64, limits: Limits) -> io::Result<()> {
    use std::os::fd::AsRawFd;
    let file = File::open(scratch)?;
    if !file.metadata()?.is_dir() {
        return Err(invalid("scratch is not a directory"));
    }
    #[cfg(target_os = "linux")]
    if limits.decoded_bytes > Limits::DEFAULT.decoded_bytes {
        let mut stat = std::mem::MaybeUninit::<libc::statfs>::uninit();
        // SAFETY: fstatfs writes the supplied valid output structure.
        if unsafe { libc::fstatfs(file.as_raw_fd(), stat.as_mut_ptr()) } != 0 {
            return Err(io::Error::last_os_error());
        }
        let stat = unsafe { stat.assume_init() };
        // Linux include/uapi/linux/magic.h; libc 0.2.189 exposes TMPFS_MAGIC
        // but not RAMFS_MAGIC. Do not confuse this with CRAMFS_MAGIC.
        const RAMFS_MAGIC: libc::c_long = 0x8584_58f6u32 as libc::c_long;
        if stat.f_type == libc::TMPFS_MAGIC || stat.f_type == RAMFS_MAGIC {
            return Err(invalid(
                "large SPK profile requires disk-backed scratch, not tmpfs/ramfs",
            ));
        }
    }
    #[cfg(not(target_os = "linux"))]
    let _ = limits;
    let mut stat = std::mem::MaybeUninit::<libc::statvfs>::uninit();
    // SAFETY: fstatvfs writes the supplied valid output structure.
    if unsafe { libc::fstatvfs(file.as_raw_fd(), stat.as_mut_ptr()) } != 0 {
        return Err(io::Error::last_os_error());
    }
    let stat = unsafe { stat.assume_init() };
    let available = u128::from(stat.f_bavail) * u128::from(stat.f_frsize);
    if available < u128::from(minimum_bytes) {
        return Err(invalid(
            "insufficient scratch workspace for selected SPK profile",
        ));
    }
    Ok(())
}

// The profile's Cap'n Proto segment bound, clamped to the absolute table ceiling, so no
// future profile can widen the pre-check past `MAX_SEGMENTS`.
fn segment_bound(limits: &Limits) -> u32 {
    limits.capnp_segments.min(MAX_SEGMENTS)
}

fn table_word(bytes: &[u8], at: usize) -> io::Result<u32> {
    Ok(u32::from_le_bytes(
        bytes
            .get(at..at + 4)
            .ok_or_else(|| invalid("truncated segment table"))?
            .try_into()
            .unwrap(),
    ))
}

struct SegmentTable {
    count: u32,
    table_bytes: usize,
    frame_bytes: u64,
}

// Bound segment-table allocation before the Cap'n Proto library sees untrusted framing.
// The segment count is bounded by the import profile, not by the library's fixed 512
// (`serialize::read_message_from_flat_slice` refuses past it whatever the byte bounds).
fn parse_segment_table(bytes: &[u8], max_segments: u32) -> io::Result<SegmentTable> {
    let count = table_word(bytes, 0)?
        .checked_add(1)
        .ok_or_else(|| invalid("segment count overflow"))?;
    if count > max_segments {
        return Err(invalid(format!(
            "too many Cap'n Proto segments: {count} exceeds bound {max_segments}"
        )));
    }
    let table_bytes = (((4 + 4 * u64::from(count)) + 7) & !7) as usize;
    let mut frame_bytes = table_bytes as u64;
    for i in 0..count as usize {
        frame_bytes += u64::from(table_word(bytes, 4 + i * 4)?) * 8;
    }
    Ok(SegmentTable {
        count,
        table_bytes,
        frame_bytes,
    })
}

fn frame_length(bytes: &[u8], max: u64, max_segments: u32) -> io::Result<usize> {
    let table = parse_segment_table(bytes, max_segments)?;
    if table.frame_bytes > max || table.frame_bytes > bytes.len() as u64 {
        return Err(invalid("truncated or oversized Cap'n Proto frame"));
    }
    Ok(table.frame_bytes as usize)
}

/// Decode one Cap'n Proto message frame under the profile's segment bound, in place of
/// `serialize::read_message_from_flat_slice`, whose library reader refuses every message
/// at 512 segments. The table is already bounded by `parse_segment_table`; the segments
/// go to `BufferSegments`, whose reader path carries no count limit of its own.
fn read_bounded_message<'a>(
    bytes: &'a [u8],
    max_segments: u32,
    options: ReaderOptions,
) -> io::Result<Reader<BufferSegments<&'a [u8]>>> {
    let table = parse_segment_table(bytes, max_segments)?;
    if table.frame_bytes > bytes.len() as u64 {
        return Err(invalid("truncated or oversized Cap'n Proto frame"));
    }
    let mut lengths = SegmentLengthsBuilder::with_capacity(table.count as usize);
    for i in 0..table.count as usize {
        lengths
            .try_push_segment(table_word(bytes, 4 + i * 4)? as usize)
            .map_err(invalid)?;
    }
    debug_assert!(table.table_bytes + lengths.total_words() * 8 <= bytes.len());
    Ok(Reader::new(
        lengths.into_slice_segments(bytes, table.table_bytes),
        options,
    ))
}

struct Index {
    entries: Vec<Entry>,
    names: usize,
    data: u64,
    max_data: u64,
    base: usize,
}
impl Index {
    fn walk(
        &mut self,
        files: capnp::struct_list::Reader<'_, archive_capnp::archive::file::Owned>,
        parent: &Path,
        depth: usize,
    ) -> io::Result<()> {
        if depth > MAX_DEPTH {
            return Err(invalid("archive depth exceeds bound"));
        }
        if files.len() as usize > MAX_FILES - self.entries.len() {
            return Err(invalid("too many archive files"));
        }
        let mut names = BTreeSet::new();
        for file in files {
            if self.entries.len() >= MAX_FILES {
                return Err(invalid("too many archive files"));
            }
            let text = file.get_name().map_err(invalid)?;
            let name = text.to_str().map_err(invalid)?;
            if name.is_empty()
                || name.len() > 255
                || matches!(name, "." | "..")
                || name.contains(['/', '\0'])
            {
                return Err(invalid("invalid archive name"));
            }
            if !names.insert(name.to_owned()) {
                return Err(invalid("duplicate archive name"));
            }
            let path = parent.join(name);
            if path.as_os_str().len() > 4096 {
                return Err(invalid("archive path exceeds bound"));
            }
            self.names += path.as_os_str().len();
            if self.names > MAX_NAME_BYTES {
                return Err(invalid("archive names exceed bound"));
            }
            let union = file.which().map_err(invalid)?;
            use archive_capnp::archive::file::Which;
            let executable = matches!(union, Which::Executable(_));
            if parent.as_os_str().is_empty()
                && matches!(name, "var" | "tmp" | "proc" | "dev")
                && !matches!(union, Which::Directory(_))
            {
                return Err(invalid("reserved mountpoint is not a directory"));
            }
            let mut entry = Entry {
                path: path.clone(),
                kind: EntryKind::Directory,
                offset: 0,
                length: 0,
            };
            match union {
                Which::Regular(data) | Which::Executable(data) => {
                    let data = data.map_err(invalid)?;
                    self.data = self
                        .data
                        .checked_add(data.len() as u64)
                        .ok_or_else(|| invalid("member size overflow"))?;
                    if self.data > self.max_data {
                        return Err(invalid("extracted bytes exceed bound"));
                    }
                    entry.offset = if data.is_empty() {
                        0
                    } else {
                        (data.as_ptr() as usize - self.base) as u64
                    };
                    entry.length = data.len() as u64;
                    entry.kind = EntryKind::Regular { executable };
                    self.entries.push(entry);
                }
                Which::Symlink(target) => {
                    let target = target.map_err(invalid)?;
                    let target = target.to_str().map_err(invalid)?;
                    if target.len() > 4096 {
                        return Err(invalid("symlink target too long"));
                    }
                    valid_link(parent, target)?;
                    self.names += target.len();
                    if self.names > MAX_NAME_BYTES {
                        return Err(invalid("archive names exceed bound"));
                    }
                    entry.kind = EntryKind::Symlink(target.to_owned());
                    self.entries.push(entry);
                }
                Which::Directory(children) => {
                    self.entries.push(entry);
                    self.walk(children.map_err(invalid)?, &path, depth + 1)?;
                }
            }
        }
        Ok(())
    }
}
fn valid_link(parent: &Path, target: &str) -> io::Result<()> {
    if target.is_empty() || target.contains('\0') {
        return Err(invalid("invalid symlink target"));
    }
    let path = Path::new(target);
    let mut depth = if path.is_absolute() {
        0
    } else {
        parent.components().count()
    };
    for component in path.components() {
        match component {
            Component::Normal(_) => depth += 1,
            Component::ParentDir => {
                if depth == 0 {
                    return Err(invalid("symlink escapes image"));
                }
                depth -= 1;
            }
            Component::RootDir => depth = 0,
            Component::CurDir => {}
            Component::Prefix(_) => return Err(invalid("unsupported symlink prefix")),
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer, SigningKey};
    use sandstorm_package::{File as Member, FileContent, SpkBuilder};
    const MANIFEST: &str = r#"{"app_id":"untrusted","app_title":"stream fixture","app_version":1,"continue_command":{"argv":["/app"]}}"#;
    fn key() -> SigningKey {
        SigningKey::from_bytes(&[7; 32])
    }
    fn fixture(file: Member) -> Vec<u8> {
        SpkBuilder::new()
            .manifest_json(MANIFEST)
            .file(file)
            .pack(&key())
    }
    fn unpack(bytes: &[u8], limits: Limits) -> io::Result<VerifiedPackage> {
        let dir = tempfile::tempdir()?;
        let path = dir.path().join("test.spk");
        std::fs::write(&path, bytes)?;
        verify(&path, dir.path(), limits)
    }
    fn compress(plain: &[u8]) -> Vec<u8> {
        let mut encoder = xz2::write::XzEncoder::new(Vec::new(), 1);
        encoder.write_all(plain).unwrap();
        let mut bytes = MAGIC.to_vec();
        bytes.extend(encoder.finish().unwrap());
        bytes
    }
    fn sign(archive: &[u8]) -> Vec<u8> {
        let hash = Sha512::digest(archive);
        let mut combined = key().sign(&hash).to_bytes().to_vec();
        combined.extend_from_slice(&hash);
        let mut plain = sandstorm_package::capnp_wire::write_signature(
            key().verifying_key().as_bytes(),
            &combined,
        );
        plain.extend_from_slice(archive);
        compress(&plain)
    }
    #[test]
    fn genuine_bread_fixture_exact_bytes_identity_and_snapshot() {
        let bytes = fixture(Member::executable("app", b"payload".to_vec()));
        let parsed = unpack(&bytes, Limits::DEFAULT).unwrap();
        assert_eq!(
            parsed.manifest,
            sandstorm_package::SpkManifest::from_spk(
                &sandstorm_package::Spk::parse(&bytes).unwrap()
            )
            .unwrap()
        );
        assert_eq!(parsed.manifest_bytes, MANIFEST.as_bytes());
        assert_eq!(parsed.raw_sha256, <[u8; 32]>::from(Sha256::digest(&bytes)));
        let mut copied = Vec::new();
        parsed.copy_raw(&mut copied).unwrap();
        assert_eq!(copied, bytes);
        let index = parsed
            .entries()
            .iter()
            .position(|e| e.path == Path::new("app"))
            .unwrap();
        copied.clear();
        parsed.copy_member(index, &mut copied).unwrap();
        assert_eq!(copied, b"payload");
        assert!(matches!(
            parsed.entries()[index].kind,
            EntryKind::Regular { executable: true }
        ));
    }
    #[test]
    fn wall_clock_scales_with_the_package_and_each_profile_keeps_its_cap() {
        let mib = 1024 * 1024;
        assert_eq!(Limits::DEFAULT.wall_seconds(0), WALL_FLOOR_SECONDS);
        // Hugo's ~75 MiB package timed out at the old fixed 120 s on a loaded box.
        assert_eq!(Limits::DEFAULT.wall_seconds(75 * mib), 60 + 75 * 3);
        assert_eq!(Limits::DEFAULT.wall_seconds(75 * mib + 1), 60 + 76 * 3);
        assert_eq!(Limits::DEFAULT.wall_seconds(Limits::DEFAULT.raw_bytes), 828);
        assert_eq!(
            Limits::MARKET_LARGE.wall_seconds(Limits::MARKET_LARGE.raw_bytes),
            1596
        );
        assert_eq!(
            Limits::OPERATOR_APPLIANCE.wall_seconds(Limits::OPERATOR_APPLIANCE.raw_bytes),
            1800
        );
        assert_eq!(Limits::DEFAULT.wall_seconds(u64::MAX), 900);
        let large: ImportProfile = "market-large-v1".parse().unwrap();
        assert_eq!(large.as_str(), "market-large-v1");
        assert_eq!(large.limits().decoded_bytes, 2 * 1024 * mib);
        assert_eq!(
            large.limits().decoder_memory_bytes,
            Limits::DEFAULT.decoder_memory_bytes
        );
        assert_eq!(Limits::DEFAULT.capnp_segments, 512);
        assert_eq!(large.limits().capnp_segments, MAX_SEGMENTS);
        assert!("market-large".parse::<ImportProfile>().is_err());
    }

    #[test]
    fn raw_decoded_and_decoder_memory_limits_are_independent() {
        let bytes = fixture(Member::regular("data", vec![0; 128 * 1024]));
        assert!(unpack(
            &bytes,
            Limits {
                raw_bytes: 10,
                ..Limits::DEFAULT
            }
        )
        .is_err());
        assert!(unpack(
            &bytes,
            Limits {
                decoded_bytes: 4096,
                ..Limits::DEFAULT
            }
        )
        .is_err());
        assert!(unpack(
            &bytes,
            Limits {
                decoder_memory_bytes: 1024,
                ..Limits::DEFAULT
            }
        )
        .is_err());
        assert!(unpack(&bytes, Limits::DEFAULT).is_ok());
    }
    #[test]
    fn corrupt_truncated_extra_and_validly_compressed_tampering_fail() {
        let bytes = fixture(Member::regular("data", b"untampered".to_vec()));
        for size in [0, 8, bytes.len() / 2, bytes.len() - 1] {
            assert!(unpack(&bytes[..size], Limits::DEFAULT).is_err());
        }
        let mut extra = bytes.clone();
        extra.extend_from_slice(b"trailing");
        assert!(unpack(&extra, Limits::DEFAULT).is_err());
        let mut plain = Vec::new();
        xz2::read::XzDecoder::new(&bytes[8..])
            .read_to_end(&mut plain)
            .unwrap();
        let at = plain.windows(10).position(|w| w == b"untampered").unwrap();
        plain[at] ^= 1;
        let error = unpack(&compress(&plain), Limits::DEFAULT).err().unwrap();
        assert!(error.to_string().contains("archive hash mismatch"));
        let mut plain = Vec::new();
        xz2::read::XzDecoder::new(&bytes[8..])
            .read_to_end(&mut plain)
            .unwrap();
        // A changed signing key keeps archive bytes/hash intact but fails signature verification.
        let original = key().verifying_key().to_bytes();
        let at = plain.windows(32).position(|w| w == original).unwrap();
        plain[at..at + 32]
            .copy_from_slice(SigningKey::from_bytes(&[8; 32]).verifying_key().as_bytes());
        assert!(unpack(&compress(&plain), Limits::DEFAULT).is_err());
    }
    #[test]
    fn traversal_duplicates_mountpoints_and_symlink_escape_fail() {
        for name in ["../escape", "bad/name", ".", "..", "", "bad\0name", "var"] {
            assert!(
                unpack(&fixture(Member::regular(name, vec![])), Limits::DEFAULT).is_err(),
                "{name:?}"
            );
        }
        let duplicate = SpkBuilder::new()
            .manifest_json(MANIFEST)
            .file(Member::regular("sandstorm-manifest", vec![]))
            .pack(&key());
        assert!(unpack(&duplicate, Limits::DEFAULT).is_err());
        for target in ["../escape", "/../../escape", ""] {
            let link = Member {
                name: "link".into(),
                content: FileContent::Symlink(target.into()),
                mtime_ns: 0,
            };
            assert!(unpack(&fixture(link), Limits::DEFAULT).is_err());
        }
        let link = Member {
            name: "link".into(),
            content: FileContent::Symlink("/lib/inside".into()),
            mtime_ns: 0,
        };
        assert!(unpack(&fixture(link), Limits::DEFAULT).is_ok());
    }
    #[test]
    fn signed_public_data_member_is_bounded_and_retained_from_verified_archive() {
        let declaration = br#"{"schema":"minidregg-public-data-v1","inventory_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}"#;
        let first = fixture(Member::regular("minidregg-data.json", declaration.to_vec()));
        let parsed = unpack(&first, Limits::DEFAULT).unwrap();
        assert_eq!(
            parsed.data_config_bytes.as_deref(),
            Some(declaration.as_slice())
        );
        let mut changed = declaration.to_vec();
        let last = changed.len() - 3;
        changed[last] = b'b';
        let second = unpack(
            &fixture(Member::regular("minidregg-data.json", changed)),
            Limits::DEFAULT,
        )
        .unwrap();
        assert_ne!(parsed.raw_sha256, second.raw_sha256);
        for bytes in [Vec::new(), vec![b'x'; 4097]] {
            assert!(unpack(
                &fixture(Member::regular("minidregg-data.json", bytes)),
                Limits::DEFAULT
            )
            .is_err());
        }
        let link = Member {
            name: "minidregg-data.json".into(),
            content: FileContent::Symlink("inside".into()),
            mtime_ns: 0,
        };
        assert!(unpack(&fixture(link), Limits::DEFAULT).is_err());
        assert!(unpack(
            &fixture(Member::regular("ordinary", b"payload".to_vec())),
            Limits::DEFAULT
        )
        .unwrap()
        .data_config_bytes
        .is_none());
    }

    #[test]
    fn sparse_large_input_is_rejected_before_allocation_or_spooling() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("large.spk");
        File::create(&path)
            .unwrap()
            .set_len(Limits::OPERATOR_APPLIANCE.raw_bytes + 1)
            .unwrap();
        assert!(verify(&path, dir.path(), Limits::DEFAULT).is_err());
        assert!(verify(&path, dir.path(), Limits::OPERATOR_APPLIANCE).is_err());
        assert_eq!(std::fs::read_dir(dir.path()).unwrap().count(), 1);
    }
    #[test]
    fn segmented_capnp_archive_and_exact_bridge_config_are_supported() {
        use capnp::message::{AllocationStrategy, Builder, HeapAllocator};
        let mut message = Builder::new(
            HeapAllocator::new()
                .first_segment_words(2)
                .allocation_strategy(AllocationStrategy::FixedSize),
        );
        {
            let archive = message.init_root::<archive_capnp::archive::Builder>();
            let mut files = archive.init_files(4);
            let mut manifest = files.reborrow().get(0);
            manifest.set_name("sandstorm-manifest");
            manifest.set_regular(MANIFEST.as_bytes());
            let mut config = files.reborrow().get(1);
            config.set_name("sandstorm-http-bridge-config");
            config.set_regular(b"exact config bytes");
            let mut data = files.reborrow().get(2);
            data.set_name("data");
            data.set_regular(&[42; 4096]);
            let mut empty = files.reborrow().get(3);
            empty.set_name("empty");
            empty.set_regular(&[]);
        }
        let archive = capnp::serialize::write_message_to_words(&message);
        assert!(u32::from_le_bytes(archive[..4].try_into().unwrap()) > 0);
        let bytes = sign(&archive);
        let parsed = unpack(&bytes, Limits::DEFAULT).unwrap();
        assert_eq!(
            parsed.bridge_config_bytes.as_deref(),
            Some(&b"exact config bytes"[..])
        );
        assert_eq!(parsed.entries()[2].len(), 4096);
        let mut empty = Vec::new();
        parsed.copy_member(3, &mut empty).unwrap();
        assert!(empty.is_empty());
    }

    #[test]
    fn segment_bound_comes_from_the_profile_and_refuses_one_past_by_name() {
        // The IPython class-L package decodes to a 583-segment archive message over
        // 667 MiB, past the library reader's fixed 512. Model the shape compactly: one
        // real archive message, its segment table rewritten to carry extra zero-length
        // segments, which carry no pointers, so member pointers are unaffected.
        let bytes = fixture(Member::regular("data", vec![42; 4096]));
        let mut plain = Vec::new();
        xz2::read::XzDecoder::new(&bytes[8..])
            .read_to_end(&mut plain)
            .unwrap();
        let start =
            frame_length(&plain, MAX_SIGNATURE as u64, Limits::DEFAULT.capnp_segments).unwrap();
        let archive = &plain[start..];
        let real = u32::from_le_bytes(archive[..4].try_into().unwrap()) + 1;
        assert_eq!(real, 1); // the fixture archive is single-segment
        let with_segments = |count: u32| {
            let mut message = Vec::with_capacity(archive.len() + 4 * count as usize);
            message.extend_from_slice(&(count - 1).to_le_bytes());
            message.extend_from_slice(&archive[4..8]);
            message.extend(std::iter::repeat(0u8).take(4 * (count - real) as usize));
            message.extend(
                std::iter::repeat(0u8)
                    .take((-(4i64 + 4 * i64::from(count))).rem_euclid(8) as usize),
            );
            message.extend_from_slice(&archive[8..]);
            message
        };
        // Exactly at the market-large bound decodes; one past is refused by name.
        let bound = Limits::MARKET_LARGE.capnp_segments;
        let parsed = unpack(&sign(&with_segments(bound)), Limits::MARKET_LARGE).unwrap();
        assert_eq!(parsed.entries()[1].len(), 4096);
        let error = unpack(&sign(&with_segments(bound + 1)), Limits::MARKET_LARGE)
            .err()
            .unwrap();
        assert!(
            error.to_string().contains("too many Cap'n Proto segments"),
            "{error}"
        );
        // The IPython shape: 583 segments is standard's refusal, market-large's admission.
        let error = unpack(&sign(&with_segments(583)), Limits::DEFAULT)
            .err()
            .unwrap();
        assert!(
            error.to_string().contains("too many Cap'n Proto segments"),
            "{error}"
        );
        assert!(unpack(&sign(&with_segments(583)), Limits::MARKET_LARGE).is_ok());
    }

    #[test]
    fn tree_depth_file_count_and_retained_path_budget_are_bounded() {
        let mut deep = Member::regular("leaf", vec![]);
        for _ in 0..66 {
            deep = Member {
                name: "d".into(),
                content: FileContent::Directory(vec![deep]),
                mtime_ns: 0,
            };
        }
        assert!(unpack(&fixture(deep), Limits::DEFAULT)
            .err()
            .unwrap()
            .to_string()
            .contains("depth"));
        let mut message = capnp::message::Builder::new_default();
        message
            .init_root::<archive_capnp::archive::Builder>()
            .init_files(MAX_FILES as u32 + 1);
        let bytes = sign(&capnp::serialize::write_message_to_words(&message));
        assert!(unpack(&bytes, Limits::DEFAULT)
            .err()
            .unwrap()
            .to_string()
            .contains("too many archive files"));
        let mut branch = Member {
            name: "d".into(),
            content: FileContent::Directory(
                (0..6000)
                    .map(|i| Member::regular(format!("f{i}"), vec![0]))
                    .collect(),
            ),
            mtime_ns: 0,
        };
        for _ in 0..12 {
            branch = Member {
                name: "x".repeat(250),
                content: FileContent::Directory(vec![branch]),
                mtime_ns: 0,
            };
        }
        let error = unpack(&fixture(branch), Limits::DEFAULT).err().unwrap();
        assert!(error.to_string().contains("names exceed bound"), "{error}");
    }

    #[test]
    fn aliased_data_cannot_amplify_extracted_size() {
        // Build one-segment wire, then point two members at the same large Data.
        let bytes = SpkBuilder::new()
            .manifest_json(MANIFEST)
            .file(Member::regular("one", vec![42; 64 * 1024]))
            .file(Member::regular("two", vec![]))
            .pack(&key());
        let mut plain = Vec::new();
        xz2::read::XzDecoder::new(&bytes[8..])
            .read_to_end(&mut plain)
            .unwrap();
        let start =
            frame_length(&plain, MAX_SIGNATURE as u64, Limits::DEFAULT.capnp_segments).unwrap();
        let mut archive = plain[start..].to_vec();
        assert_eq!(&archive[..4], &[0; 4]); // single segment, eight-byte table
        let word = |bytes: &[u8], i: usize| {
            u64::from_le_bytes(bytes[8 + i * 8..16 + i * 8].try_into().unwrap())
        };
        let target = |pointer: u64, at: usize| {
            ((at as i64) + 1 + (((pointer as u32) as i32) >> 2) as i64) as usize
        };
        let root = target(word(&archive, 0), 0);
        let tag = target(word(&archive, root), root);
        let layout = word(&archive, tag);
        let data_words = ((layout >> 32) & 0xffff) as usize;
        let stride = data_words + (layout >> 48) as usize;
        let one = tag + 1 + stride + data_words + 1;
        let two = tag + 1 + 2 * stride + data_words + 1;
        let source = word(&archive, one);
        let offset = (target(source, one) as i64 - two as i64 - 1) as i32;
        let replacement = (source & !0xffff_ffff) | u64::from(((offset as u32) << 2) | 1);
        archive[8 + two * 8..16 + two * 8].copy_from_slice(&replacement.to_le_bytes());
        let decoded_limit = archive.len() as u64 + start as u64;
        let err = unpack(
            &sign(&archive),
            Limits {
                decoded_bytes: decoded_limit,
                ..Limits::DEFAULT
            },
        )
        .err()
        .unwrap();
        assert!(
            err.to_string().contains("extracted bytes exceed bound"),
            "{err}"
        );
    }
}
