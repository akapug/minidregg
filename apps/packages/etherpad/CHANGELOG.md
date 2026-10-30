# Etherpad for Mini/Sandstorm

## 3.3.12-1

- Repackaged upstream Etherpad v3.3.12 (commit f534756571d1c816e85af08acdc472a5822f5761), the current upstream security release published on 2026-10-28.
- Uses the official dependency-locked, frontend-built amd64 release payload and a pinned Node.js 24 runtime; no packages are installed globally.
- Preserves `/p/:pad/import` and `/p/:pad/export/txt`, including the import JSON success shape used by Mini's app interface.
- Retains Sandstorm read-only permissions and stable Sandstorm author identity, and opens each grain at `/p/main`.
- Uses per-grain RustyDB storage under `/var`; update checks and the legacy Etherpad HTTP API are disabled.
- Replaces the obsolete Etherpad 1.8-era plugin stack with maintained upstream core functionality.
