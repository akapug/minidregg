# 0.5-1

- Repackaged for minidregg from upstream aliasaria/scrumblr snapshot
  5bb16d92d7e08e288b8e76ea974b7ac813289676 (2026-10-23, tip of the
  fly-migration branch, which strictly contains master).
- Bundles Node.js 24.22.2 (Sandstorm 308 toolchain family) and
  redis-server 8.0.2 (Debian 13) running inside the grain; board state
  persists in Redis under /var.
- Exposes the web UI through sandstorm-http-bridge with
  bridgeConfig.apiPath = "/", so an `api` interface sits next to `web`.
