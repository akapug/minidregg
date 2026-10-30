#!/bin/bash
set -euo pipefail

CURRENT_VERSION="$(cat /opt/app/version.txt)"
if [[ ! -e /var/wgSecretKey.php ]]; then
	key="$(dd if=/dev/urandom bs=32 count=1 status=none | base64)"
	printf '<?php $wgSecretKey = "%s";\n' "$key" > /var/wgSecretKey.php
fi
if [[ ! -e /var/VERSION ]]; then
	cp -R /opt/app/init-var/. /var/
	chmod -R u+rwX /var/wiki
fi

mkdir -p /var/wiki /var/lib/nginx /var/lib/php/sessions /var/log/nginx \
	/var/mediawiki-cache /var/mediawiki-images /var/run/php \
	/var/tmp/client_temp /var/tmp/proxy_temp /var/tmp/fastcgi_temp \
	/var/tmp/uwsgi_temp /var/tmp/scgi_temp
if [[ ! -e /var/mediawiki-images/.htaccess ]]; then
	cp -a /opt/app/mediawiki/images.orig/. /var/mediawiki-images/
fi
if [[ "$(cat /var/VERSION)" != "$CURRENT_VERSION" ]]; then
	(cd /opt/app/mediawiki && /usr/bin/php8.4 maintenance/update.php --quick)
	printf '%s\n' "$CURRENT_VERSION" > /var/VERSION
fi
rm -rf /var/run
mkdir -p /var/run/php

/usr/sbin/php-fpm8.4 --nodaemonize --fpm-config /opt/app/php-fpm.conf &
fpm_pid=$!
printf '%s\n' "$fpm_pid" > /var/run/php-fpm-supervisor.pid
/usr/sbin/nginx -c /opt/app/nginx.conf -g 'daemon off;' &
nginx_pid=$!
printf '%s\n' "$nginx_pid" > /var/run/nginx-supervisor.pid

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
