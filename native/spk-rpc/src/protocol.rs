use crate::{api_session_capnp, grain_capnp, identity_capnp, util_capnp, web_session_capnp};
use capnp::traits::HasTypeId;
use capnp_rpc::{rpc_twoparty_capnp, twoparty, RpcSystem};
use futures::AsyncReadExt;
use sha2::{Digest, Sha256};
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;
use tokio::net::UnixStream;
use tokio_util::compat::TokioAsyncReadCompatExt;

/// One identity capability a grain asked to keep (`BridgeConfig.saveIdentityCaps`):
/// the participant's identity as the custodian presented it, held by the grain
/// under a token the custody minted. It is a grant the member made by opening
/// the grain, recorded and revocable; it carries no permission of its own.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SavedIdentity {
    pub identity_id: [u8; 32],
    pub display_name: String,
    pub preferred_handle: String,
}

/// Why a token does not restore.
#[derive(Debug, PartialEq, Eq)]
pub enum CustodyRefusal {
    UnknownToken,
    IdentityRevoked,
    Io(String),
}

impl CustodyRefusal {
    pub fn name(&self) -> String {
        match self {
            Self::UnknownToken => "unknownToken".into(),
            Self::IdentityRevoked => "identityRevoked".into(),
            Self::Io(detail) => format!("custodyUnavailable: {detail}"),
        }
    }
}

/// Where the grain's saved identities live across app generations. The
/// supervisor transport calls it from its single-threaded RPC task.
pub trait IdentityCustody {
    /// Mint a fresh token for this identity and retain the record.
    fn save(&self, identity: &SavedIdentity) -> Result<Vec<u8>, CustodyRefusal>;
    /// The record a token names, unless revoked or unknown.
    fn restore(&self, token: &[u8]) -> Result<SavedIdentity, CustodyRefusal>;
    /// The grain (or the member) let the identity go: the token never restores again.
    fn release(&self, token: &[u8]) -> Result<(), CustodyRefusal>;
}

/// Tokens that live as long as the connection: tests and the audit harness.
#[derive(Default)]
pub struct MemoryIdentityCustody {
    records: RefCell<HashMap<Vec<u8>, (SavedIdentity, bool)>>,
}

impl IdentityCustody for MemoryIdentityCustody {
    fn save(&self, identity: &SavedIdentity) -> Result<Vec<u8>, CustodyRefusal> {
        let token = random_bytes().map_err(|e| CustodyRefusal::Io(e.to_string()))?.to_vec();
        self.records.borrow_mut().insert(token.clone(), (identity.clone(), false));
        Ok(token)
    }
    fn restore(&self, token: &[u8]) -> Result<SavedIdentity, CustodyRefusal> {
        match self.records.borrow().get(token) {
            None => Err(CustodyRefusal::UnknownToken),
            Some((_, true)) => Err(CustodyRefusal::IdentityRevoked),
            Some((identity, false)) => Ok(identity.clone()),
        }
    }
    fn release(&self, token: &[u8]) -> Result<(), CustodyRefusal> {
        match self.records.borrow_mut().get_mut(token) {
            None => Err(CustodyRefusal::UnknownToken),
            Some(entry) => {
                entry.1 = true;
                Ok(())
            }
        }
    }
}

pub(crate) fn random_bytes() -> std::io::Result<[u8; 32]> {
    use std::io::Read;
    let mut bytes = [0_u8; 32];
    std::fs::File::open("/dev/urandom")?.read_exact(&mut bytes)?;
    Ok(bytes)
}

/// The identity object's self-description, as `AppPersistent.save` returns it.
/// The tag binds it to this connection's secret and this identity, so an app
/// cannot hand `SandstormApi.save` a forged identity object: it would need the
/// tag for an identity it never received.
const IDENTITY_OBJECT_MAGIC: &[u8] = b"mini-identity-object-v1";

fn identity_tag(secret: &[u8; 32], identity_id: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(IDENTITY_OBJECT_MAGIC);
    hasher.update(secret);
    hasher.update(identity_id);
    hasher.finalize().into()
}

fn encode_identity_object(identity: &SavedIdentity, tag: &[u8; 32]) -> Vec<u8> {
    let mut out = IDENTITY_OBJECT_MAGIC.to_vec();
    out.extend_from_slice(&identity.identity_id);
    out.extend_from_slice(tag);
    for text in [&identity.display_name, &identity.preferred_handle] {
        let len = u16::try_from(text.len()).unwrap_or(u16::MAX);
        out.extend_from_slice(&len.to_le_bytes());
        out.extend_from_slice(&text.as_bytes()[..len as usize]);
    }
    out
}

fn decode_identity_object(bytes: &[u8], secret: &[u8; 32]) -> Result<SavedIdentity, &'static str> {
    let rest = bytes
        .strip_prefix(IDENTITY_OBJECT_MAGIC)
        .ok_or("unsupportedPersistentCap: only identity capabilities are saved")?;
    if rest.len() < 64 + 4 || rest.len() > 64 + 4 + 1024 + 256 {
        return Err("identityObjectRefused: shape");
    }
    let mut identity_id = [0_u8; 32];
    identity_id.copy_from_slice(&rest[..32]);
    if rest[32..64] != identity_tag(secret, &identity_id) {
        return Err("identityTagRefused: the object was not minted by this connection");
    }
    let mut cursor = &rest[64..];
    let mut texts = Vec::with_capacity(2);
    for bound in [1024_usize, 256] {
        if cursor.len() < 2 {
            return Err("identityObjectRefused: shape");
        }
        let len = u16::from_le_bytes([cursor[0], cursor[1]]) as usize;
        cursor = &cursor[2..];
        if len > bound || cursor.len() < len {
            return Err("identityObjectRefused: shape");
        }
        texts.push(std::str::from_utf8(&cursor[..len]).map_err(|_| "identityObjectRefused: text")?.to_owned());
        cursor = &cursor[len..];
    }
    if !cursor.is_empty() {
        return Err("identityObjectRefused: shape");
    }
    Ok(SavedIdentity { identity_id, display_name: texts[0].clone(), preferred_handle: texts[1].clone() })
}

/// Values placed on Sandstorm's wire after the Mini controller has admitted
/// this exact request. These values carry no authorization proof themselves.
#[derive(Clone, Debug)]
pub struct SessionParameters {
    pub identity_id: [u8; 32],
    pub display_name: String,
    pub preferred_handle: String,
    pub permissions: Vec<bool>,
    pub tab_id: Vec<u8>,
    pub base_path: String,
    pub user_agent: String,
    pub acceptable_languages: Vec<String>,
}

#[derive(Debug, PartialEq, Eq)]
pub struct ViewInfo {
    pub app_title: String,
    /// Stable wire indexes are their positions in this vector.
    pub permissions: Vec<PermissionDefinition>,
    /// Stable wire role IDs are their positions in this vector.
    pub roles: Vec<RoleDefinition>,
    /// Proxy UiView attenuation metadata, not an authorization decision.
    pub denied_permissions: Vec<bool>,
    /// Compatibility summary; use `permissions` for complete metadata.
    pub permission_names: Vec<String>,
    /// Compatibility summary; use `roles` for definitions/default bits.
    pub role_count: u32,
}

#[derive(Debug, PartialEq, Eq)]
pub struct LocalizedText {
    pub default_text: String,
    pub localizations: Vec<(String, String)>,
}

#[derive(Debug, PartialEq, Eq)]
pub struct PermissionDefinition {
    pub name: String,
    pub title: LocalizedText,
    pub description: LocalizedText,
    pub obsolete: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub struct RoleDefinition {
    pub title: LocalizedText,
    pub verb_phrase: LocalizedText,
    pub description: LocalizedText,
    /// Raw PermissionSet bit list, whose wire length may differ from definitions.
    pub permissions: Vec<bool>,
    pub obsolete: bool,
    /// Legacy `RoleAssignment.none` may refer to a role with this flag.
    pub default: bool,
}

fn bounded_text(value: capnp::text::Reader<'_>, maximum: usize) -> capnp::Result<String> {
    let value = value.to_str()?;
    if value.len() > maximum {
        return Err(capnp::Error::failed("ViewInfo text exceeds bound".into()));
    }
    Ok(value.to_owned())
}

fn localized(value: util_capnp::localized_text::Reader<'_>) -> capnp::Result<LocalizedText> {
    let default_text = bounded_text(value.get_default_text()?, 4096)?;
    let entries = value.get_localizations()?;
    bounded_len(entries.len() as usize, 32, "localizations")?;
    let mut localizations = Vec::with_capacity(entries.len() as usize);
    for item in entries.iter() {
        localizations.push((
            bounded_text(item.get_locale()?, 128)?,
            bounded_text(item.get_text()?, 4096)?,
        ));
    }
    Ok(LocalizedText {
        default_text,
        localizations,
    })
}

#[derive(Debug, PartialEq, Eq)]
pub struct InlineResponse {
    pub status: u16,
    pub mime_type: String,
    pub body: Vec<u8>,
}

/// The `SandstormApi` this side exports. Three methods are served, all about
/// identity capabilities (`BridgeConfig.saveIdentityCaps`): `save` of an identity
/// object this connection minted, `restore` of a token the custody issued, and
/// `drop`. Every other method answers unimplemented by name: no powerbox, no
/// sharing, no scheduling, no app-object persistence (an app-object token is
/// `unknownToken` to `restore`), which is the bounded surface `expectAppHooks`
/// apps get: their hooks answer the bridge's `getViewInfo`, nothing more.
struct RecordingSandstormApi {
    custody: Rc<dyn IdentityCustody>,
    secret: [u8; 32],
}

fn refused(name: impl Into<String>) -> capnp::Error {
    capnp::Error::failed(name.into())
}

impl grain_capnp::sandstorm_api::Server<capnp::data::Owned> for RecordingSandstormApi {
    async fn save(
        self: capnp::capability::Rc<Self>,
        params: grain_capnp::sandstorm_api::SaveParams<capnp::data::Owned>,
        mut results: grain_capnp::sandstorm_api::SaveResults<capnp::data::Owned>,
    ) -> capnp::Result<()> {
        let cap: grain_capnp::app_persistent::Client<capnp::data::Owned> =
            params.get()?.get_cap().get_as_capability()?;
        // The documented flow: the supervisor asks the capability to describe
        // itself; only an identity object this connection minted passes the tag.
        let reply = cap.save_request().send().promise.await.map_err(|error| {
            refused(format!(
                "unsupportedPersistentCap: the capability does not describe itself as an identity ({error})"
            ))
        })?;
        let object = reply.get()?.get_object_id()?;
        let identity = decode_identity_object(object, &self.secret).map_err(refused)?;
        let token = self.custody.save(&identity).map_err(|e| refused(e.name()))?;
        results.get().set_token(&token);
        Ok(())
    }

    async fn restore(
        self: capnp::capability::Rc<Self>,
        params: grain_capnp::sandstorm_api::RestoreParams<capnp::data::Owned>,
        mut results: grain_capnp::sandstorm_api::RestoreResults<capnp::data::Owned>,
    ) -> capnp::Result<()> {
        let token = params.get()?.get_token()?;
        if token.len() != 32 {
            return Err(refused(CustodyRefusal::UnknownToken.name()));
        }
        let identity = self.custody.restore(token).map_err(|e| refused(e.name()))?;
        let client = identity_client(ProfileIdentity { identity, tag: None });
        results.get().init_cap().set_as_capability(client.client.hook);
        Ok(())
    }

    async fn drop(
        self: capnp::capability::Rc<Self>,
        params: grain_capnp::sandstorm_api::DropParams<capnp::data::Owned>,
        _: grain_capnp::sandstorm_api::DropResults<capnp::data::Owned>,
    ) -> capnp::Result<()> {
        let token = params.get()?.get_token()?;
        self.custody.release(token).map_err(|e| refused(e.name()))
    }
}

/// The session context an app receives. It answers as `HackSessionContext`
/// (which extends `SessionContext` and `EmailSendPort`), because bridge apps
/// cast `getSessionContext`'s result to it and call `getPublicId` on ordinary
/// page loads. The publishing origin is derived from the session's own origin
/// (`base_path`, `https://<grain>.<base>`): `https://<grain>-www.<base>`.
struct GrainSessionContext {
    base_path: String,
}

/// `(publicId, hostname, autoUrl)` for a session origin `https://LABEL.REST`.
pub fn publishing_origin(base_path: &str) -> Result<(String, String, String), &'static str> {
    let host = base_path.strip_prefix("https://").ok_or("publishingOriginUnavailable")?;
    let (label, rest) = host.split_once('.').ok_or("publishingOriginUnavailable")?;
    let valid = |s: &str| !s.is_empty() && s.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'.');
    if !valid(label) || label.contains('.') || !valid(rest) || rest.starts_with('.') || rest.ends_with('.') || rest.contains("..") {
        return Err("publishingOriginUnavailable");
    }
    let public_id = format!("{label}-www");
    let auto_url = format!("https://{public_id}.{rest}");
    Ok((public_id, rest.to_owned(), auto_url))
}

impl grain_capnp::session_context::Server for GrainSessionContext {}

impl crate::email_capnp::email_send_port::Server for GrainSessionContext {
    async fn send(
        self: capnp::capability::Rc<Self>,
        _: crate::email_capnp::email_send_port::SendParams,
        _: crate::email_capnp::email_send_port::SendResults,
    ) -> capnp::Result<()> {
        Err(refused("emailUnsupported"))
    }
    async fn hint_address(
        self: capnp::capability::Rc<Self>,
        _: crate::email_capnp::email_send_port::HintAddressParams,
        _: crate::email_capnp::email_send_port::HintAddressResults,
    ) -> capnp::Result<()> {
        Err(refused("emailUnsupported"))
    }
}

macro_rules! obsolete_hack_method {
    ($($name:ident: $params:ident, $results:ident;)*) => {$(
        async fn $name(
            self: capnp::capability::Rc<Self>,
            _: crate::hack_session_capnp::hack_session_context::$params,
            _: crate::hack_session_capnp::hack_session_context::$results,
        ) -> capnp::Result<()> {
            Err(refused(concat!("obsoleteHackMethod: ", stringify!($name))))
        }
    )*};
}

impl crate::hack_session_capnp::hack_session_context::Server for GrainSessionContext {
    async fn get_public_id(
        self: capnp::capability::Rc<Self>,
        _: crate::hack_session_capnp::hack_session_context::GetPublicIdParams,
        mut results: crate::hack_session_capnp::hack_session_context::GetPublicIdResults,
    ) -> capnp::Result<()> {
        let (public_id, hostname, auto_url) = publishing_origin(&self.base_path).map_err(refused)?;
        let mut out = results.get();
        out.set_public_id(public_id.as_str());
        out.set_hostname(hostname.as_str());
        out.set_auto_url(auto_url.as_str());
        out.set_is_demo_user(false);
        Ok(())
    }
    async fn get_user_address(
        self: capnp::capability::Rc<Self>,
        _: crate::hack_session_capnp::hack_session_context::GetUserAddressParams,
        _: crate::hack_session_capnp::hack_session_context::GetUserAddressResults,
    ) -> capnp::Result<()> {
        Err(refused("emailUnsupported"))
    }
    obsolete_hack_method! {
        obsolete_http_get: ObsoleteHttpGetParams, ObsoleteHttpGetResults;
        obsolete_get_ui_view_for_endpoint: ObsoleteGetUiViewForEndpointParams, ObsoleteGetUiViewForEndpointResults;
        obsolete_generate_api_token: ObsoleteGenerateApiTokenParams, ObsoleteGenerateApiTokenResults;
        obsolete_list_api_tokens: ObsoleteListApiTokensParams, ObsoleteListApiTokensResults;
        obsolete_revoke_api_token: ObsoleteRevokeApiTokenParams, ObsoleteRevokeApiTokenResults;
        obsolete_get_ip_network: ObsoleteGetIpNetworkParams, ObsoleteGetIpNetworkResults;
        obsolete_get_ip_interface: ObsoleteGetIpInterfaceParams, ObsoleteGetIpInterfaceResults;
    }
}

/// The participant's identity as presented to the app. A session's identity
/// carries the connection tag so `SandstormApi.save` can accept it; a restored
/// identity carries none (it is already held; saving it again is refused).
struct ProfileIdentity {
    identity: SavedIdentity,
    tag: Option<[u8; 32]>,
}
impl identity_capnp::identity::Server for ProfileIdentity {
    async fn get_profile(
        self: capnp::capability::Rc<Self>,
        _: identity_capnp::identity::GetProfileParams,
        mut results: identity_capnp::identity::GetProfileResults,
    ) -> capnp::Result<()> {
        let mut profile = results.get().init_profile();
        profile
            .reborrow()
            .init_display_name()
            .set_default_text(self.identity.display_name.as_str());
        profile.set_preferred_handle(self.identity.preferred_handle.as_str());
        Ok(())
    }
}
/// Sandstorm's identity objects answer both `Identity` and `AppPersistent`; a
/// generated client dispatches one interface, so this client routes by interface
/// id to the generated dispatchers of each. Exported through the public
/// `new_client` path (`FromServer`), never by poking at the transport.
struct DualIdentityClient {
    client: capnp::capability::Client,
}
impl capnp::capability::FromClientHook for DualIdentityClient {
    fn new(hook: Box<dyn capnp::private::capability::ClientHook>) -> Self {
        Self { client: capnp::capability::Client::new(hook) }
    }
    fn into_client_hook(self) -> Box<dyn capnp::private::capability::ClientHook> {
        self.client.hook
    }
    fn as_client_hook(&self) -> &dyn capnp::private::capability::ClientHook {
        &*self.client.hook
    }
}
#[derive(Clone)]
struct DualIdentityDispatch {
    server: capnp::capability::Rc<ProfileIdentity>,
}
impl std::ops::Deref for DualIdentityDispatch {
    type Target = ProfileIdentity;
    fn deref(&self) -> &ProfileIdentity {
        &self.server
    }
}
impl capnp::capability::Server for DualIdentityDispatch {
    fn dispatch_call(
        self,
        interface_id: u64,
        method_id: u16,
        params: capnp::capability::Params<capnp::any_pointer::Owned>,
        results: capnp::capability::Results<capnp::any_pointer::Owned>,
    ) -> capnp::capability::DispatchCallResult {
        if interface_id == <identity_capnp::identity::Client as HasTypeId>::TYPE_ID {
            identity_capnp::identity::ServerDispatch::<ProfileIdentity>::dispatch_call_internal(
                self.server, method_id, params, results,
            )
        } else if interface_id
            == <grain_capnp::app_persistent::Client<capnp::data::Owned> as HasTypeId>::TYPE_ID
        {
            grain_capnp::app_persistent::ServerDispatch::<ProfileIdentity, capnp::data::Owned>::dispatch_call_internal(
                self.server, method_id, params, results,
            )
        } else {
            capnp::capability::DispatchCallResult::new(
                capnp::capability::Promise::err(capnp::Error::unimplemented(
                    "identity object answers Identity and AppPersistent only".into(),
                )),
                false,
            )
        }
    }
    fn as_ptr(&self) -> usize {
        capnp::capability::Rc::as_ptr(&self.server) as usize
    }
}
impl capnp::capability::FromServer<ProfileIdentity> for DualIdentityClient {
    type Dispatch = DualIdentityDispatch;
    fn from_server(s: capnp::capability::Rc<ProfileIdentity>) -> DualIdentityDispatch {
        DualIdentityDispatch { server: s }
    }
}
fn identity_client(identity: ProfileIdentity) -> identity_capnp::identity::Client {
    let dual: DualIdentityClient = capnp_rpc::new_client(identity);
    identity_capnp::identity::Client { client: dual.client }
}

impl grain_capnp::app_persistent::Server<capnp::data::Owned> for ProfileIdentity {
    async fn save(
        self: capnp::capability::Rc<Self>,
        _: grain_capnp::app_persistent::SaveParams<capnp::data::Owned>,
        mut results: grain_capnp::app_persistent::SaveResults<capnp::data::Owned>,
    ) -> capnp::Result<()> {
        let Some(tag) = &self.tag else {
            return Err(refused("identityAlreadyHeld: a restored identity is not saved again"));
        };
        let mut out = results.get();
        out.set_object_id(&encode_identity_object(&self.identity, tag)[..])?;
        out.init_label().set_default_text(self.identity.display_name.as_str());
        Ok(())
    }
}

struct RejectingResponseStream;
impl crate::util_capnp::byte_stream::Server for RejectingResponseStream {}

fn reader_options() -> capnp::message::ReaderOptions {
    capnp::message::ReaderOptions {
        traversal_limit_in_words: Some(2 * 1024 * 1024), // 16 MiB traversal ceiling
        nesting_limit: 64,
    }
}

fn bounded_len(value: usize, maximum: usize, field: &str) -> capnp::Result<u32> {
    if value > maximum {
        return Err(capnp::Error::failed(format!(
            "{field} exceeds SPK RPC transport bound"
        )));
    }
    u32::try_from(value).map_err(|_| capnp::Error::failed(format!("{field} is too large")))
}

pub(crate) fn decode_view_info(
    info: grain_capnp::ui_view::view_info::Reader<'_>,
) -> capnp::Result<ViewInfo> {
    let app_title = bounded_text(info.get_app_title()?.get_default_text()?, 4096)?;
    let raw_permissions = info.get_permissions()?;
    let raw_roles = info.get_roles()?;
    bounded_len(
        raw_permissions.len() as usize,
        4096,
        "permission definitions",
    )?;
    bounded_len(raw_roles.len() as usize, 4096, "role definitions")?;
    let mut names = std::collections::HashSet::new();
    let mut permissions = Vec::with_capacity(raw_permissions.len() as usize);
    for item in raw_permissions.iter() {
        let name = bounded_text(item.get_name()?, 256)?;
        if !name.starts_with(|c: char| c.is_ascii_alphabetic())
            || !name.chars().all(|c| c.is_ascii_alphanumeric())
            || !names.insert(name.clone())
        {
            return Err(capnp::Error::failed(
                "invalid or duplicate permission name".into(),
            ));
        }
        permissions.push(PermissionDefinition {
            name,
            title: localized(item.get_title()?)?,
            description: localized(item.get_description()?)?,
            obsolete: item.get_obsolete(),
        });
    }
    let mut roles = Vec::with_capacity(raw_roles.len() as usize);
    let mut defaults = 0;
    for item in raw_roles.iter() {
        let bits = item.get_permissions()?;
        bounded_len(bits.len() as usize, 4096, "role permission bits")?;
        let default = item.get_default();
        if default {
            defaults += 1;
        }
        roles.push(RoleDefinition {
            title: localized(item.get_title()?)?,
            verb_phrase: localized(item.get_verb_phrase()?)?,
            description: localized(item.get_description()?)?,
            permissions: bits.iter().collect(),
            obsolete: item.get_obsolete(),
            default,
        });
    }
    if defaults > 1 {
        return Err(capnp::Error::failed(
            "multiple default roles are ambiguous".into(),
        ));
    }
    let denied = info.get_denied_permissions()?;
    bounded_len(denied.len() as usize, 4096, "denied permission bits")?;
    let permission_names = permissions.iter().map(|p| p.name.clone()).collect();
    Ok(ViewInfo {
        app_title,
        permissions,
        roles,
        denied_permissions: denied.iter().collect(),
        permission_names,
        role_count: raw_roles.len(),
    })
}

/// The supervisor side of one already-connected Sandstorm fd3 socketpair.
///
/// The caller must drive the returned RPC system on a Tokio LocalSet for as
/// long as the app is alive. The app's fd3 end runs as the two-party CLIENT;
/// this side is SERVER, exports SandstormApi, and bootstraps its UiView.
pub struct SupervisorConnection {
    view: grain_capnp::ui_view::Client,
    /// Per-connection secret behind the identity objects' tags.
    secret: [u8; 32],
}

impl SupervisorConnection {
    /// Identity tokens live as long as this connection (tests, audits).
    pub fn from_connected_stream(
        stream: UnixStream,
    ) -> (Self, RpcSystem<rpc_twoparty_capnp::Side>) {
        Self::from_connected_stream_with_custody(stream, Rc::new(MemoryIdentityCustody::default()))
    }

    /// The production shape: the custody outlives the app generation.
    pub fn from_connected_stream_with_custody(
        stream: UnixStream,
        custody: Rc<dyn IdentityCustody>,
    ) -> (Self, RpcSystem<rpc_twoparty_capnp::Side>) {
        let (reader, writer) = stream.compat().split();
        let network = twoparty::VatNetwork::new(
            futures::io::BufReader::new(reader),
            futures::io::BufWriter::new(writer),
            rpc_twoparty_capnp::Side::Server,
            reader_options(),
        );
        // /dev/urandom failing is a broken host; the tag then binds to nothing
        // the app can predict either, and save() refuses because no tag matches.
        let secret = random_bytes().unwrap_or([0; 32]);
        let api: grain_capnp::sandstorm_api::Client<capnp::data::Owned> =
            capnp_rpc::new_client(RecordingSandstormApi { custody, secret });
        let mut rpc = RpcSystem::new(Box::new(network), Some(api.client));
        let view = rpc.bootstrap(rpc_twoparty_capnp::Side::Client);
        (Self { view, secret }, rpc)
    }

    pub async fn get_view_info(&self) -> capnp::Result<ViewInfo> {
        let reply = self.view.get_view_info_request().send().promise.await?;
        decode_view_info(reply.get()?)
    }

    pub async fn new_web_session(
        &self,
        params: &SessionParameters,
    ) -> capnp::Result<web_session_capnp::web_session::Client> {
        self.new_session(params, false).await
    }

    pub async fn new_api_session(
        &self,
        params: &SessionParameters,
    ) -> capnp::Result<web_session_capnp::web_session::Client> {
        self.new_session(params, true).await
    }

    async fn new_session(
        &self,
        params: &SessionParameters,
        api: bool,
    ) -> capnp::Result<web_session_capnp::web_session::Client> {
        let permission_count = bounded_len(params.permissions.len(), 4096, "permissions")?;
        let language_count = bounded_len(params.acceptable_languages.len(), 32, "languages")?;
        bounded_len(params.display_name.len(), 1024, "display name")?;
        bounded_len(params.preferred_handle.len(), 256, "preferred handle")?;
        bounded_len(params.tab_id.len(), 256, "tab ID")?;
        bounded_len(params.base_path.len(), 8192, "base path")?;
        bounded_len(params.user_agent.len(), 4096, "user agent")?;
        for language in &params.acceptable_languages {
            bounded_len(language.len(), 256, "language")?;
        }
        let mut request = self.view.new_session_request();
        {
            let mut body = request.get();
            let mut user = body.reborrow().init_user_info();
            user.reborrow()
                .init_display_name()
                .set_default_text(params.display_name.as_str());
            user.set_preferred_handle(params.preferred_handle.as_str());
            user.set_identity_id(&params.identity_id);
            let identity = identity_client(ProfileIdentity {
                    identity: SavedIdentity {
                        identity_id: params.identity_id,
                        display_name: params.display_name.clone(),
                        preferred_handle: params.preferred_handle.clone(),
                    },
                    tag: Some(identity_tag(&self.secret, &params.identity_id)),
                });
            user.set_identity(identity);
            let mut permissions = user.init_permissions(permission_count);
            for (index, allowed) in params.permissions.iter().enumerate() {
                permissions.set(index as u32, *allowed);
            }
            let hack: crate::hack_session_capnp::hack_session_context::Client =
                capnp_rpc::new_client(GrainSessionContext { base_path: params.base_path.clone() });
            let context = grain_capnp::session_context::Client { client: hack.client };
            body.set_context(context);
            body.set_tab_id(&params.tab_id);
            if api {
                body.set_session_type(api_session_capnp::api_session::Client::TYPE_ID);
                let _: api_session_capnp::api_session::params::Builder<'_> =
                    body.init_session_params().init_as();
            } else {
                body.set_session_type(web_session_capnp::web_session::Client::TYPE_ID);
                let mut web: web_session_capnp::web_session::params::Builder<'_> =
                    body.init_session_params().init_as();
                web.set_base_path(params.base_path.as_str());
                web.set_user_agent(params.user_agent.as_str());
                let mut languages = web.init_acceptable_languages(language_count);
                for (index, language) in params.acceptable_languages.iter().enumerate() {
                    languages.set(index as u32, language.as_str());
                }
            }
        }
        let reply = request.send().promise.await?;
        let session = reply.get()?.get_session()?;
        Ok(web_session_capnp::web_session::Client {
            client: session.client,
        })
    }

    /// A first typed WebSession operation. Streaming responses fail closed until
    /// the application body-stream adapter is connected to durable dispatch.
    pub async fn get_inline(
        session: &web_session_capnp::web_session::Client,
        path: &str,
        max_body_bytes: usize,
    ) -> capnp::Result<InlineResponse> {
        use web_session_capnp::web_session::response::{self, content};
        bounded_len(path.len(), 8192, "request path")?;
        let mut request = session.get_request();
        {
            let mut body = request.get();
            body.set_path(path);
            body.set_ignore_body(false);
            let mut context = body.init_context();
            let stream: crate::util_capnp::byte_stream::Client =
                capnp_rpc::new_client(RejectingResponseStream);
            context.set_response_stream(stream);
        }
        let reply = request.send().promise.await?;
        match reply
            .get()?
            .which()
            .map_err(|e| capnp::Error::failed(e.to_string()))?
        {
            response::Which::Content(value) => {
                let status = match value
                    .get_status_code()
                    .map_err(|e| capnp::Error::failed(e.to_string()))?
                {
                    response::SuccessCode::Ok => 200,
                    response::SuccessCode::Created => 201,
                    response::SuccessCode::Accepted => 202,
                    response::SuccessCode::NoContent => 204,
                    response::SuccessCode::PartialContent => 206,
                    response::SuccessCode::MultiStatus => 207,
                    response::SuccessCode::NotModified => 304,
                };
                let mime_type = value.get_mime_type()?.to_str()?.to_owned();
                let body = match value
                    .get_body()
                    .which()
                    .map_err(|e| capnp::Error::failed(e.to_string()))?
                {
                    content::body::Which::Bytes(bytes) => bytes?.to_vec(),
                    content::body::Which::Stream(_) => {
                        return Err(capnp::Error::unimplemented(
                            "streaming response body is not connected".into(),
                        ))
                    }
                };
                if body.len() > max_body_bytes {
                    return Err(capnp::Error::failed(
                        "app response exceeds caller bound".into(),
                    ));
                }
                Ok(InlineResponse {
                    status,
                    mime_type,
                    body,
                })
            }
            _ => Err(capnp::Error::unimplemented(
                "response variant is not mapped".into(),
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use capnp_rpc::rpc_twoparty_capnp::Side;
    use std::{cell::RefCell, rc::Rc};

    #[derive(Default)]
    struct Observed {
        identity_id: Vec<u8>,
        permissions: Vec<bool>,
        session_type: u64,
        base_path: String,
        api_sessions: u32,
        identity_profile: String,
        identity: Option<identity_capnp::identity::Client>,
        paths: Vec<String>,
        posts: Vec<(String, Vec<u8>, String, String)>,
        view_fault: u8,
        /// What a bridge app learns by casting its session context to `HackSessionContext`.
        public_id: Vec<String>,
        user_address: String,
    }

    struct FakeApp(Rc<RefCell<Observed>>);
    impl grain_capnp::ui_view::Server for FakeApp {
        async fn get_view_info(
            self: capnp::capability::Rc<Self>,
            _: grain_capnp::ui_view::GetViewInfoParams,
            mut results: grain_capnp::ui_view::GetViewInfoResults,
        ) -> capnp::Result<()> {
            let mut info = results.get();
            info.reborrow()
                .init_app_title()
                .set_default_text("Actual app");
            let mut permissions = info.reborrow().init_permissions(2);
            let mut read = permissions.reborrow().get(0);
            read.set_name("read");
            read.reborrow().init_title().set_default_text("Read");
            read.reborrow()
                .init_description()
                .set_default_text("See tasks");
            let mut edit = permissions.reborrow().get(1);
            edit.set_name(if self.0.borrow().view_fault == 1 {
                "read"
            } else {
                "edit"
            });
            edit.set_obsolete(true);
            let mut title = edit.reborrow().init_title();
            title.set_default_text("Edit");
            let mut localized = title.init_localizations(1);
            localized.reborrow().get(0).set_locale("fr");
            localized.get(0).set_text("Modifier");
            edit.init_description().set_default_text("Change tasks");
            let mut roles = info.reborrow().init_roles(2);
            let mut viewer = roles.reborrow().get(0);
            viewer.reborrow().init_title().set_default_text("Viewer");
            viewer
                .reborrow()
                .init_verb_phrase()
                .set_default_text("can view");
            viewer
                .reborrow()
                .init_description()
                .set_default_text("Read only");
            viewer.set_default(true);
            viewer.init_permissions(2).set(0, true);
            let mut editor = roles.get(1);
            editor.reborrow().init_title().set_default_text("Editor");
            editor
                .reborrow()
                .init_verb_phrase()
                .set_default_text("can edit");
            editor
                .reborrow()
                .init_description()
                .set_default_text("Full task editing");
            editor.set_obsolete(true);
            if self.0.borrow().view_fault == 2 {
                editor.set_default(true);
            }
            let mut bits = editor.init_permissions(2);
            bits.set(0, true);
            bits.set(1, true);
            info.init_denied_permissions(2).set(1, true);
            Ok(())
        }

        async fn new_session(
            self: capnp::capability::Rc<Self>,
            params: grain_capnp::ui_view::NewSessionParams,
            mut results: grain_capnp::ui_view::NewSessionResults,
        ) -> capnp::Result<()> {
            let params = params.get()?;
            let user = params.get_user_info()?;
            let profile_reply = user
                .get_identity()?
                .get_profile_request()
                .send()
                .promise
                .await?;
            let profile_name = profile_reply
                .get()?
                .get_profile()?
                .get_display_name()?
                .get_default_text()?
                .to_str()?
                .to_owned();
            {
                let mut seen = self.0.borrow_mut();
                seen.identity_id = user.get_identity_id()?.to_vec();
                seen.permissions = user.get_permissions()?.iter().collect();
                seen.session_type = params.get_session_type();
                seen.identity_profile = profile_name;
                seen.identity = Some(user.get_identity()?);
                if seen.session_type == api_session_capnp::api_session::Client::TYPE_ID {
                    let _: api_session_capnp::api_session::params::Reader<'_> =
                        params.get_session_params().get_as()?;
                    seen.api_sessions += 1;
                } else {
                    let web: web_session_capnp::web_session::params::Reader<'_> =
                        params.get_session_params().get_as()?;
                    seen.base_path = web.get_base_path()?.to_str()?.to_owned();
                }
            }
            // As Hacker Slides' index does: cast the context, ask for the publishing origin.
            let hack = crate::hack_session_capnp::hack_session_context::Client {
                client: params.get_context()?.client,
            };
            let public = hack.get_public_id_request().send().promise.await;
            let address = hack.get_user_address_request().send().promise.await;
            {
                let mut seen = self.0.borrow_mut();
                seen.public_id = match public {
                    Ok(reply) => {
                        let r = reply.get()?;
                        vec![
                            r.get_public_id()?.to_str()?.to_owned(),
                            r.get_hostname()?.to_str()?.to_owned(),
                            r.get_auto_url()?.to_str()?.to_owned(),
                            r.get_is_demo_user().to_string(),
                        ]
                    }
                    Err(error) => vec![format!("refused {error}")],
                };
                seen.user_address = match address {
                    Ok(_) => "served".into(),
                    Err(error) => error.to_string(),
                };
            }
            let web: web_session_capnp::web_session::Client =
                capnp_rpc::new_client(FakeWebSession(self.0.clone()));
            results
                .get()
                .set_session(grain_capnp::ui_session::Client { client: web.client });
            Ok(())
        }
    }
    impl grain_capnp::main_view::Server<capnp::data::Owned> for FakeApp {}

    struct FakeWebSession(Rc<RefCell<Observed>>);
    impl grain_capnp::ui_session::Server for FakeWebSession {}
    impl web_session_capnp::web_session::Server for FakeWebSession {
        async fn get(
            self: capnp::capability::Rc<Self>,
            params: web_session_capnp::web_session::GetParams,
            mut results: web_session_capnp::web_session::GetResults,
        ) -> capnp::Result<()> {
            let path = params.get()?.get_path()?.to_str()?.to_owned();
            if path == "stream" || path == "overflow" {
                let sink = params.get()?.get_context()?.get_response_stream()?;
                let bytes: &'static [u8] = if path == "overflow" {
                    b"too many bytes"
                } else {
                    b"streamed body"
                };
                tokio::task::spawn_local(async move {
                    let mut write = sink.write_request();
                    write.get().set_data(bytes);
                    write.send().await.unwrap();
                    let _ = sink.done_request().send().promise.await;
                });
                let mut content = results.get().init_content();
                content.set_status_code(web_session_capnp::web_session::response::SuccessCode::Ok);
                content.set_mime_type("text/plain");
                let handle: crate::util_capnp::handle::Client = capnp_rpc::new_client(FakeHandle);
                content.init_body().set_stream(handle);
                return Ok(());
            }
            self.0.borrow_mut().paths.push(path);
            let mut content = results.get().init_content();
            content.set_status_code(web_session_capnp::web_session::response::SuccessCode::Ok);
            content.set_mime_type("text/plain");
            content.init_body().set_bytes(b"from packaged app");
            Ok(())
        }

        async fn post(
            self: capnp::capability::Rc<Self>,
            params: web_session_capnp::web_session::PostParams,
            mut results: web_session_capnp::web_session::PostResults,
        ) -> capnp::Result<()> {
            let params = params.get()?;
            let context = params.get_context()?;
            let cookie = context.get_cookies()?.get(0);
            let header = context.get_additional_headers()?.get(0);
            let content = params.get_content()?;
            self.0.borrow_mut().posts.push((
                params.get_path()?.to_str()?.to_owned(),
                content.get_content()?.to_vec(),
                format!(
                    "{}={}",
                    cookie.get_key()?.to_str()?,
                    cookie.get_value()?.to_str()?
                ),
                format!(
                    "{}={}",
                    header.get_name()?.to_str()?,
                    header.get_value()?.to_str()?
                ),
            ));
            let mut response = results.get();
            let mut headers = response.reborrow().init_additional_headers(1);
            headers.reborrow().get(0).set_name("x-sandstorm-app-test");
            headers.get(0).set_value("kept");
            let mut content = response.init_content();
            content.set_status_code(web_session_capnp::web_session::response::SuccessCode::Created);
            content.set_mime_type("application/json");
            content.init_body().set_bytes(br#"{"ok":true}"#);
            Ok(())
        }

        async fn open_web_socket(
            self: capnp::capability::Rc<Self>,
            params: web_session_capnp::web_session::OpenWebSocketParams,
            mut results: web_session_capnp::web_session::OpenWebSocketResults,
        ) -> capnp::Result<()> {
            let params = params.get()?;
            self.0
                .borrow_mut()
                .paths
                .push(format!("ws:{}", params.get_path()?.to_str()?));
            let offered = params.get_protocol()?;
            let client = params.get_client_stream()?;
            let mut reply = results.get();
            if offered.iter().any(|p| p.ok().and_then(|p| p.to_str().ok()) == Some("chat")) {
                reply.reborrow().init_protocol(1).set(0, "chat");
            }
            let server: web_session_capnp::web_session::web_socket_stream::Client =
                capnp_rpc::new_client(EchoStream(client));
            reply.set_server_stream(server);
            Ok(())
        }

        async fn delete(
            self: capnp::capability::Rc<Self>,
            _: web_session_capnp::web_session::DeleteParams,
            mut results: web_session_capnp::web_session::DeleteResults,
        ) -> capnp::Result<()> {
            let mut err = results.get().init_client_error();
            err.set_status_code(
                web_session_capnp::web_session::response::ClientErrorCode::Forbidden,
            );
            err.set_description_html("<p>denied</p>");
            Ok(())
        }
        async fn propfind(
            self: capnp::capability::Rc<Self>,
            params: web_session_capnp::web_session::PropfindParams,
            mut results: web_session_capnp::web_session::PropfindResults,
        ) -> capnp::Result<()> {
            let p = params.get()?;
            let depth = match p.get_depth()? {
                web_session_capnp::web_session::PropfindDepth::Zero => "0",
                web_session_capnp::web_session::PropfindDepth::One => "1",
                web_session_capnp::web_session::PropfindDepth::Infinity => "infinity",
            };
            let echoed = format!("{}|{}|{}", p.get_path()?.to_str()?, depth, p.get_xml_content()?.to_str()?);
            let mut content = results.get().init_content();
            content.set_status_code(web_session_capnp::web_session::response::SuccessCode::MultiStatus);
            content.set_mime_type("application/xml");
            content.init_body().set_bytes(echoed.as_bytes());
            Ok(())
        }
        async fn move_(
            self: capnp::capability::Rc<Self>,
            params: web_session_capnp::web_session::MoveParams,
            mut results: web_session_capnp::web_session::MoveResults,
        ) -> capnp::Result<()> {
            let p = params.get()?;
            let echoed = format!("{}->{}|{}", p.get_path()?.to_str()?, p.get_destination()?.to_str()?, p.get_no_overwrite());
            let mut content = results.get().init_content();
            content.set_status_code(web_session_capnp::web_session::response::SuccessCode::Created);
            content.set_mime_type("text/plain");
            content.init_body().set_bytes(echoed.as_bytes());
            Ok(())
        }
        async fn options(
            self: capnp::capability::Rc<Self>,
            _: web_session_capnp::web_session::OptionsParams,
            mut results: web_session_capnp::web_session::OptionsResults,
        ) -> capnp::Result<()> {
            let mut o = results.get();
            o.set_dav_class1(true);
            o.set_dav_class2(true);
            o.reborrow().init_dav_extensions(1).set(0, "calendar-access");
            Ok(())
        }
    }

    struct FakeHandle;
    impl crate::util_capnp::handle::Server for FakeHandle {}

    /// The app's `serverStream`: echoes each client message back through the
    /// `clientStream` it was given, and releases that stream when dropped.
    struct EchoStream(web_session_capnp::web_session::web_socket_stream::Client);
    impl web_session_capnp::web_session::web_socket_stream::Server for EchoStream {
        async fn send_bytes(
            self: capnp::capability::Rc<Self>,
            params: web_session_capnp::web_session::web_socket_stream::SendBytesParams,
        ) -> capnp::Result<()> {
            let mut echoed = b"echo:".to_vec();
            echoed.extend_from_slice(params.get()?.get_message()?);
            let mut call = self.0.send_bytes_request();
            call.get().set_message(&echoed);
            call.send().await
        }
    }


    /// A forged identity object: the right shape, a tag this connection never minted.
    struct Forger;
    impl grain_capnp::app_persistent::Server<capnp::data::Owned> for Forger {
        async fn save(
            self: capnp::capability::Rc<Self>,
            _: grain_capnp::app_persistent::SaveParams<capnp::data::Owned>,
            mut results: grain_capnp::app_persistent::SaveResults<capnp::data::Owned>,
        ) -> capnp::Result<()> {
            let forged = encode_identity_object(
                &SavedIdentity { identity_id: [3; 32], display_name: "Mallory".into(), preferred_handle: "m".into() },
                &[0xAB; 32],
            );
            results.get().set_object_id(&forged[..])?;
            Ok(())
        }
    }

    async fn save_cap(
        api: &grain_capnp::sandstorm_api::Client<capnp::data::Owned>,
        hook: Box<dyn capnp::private::capability::ClientHook>,
    ) -> Result<Vec<u8>, String> {
        let mut request = api.save_request();
        request.get().init_cap().set_as_capability(hook);
        let reply = request.send().promise.await.map_err(|e| e.to_string())?;
        Ok(reply.get().map_err(|e| e.to_string())?.get_token().map_err(|e| e.to_string())?.to_vec())
    }

    fn failure<T>(result: Result<T, String>) -> String {
        match result {
            Ok(_) => panic!("expected a refusal"),
            Err(error) => error,
        }
    }

    async fn restore_name(
        api: &grain_capnp::sandstorm_api::Client<capnp::data::Owned>,
        token: &[u8],
    ) -> Result<(identity_capnp::identity::Client, String), String> {
        let mut request = api.restore_request();
        request.get().set_token(token);
        let reply = request.send().promise.await.map_err(|e| e.to_string())?;
        let cap: identity_capnp::identity::Client =
            reply.get().map_err(|e| e.to_string())?.get_cap().get_as_capability().map_err(|e| e.to_string())?;
        let profile = cap.get_profile_request().send().promise.await.map_err(|e| e.to_string())?;
        let name = profile.get().unwrap().get_profile().unwrap().get_display_name().unwrap().get_default_text().unwrap().to_str().unwrap().to_owned();
        Ok((cap, name))
    }

    #[tokio::test(flavor = "current_thread")]
    async fn identity_capabilities_are_saved_restored_and_revoked_by_name() {
        tokio::task::LocalSet::new()
            .run_until(async {
                let (host_fd, app_fd) = UnixStream::pair().unwrap();
                let observed = Rc::new(RefCell::new(Observed::default()));
                let main: grain_capnp::main_view::Client<capnp::data::Owned> =
                    capnp_rpc::new_client(FakeApp(observed.clone()));
                let (reader, writer) = app_fd.compat().split();
                let network = twoparty::VatNetwork::new(
                    futures::io::BufReader::new(reader),
                    futures::io::BufWriter::new(writer),
                    Side::Client,
                    reader_options(),
                );
                let mut app_rpc = RpcSystem::new(Box::new(network), Some(main.client.clone()));
                let api: grain_capnp::sandstorm_api::Client<capnp::data::Owned> =
                    app_rpc.bootstrap(Side::Server);
                let _app_task = tokio::task::spawn_local(app_rpc);
                let custody = Rc::new(MemoryIdentityCustody::default());
                let (host, host_rpc) =
                    SupervisorConnection::from_connected_stream_with_custody(host_fd, custody.clone());
                let _host_task = tokio::task::spawn_local(host_rpc);

                let params = SessionParameters {
                    identity_id: [7; 32],
                    display_name: "Ada".into(),
                    preferred_handle: "ada".into(),
                    permissions: vec![true],
                    tab_id: vec![1],
                    base_path: "https://a4501.demo.test".into(),
                    user_agent: "Mini test".into(),
                    acceptable_languages: vec![],
                };
                let _session = host.new_web_session(&params).await.unwrap();
                let identity = observed.borrow().identity.clone().unwrap();

                // The bridge saves the identity it was given: a 32-byte token, a record in custody.
                let token = save_cap(&api, identity.client.hook.add_ref()).await.unwrap();
                assert_eq!(token.len(), 32);
                assert_eq!(
                    custody.restore(&token).unwrap(),
                    SavedIdentity { identity_id: [7; 32], display_name: "Ada".into(), preferred_handle: "ada".into() }
                );
                // restore() gives back an identity with the same profile ...
                let (restored, name) = restore_name(&api, &token).await.unwrap();
                assert_eq!(name, "Ada");
                // ... which is already held: saving it again is refused by name.
                let again = failure(save_cap(&api, restored.client.hook.add_ref()).await);
                assert!(again.contains("identityAlreadyHeld"), "{again}");
                // A forged identity object and a non-identity capability are refused by name.
                let forger: grain_capnp::app_persistent::Client<capnp::data::Owned> = capnp_rpc::new_client(Forger);
                let forged = save_cap(&api, forger.client.hook).await.unwrap_err();
                assert!(forged.contains("identityTagRefused"), "{forged}");
                let other = save_cap(&api, main.client.hook.add_ref()).await.unwrap_err();
                assert!(other.contains("unsupportedPersistentCap"), "{other}");
                // Unknown and malformed tokens do not restore.
                assert!(failure(restore_name(&api, &[1; 32]).await).contains("unknownToken"));
                assert!(failure(restore_name(&api, b"short").await).contains("unknownToken"));
                // drop() revokes: the token never restores again, and says so.
                let mut drop_request = api.drop_request();
                drop_request.get().set_token(&token);
                drop_request.send().promise.await.unwrap();
                let revoked = failure(restore_name(&api, &token).await);
                assert!(revoked.contains("identityRevoked"), "{revoked}");
                assert_eq!(custody.restore(&token), Err(CustodyRefusal::IdentityRevoked));
                // Unimplemented methods stay unimplemented by name.
                let unimplemented = match api.share_view_request().send().promise.await {
                    Ok(_) => panic!("shareView must stay unimplemented"),
                    Err(error) => error.to_string(),
                };
                assert!(unimplemented.contains("not implemented"), "{unimplemented}");
            })
            .await;
    }

    #[test]
    fn publishing_origin_is_the_grain_label_with_www_and_refuses_odd_origins() {
        assert_eq!(
            super::publishing_origin("https://a42.demo.dregg.online").unwrap(),
            ("a42-www".into(), "demo.dregg.online".into(), "https://a42-www.demo.dregg.online".into())
        );
        for odd in ["http://a42.demo.test", "https://localhost", "https://a42.demo.test/i/x", "https://A42.demo.test", "https://a42.", "https://a42..test"] {
            assert_eq!(super::publishing_origin(odd), Err("publishingOriginUnavailable"), "{odd}");
        }
    }

    #[test]
    fn identity_objects_decode_only_with_this_connection_tag() {
        let secret = [5; 32];
        let identity = SavedIdentity { identity_id: [9; 32], display_name: "Grace".into(), preferred_handle: "grace".into() };
        let object = encode_identity_object(&identity, &identity_tag(&secret, &identity.identity_id));
        assert_eq!(decode_identity_object(&object, &secret).unwrap(), identity);
        assert!(decode_identity_object(&object, &[6; 32]).unwrap_err().starts_with("identityTagRefused"));
        assert!(decode_identity_object(b"not an identity", &secret).unwrap_err().starts_with("unsupportedPersistentCap"));
        let mut truncated = object.clone();
        truncated.pop();
        assert!(decode_identity_object(&truncated, &secret).unwrap_err().starts_with("identityObjectRefused"));
        let mut trailing = object;
        trailing.push(0);
        assert!(decode_identity_object(&trailing, &secret).unwrap_err().starts_with("identityObjectRefused"));
    }

    #[tokio::test(flavor = "current_thread")]
    async fn two_party_fd3_bootstrap_session_and_web_get() {
        tokio::task::LocalSet::new()
            .run_until(async {
                let (host_fd, app_fd) = UnixStream::pair().unwrap();
                let observed = Rc::new(RefCell::new(Observed::default()));
                let main: grain_capnp::main_view::Client<capnp::data::Owned> =
                    capnp_rpc::new_client(FakeApp(observed.clone()));
                let (reader, writer) = app_fd.compat().split();
                let network = twoparty::VatNetwork::new(
                    futures::io::BufReader::new(reader),
                    futures::io::BufWriter::new(writer),
                    Side::Client,
                    reader_options(),
                );
                let mut app_rpc = RpcSystem::new(Box::new(network), Some(main.client));
                let api: grain_capnp::sandstorm_api::Client<capnp::data::Owned> =
                    app_rpc.bootstrap(Side::Server);
                let app_task = tokio::task::spawn_local(app_rpc);

                let (host, host_rpc) = SupervisorConnection::from_connected_stream(host_fd);
                let host_task = tokio::task::spawn_local(host_rpc);
                assert!(api
                    .deprecated_publish_request()
                    .send()
                    .promise
                    .await
                    .is_err());

                let info = host.get_view_info().await.unwrap();
                assert_eq!(info.app_title, "Actual app");
                assert_eq!(info.permission_names, ["read", "edit"]);
                assert_eq!(info.role_count, 2);
                assert_eq!(info.denied_permissions, [false, true]);
                assert_eq!(info.permissions[1].title.localizations, [("fr".into(), "Modifier".into())]);
                assert!(info.permissions[1].obsolete);
                assert_eq!(info.roles[0].permissions, [true, false]);
                assert!(info.roles[0].default);
                assert_eq!(info.roles[1].permissions, [true, true]);
                assert!(info.roles[1].obsolete);
                let source = crate::permission_schema_source_bytes(&info, 7).unwrap();
                let value: serde_json::Value = serde_json::from_slice(&source).unwrap();
                assert_eq!(value["version"], "7");
                assert_eq!(value["permissions"][0]["name"], "read");
                assert_eq!(value["permissions"][1]["obsolete"], true);
                assert_eq!(value["roles"][0]["permissions"], serde_json::json!([true, false]));
                assert_eq!(value["roles"][0]["default"], true);
                assert_eq!(value["denied"], serde_json::json!([false, true]));
                let pinned_source: serde_json::Value = serde_json::from_str(include_str!(
                    "../tests/fixtures/permission-schema-source-v1.json"
                ))
                .unwrap();
                assert_eq!(value, pinned_source);
                observed.borrow_mut().view_fault = 1;
                assert!(host.get_view_info().await.is_err());
                observed.borrow_mut().view_fault = 2;
                assert!(host.get_view_info().await.is_err());
                observed.borrow_mut().view_fault = 0;

                let params = SessionParameters {
                    identity_id: [7; 32],
                    display_name: "Ada".into(),
                    preferred_handle: "ada".into(),
                    permissions: vec![true, false],
                    tab_id: vec![9, 8, 7],
                    base_path: "https://a9101.demo.test".into(),
                    user_agent: "Mini test".into(),
                    acceptable_languages: vec!["en".into()],
                };
                let session = host.new_web_session(&params).await.unwrap();
                let response = SupervisorConnection::get_inline(&session, "todos", 1024)
                    .await
                    .unwrap();
                assert_eq!(response.status, 200);
                assert_eq!(response.mime_type, "text/plain");
                assert_eq!(response.body, b"from packaged app");
                {
                    let seen = observed.borrow();
                    assert_eq!(seen.identity_id, vec![7; 32]);
                    assert_eq!(seen.permissions, [true, false]);
                    assert_eq!(
                        seen.session_type,
                        web_session_capnp::web_session::Client::TYPE_ID
                    );
                    assert_eq!(seen.base_path, "https://a9101.demo.test");
                    assert_eq!(seen.identity_profile, "Ada");
                    assert_eq!(seen.paths, ["todos"]);
                    assert_eq!(
                        seen.public_id,
                        ["a9101-www", "demo.test", "https://a9101-www.demo.test", "false"]
                    );
                    assert!(seen.user_address.contains("emailUnsupported"), "{}", seen.user_address);
                }
                let api_session = host.new_api_session(&params).await.unwrap();
                let api_response =
                    SupervisorConnection::get_inline(&api_session, "api/todos", 1024)
                        .await
                        .unwrap();
                assert_eq!(api_response.body, b"from packaged app");
                {
                    let seen = observed.borrow();
                    assert_eq!(seen.api_sessions, 1);
                    assert_eq!(
                        seen.session_type,
                        api_session_capnp::api_session::Client::TYPE_ID
                    );
                    assert_eq!(seen.paths, ["todos", "api/todos"]);
                }
                use crate::web::{dispatch_web, Body, Cookie, Header, Method, RequestContext, WebRequest, WebResult};
                use std::time::Duration;
                let post = WebRequest {
                    method: Method::Post,
                    path_and_query: "todos?from=app%20view&n=2".into(),
                    context: RequestContext {
                        cookies: vec![Cookie { name: "session".into(), value: "abc".into() }],
                        additional_headers: vec![Header { name: "x-sandstorm-app-test".into(), value: "yes".into() }],
                        ..Default::default()
                    },
                    body: Some(Body { mime_type: "application/json".into(), encoding: String::new(), bytes: br#"{"task":"write"}"#.to_vec() }),
                    dav: Default::default(),
                };
                let reply = dispatch_web(&session, &post, 1024, Duration::from_secs(5)).await.unwrap();
                assert_eq!(reply.headers, [Header { name: "x-sandstorm-app-test".into(), value: "kept".into() }]);
                assert!(matches!(reply.result, WebResult::Content { status: 201, body, .. } if body == br#"{"ok":true}"#));
                assert_eq!(observed.borrow().posts, [("todos?from=app%20view&n=2".into(), br#"{"task":"write"}"#.to_vec(), "session=abc".into(), "x-sandstorm-app-test=yes".into())]);
                let delete = WebRequest { method: Method::Delete, path_and_query: "todos/1".into(), context: RequestContext::default(), body: None, dav: Default::default() };
                let reply = dispatch_web(&session, &delete, 1024, Duration::from_secs(5)).await.unwrap();
                assert!(matches!(reply.result, WebResult::ClientError { status: 403, html, .. } if html == "<p>denied</p>"));
                let get = |path: &str| WebRequest { method: Method::Get, path_and_query: path.into(), context: RequestContext::default(), body: None, dav: Default::default() };
                let reply = dispatch_web(&session, &get("stream"), 64, Duration::from_secs(5)).await.unwrap();
                assert!(matches!(reply.result, WebResult::Content { body, .. } if body == b"streamed body"));
                assert!(dispatch_web(&session, &get("overflow"), 4, Duration::from_secs(5)).await.is_err());
                use crate::web::{DavArgs, Depth};
                let propfind = WebRequest {
                    method: Method::Propfind,
                    path_and_query: "dav/notes".into(),
                    context: RequestContext::default(),
                    body: Some(Body { mime_type: "application/xml".into(), encoding: String::new(), bytes: b"<propfind/>".to_vec() }),
                    dav: DavArgs { depth: Some(Depth::One), ..Default::default() },
                };
                let reply = dispatch_web(&session, &propfind, 1024, Duration::from_secs(5)).await.unwrap();
                assert!(matches!(reply.result, WebResult::Content { status: 207, body, .. } if body == b"dav/notes|1|<propfind/>"));
                let mv = WebRequest {
                    method: Method::Move,
                    path_and_query: "dav/a".into(),
                    context: RequestContext::default(),
                    body: None,
                    dav: DavArgs { destination: Some("dav/b".into()), no_overwrite: true, ..Default::default() },
                };
                let reply = dispatch_web(&session, &mv, 1024, Duration::from_secs(5)).await.unwrap();
                assert!(matches!(reply.result, WebResult::Content { status: 201, body, .. } if body == b"dav/a->dav/b|true"));
                let options = WebRequest { method: Method::Options, path_and_query: "dav".into(), context: RequestContext::default(), body: None, dav: Default::default() };
                let reply = dispatch_web(&session, &options, 1024, Duration::from_secs(5)).await.unwrap();
                assert_eq!(reply.headers, [Header { name: "dav".into(), value: "1, 2, calendar-access".into() }]);
                // Refused before the call: a MOVE without a destination, a destination on a GET,
                // a COPY with a body, a PROPFIND whose xmlContent is not text.
                let mut no_destination = mv.clone();
                no_destination.dav.destination = None;
                assert!(dispatch_web(&session, &no_destination, 1024, Duration::from_secs(5)).await.is_err());
                let mut get_with_destination = get("todos");
                get_with_destination.dav.destination = Some("x".into());
                assert!(dispatch_web(&session, &get_with_destination, 1024, Duration::from_secs(5)).await.is_err());
                let mut copy_with_body = mv.clone();
                copy_with_body.method = Method::Copy;
                copy_with_body.body = Some(Body { mime_type: String::new(), encoding: String::new(), bytes: b"x".to_vec() });
                assert!(dispatch_web(&session, &copy_with_body, 1024, Duration::from_secs(5)).await.is_err());
                let mut binary_xml = propfind.clone();
                binary_xml.body.as_mut().unwrap().bytes = vec![0xff, 0xfe];
                assert!(dispatch_web(&session, &binary_xml, 1024, Duration::from_secs(5)).await.is_err());
                let mut forbidden = post.clone();
                forbidden.context.additional_headers[0].name = "authorization".into();
                assert!(dispatch_web(&session, &forbidden, 1024, Duration::from_secs(5)).await.is_err());
                use crate::web::{open_web_socket, send_to_app, WebSocketOpen};
                let open = WebSocketOpen {
                    path_and_query: "websocket?x=1".into(),
                    context: RequestContext::default(),
                    protocols: vec!["chat".into(), "superchat".into()],
                };
                let mut socket = open_web_socket(&session, &open, Duration::from_secs(5)).await.unwrap();
                assert_eq!(socket.protocols, ["chat"]);
                assert_eq!(observed.borrow().paths.last().unwrap(), "ws:websocket?x=1");
                send_to_app(&socket.to_app, b"\x81\x04ping").await.unwrap();
                assert_eq!(socket.from_app.recv().await.unwrap(), b"echo:\x81\x04ping");
                send_to_app(&socket.to_app, b"two").await.unwrap();
                assert_eq!(socket.from_app.recv().await.unwrap(), b"echo:two");
                // Dropping serverStream is the close toward the app; the app
                // releases clientStream and the client side ends.
                drop(socket.to_app);
                assert!(socket.from_app.recv().await.is_none());
                let mut bad = open.clone();
                bad.protocols = vec!["not a token".into()];
                assert!(open_web_socket(&session, &bad, Duration::from_secs(5)).await.is_err());
                host_task.abort();
                app_task.abort();
            })
            .await;
    }
}
