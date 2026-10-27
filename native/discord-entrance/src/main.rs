//! `mini-discord`: the Discord interactions endpoint for Mini.
//!
//! Takes no arguments. Configuration is the environment (the unit's 0600 `EnvironmentFile`,
//! `/etc/mini/discord.env`), so the application id and key never appear on argv:
//!
//! | variable | meaning |
//! |---|---|
//! | `MINI_DISCORD_MODE` | `http` (default: Discord POSTs to the Interactions Endpoint URL) or `gateway` (the bot takes `INTERACTION_CREATE` over the gateway WebSocket; for an application with no endpoint URL) |
//! | `MINI_DISCORD_BOT_TOKEN_FILE` | gateway mode: the bot token's file (systemd `LoadCredential=`); never in the environment |
//! | `MINI_DISCORD_GATEWAY_URL` | gateway mode: default `wss://gateway.discord.gg/?v=10&encoding=json` |
//! | `MINI_DISCORD_CA_FILE` | gateway mode: trust anchors (default `/etc/ssl/certs/ca-certificates.crt`) |
//! | `MINI_DISCORD_APPLICATION_ID` | the Discord application (snowflake) |
//! | `MINI_DISCORD_PUBLIC_KEY` | HTTP mode: the application's Ed25519 public key, hex |
//! | `MINI_DISCORD_LISTEN` | loopback address Caddy proxies to (default `127.0.0.1:8793`) |
//! | `MINI_DISCORD_ROSTER` | `discord_user_id -> session NAME` (default `/etc/mini/discord-roster.json`) |
//! | `MINI_DISCORD_ROSTER_OWNER_UID` | the uid that must own the roster (default 0) |
//! | `MINI_DISCORD_API_BASE` | default `https://discord.com/api/v10` (the evidence run points it at a loopback fake) |
//! | `MINI_DISCORD_SPOOL` | private directory for follow-up bodies (default `/run/mini-discord`) |
//! | `MINI_DISCORD_MAX_INFLIGHT` | lines running at once (default 4) |
//! | `MINI_SHELL_WRAPPER` `MINI_CLIENT` `MINI_HOST` `MINI_CONFIG` `MINI_SOCKET` | the ssh entrance's forced command and its first four arguments |
//! | `MINI_SESSIONS` `MINI_SPONSOR` `MINI_SPONSOR_WORKSPACE` | the session layout (`render-authorized-keys.sh`'s) |
//! | `MINI_LINE_TIMEOUT_S` | a line is stopped after this long (default 120) |
//! | `MINI_SESSION_RUNNER` | split tenancy: the root runner's socket (`/run/mini-session-run.sock`); each line runs there as the session's own account, with no setuid program in the entrance |
//! | `MINI_DISCORD_STATE` | split tenancy: this account's own directory for interaction custody and the per-session line log (required with the runner, refused without it) |
//! | `MINI_DISCORD_DOOR_LINKS` | the door's link spool for `/mini line:link CODE` (default `STATE/door-links` under split tenancy; unset otherwise: no door) |
//! | `MINI_DISCORD_DOOR_URL` | the door's https URL, named in the answer to an unlinked Discord user |
//! | `MINI_DISCORD_CUSTODY_DAYS` `MINI_DISCORD_CUSTODY_MAX` | completed interaction custody kept (default 7 days, 2000 records) |

use std::net::TcpListener;

use minidregg_discord_entrance::server::{App, Config, Mode};

fn main() {
    if std::env::args().len() > 1 {
        eprintln!("mini-discord takes no arguments; configure it through the environment (see the unit's EnvironmentFile)");
        std::process::exit(64);
    }
    let cfg = match Config::from_env() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("mini-discord: {e}");
            std::process::exit(78);
        }
    };
    let listen = cfg.listen.clone();
    let gateway_cfg = cfg.clone();
    let app = match App::new(cfg) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("mini-discord: {e}");
            std::process::exit(78);
        }
    };
    if gateway_cfg.mode == Mode::Gateway {
        eprintln!("mini-discord: taking interactions over the gateway ({})", gateway_cfg.gateway_url);
        match minidregg_discord_entrance::gateway::serve(app, &gateway_cfg) {
            Ok(()) => std::process::exit(0),
            Err(e) => {
                eprintln!("mini-discord: gateway: {e}");
                std::process::exit(78);
            }
        }
    }
    let listener = match TcpListener::bind(&listen) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("mini-discord: bind {listen}: {e}");
            std::process::exit(69);
        }
    };
    eprintln!("mini-discord: serving interactions on {listen}");
    app.serve(listener)
}
