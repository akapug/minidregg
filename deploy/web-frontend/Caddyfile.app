# The web front end's route for the one edge (Caddy; minidregg docs/WEB-FRONTEND-2026-10-27.md).
# The infra lane owns the Caddyfile (dregg-infra-demo-vm edge/demo/host/caddy/Caddyfile); import
# this snippet into the demo.dregg.online site block AFTER the /join, /interactions and /mini/v1
# handles. It replaces the fallback `handle { respond "Mini demo…" }` and the docuverse snapshot
# route: the application is the site, for members and for the public reader alike.
#
# The gateway (uid mini-web, 127.0.0.1:8797) is a loopback listener with no key, no Store and no
# socket path; WebSocket upgrades (/ws/term/*) are long-lived and need the long timeouts below.
(mini_app) {
	header {
		X-Content-Type-Options nosniff
		Referrer-Policy same-origin
		Strict-Transport-Security "max-age=31536000"
		-Server
	}
	handle /ws/* {
		reverse_proxy 127.0.0.1:8797 {
			transport http {
				dial_timeout 2s
				response_header_timeout 15s
				read_timeout 0
				write_timeout 0
			}
			flush_interval -1
		}
	}
	handle {
		request_body {
			max_size 256KB
		}
		reverse_proxy 127.0.0.1:8797 {
			transport http {
				dial_timeout 2s
				# A write through a form waits on the Host (p99 10 s on the serial Host): the body's
				# own deadline is 120 s so a slow answer is a decoded outcome, never a dropped one.
				response_header_timeout 125s
			}
		}
	}
}
# demo.dregg.online {
#	handle /interactions { ... }
#	handle /join* { ... }
#	handle /mini/v1/* { ... }
#	import mini_app
# }
