#!/bin/bash
set -euo pipefail
mkdir -p /var/lib/nginx /var/lib/php/sessions /var/log/nginx \
	/var/tmp/client_temp /var/tmp/proxy_temp /var/tmp/fastcgi_temp \
	/var/tmp/uwsgi_temp /var/tmp/scgi_temp
rm -rf /var/run
mkdir -p /var/run/php
/usr/sbin/php-fpm8.4 --nodaemonize --fpm-config /opt/app/php-fpm.conf &
fpm_pid=$!
/usr/sbin/nginx -c /opt/app/nginx.conf -g 'daemon off;' &
nginx_pid=$!
cleanup() {
	trap - EXIT TERM INT
	kill "$nginx_pid" "$fpm_pid" 2>/dev/null || true
	wait "$nginx_pid" "$fpm_pid" 2>/dev/null || true
}
trap cleanup EXIT TERM INT
for _ in $(seq 1 150); do
	[[ -S /var/run/php/php8.4-fpm.sock ]] && break
	kill -0 "$fpm_pid"
	sleep 0.2
done
[[ -S /var/run/php/php8.4-fpm.sock ]]
wait -n "$nginx_pid" "$fpm_pid"
