#!/bin/bash
set -euo pipefail
export HOME=/var TMPDIR=/var/tmp
CURRENT="$(cat /opt/app/version.txt)"
mkdir -p /var/tmp /var/lib/nginx /var/lib/php/sessions /var/log/nginx /var/tmp/client_temp /var/tmp/proxy_temp \
	/var/tmp/fastcgi_temp /var/tmp/uwsgi_temp /var/tmp/scgi_temp
if [[ ! -e /var/firefly/database.sqlite ]]; then
	mkdir -p /var/firefly
	cp -R /opt/app/init-var/. /var/firefly/
	chmod -R u+rwX /var/firefly
	printf '%s\n' "$CURRENT" > /var/firefly/VERSION
fi
if [[ ! -e /var/firefly/app-key ]]; then
	head -c 24 /dev/urandom | base64 > /var/firefly/app-key
fi
cat > /var/firefly/.env <<ENV
APP_ENV=production
APP_DEBUG=false
APP_KEY=$(cat /var/firefly/app-key)
SITE_OWNER=owner@localhost.invalid
DEFAULT_LANGUAGE=en_US
DEFAULT_LOCALE=equal
TZ=UTC
TRUSTED_PROXIES=**
DB_CONNECTION=sqlite
DB_DATABASE=/var/firefly/database.sqlite
CACHE_DRIVER=file
SESSION_DRIVER=file
LOG_CHANNEL=stack
APP_LOG_LEVEL=warning
DISABLE_FRAME_HEADER=true
DISABLE_CSP_HEADER=true
ALLOW_WEBHOOKS=false
MAPBOX_API_KEY=
AUTHENTICATION_GUARD=remote_user_guard
AUTHENTICATION_GUARD_HEADER=HTTP_X_SANDSTORM_USER_ID
AUTHENTICATION_GUARD_EMAIL=
ENV
if [[ "$(cat /var/firefly/VERSION)" != "$CURRENT" ]]; then
	(cd /opt/app/firefly && /usr/bin/php8.5 artisan migrate --seed --force && /usr/bin/php8.5 artisan firefly-iii:upgrade-database) || true
	printf '%s\n' "$CURRENT" > /var/firefly/VERSION
fi
if [[ ! -e /var/firefly/storage/oauth-private.key ]]; then
	(cd /opt/app/firefly && /usr/bin/php8.5 artisan firefly-iii:laravel-passport-keys) || true
fi
rm -rf /var/run
mkdir -p /var/run/php
/usr/sbin/php-fpm8.5 --nodaemonize --fpm-config /opt/app/php-fpm.conf &
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
	[[ -S /var/run/php/php8.5-fpm.sock ]] && break
	kill -0 "$fpm_pid"
	sleep 0.2
done
[[ -S /var/run/php/php8.5-fpm.sock ]]
wait -n "$nginx_pid" "$fpm_pid"
