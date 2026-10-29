#!/bin/bash
set -euo pipefail

mkdir -p /var/lib/nginx /var/lib/php/sessions /var/lib/dokuwiki/users \
  /var/log/nginx /var/run /var/tmp/client_temp /var/tmp/proxy_temp \
  /var/tmp/fastcgi_temp /var/tmp/uwsgi_temp /var/tmp/scgi_temp
rm -rf /var/run
mkdir -p /var/run

if [[ ! -d /var/lib/dokuwiki/conf ]]; then
  rsync -a /opt/app/dokuwiki/conf.orig/ /var/lib/dokuwiki/conf/
  cp /opt/app/local.php /var/lib/dokuwiki/conf/local.php
fi
if [[ ! -d /var/lib/dokuwiki/data ]]; then
  rsync -a /opt/app/dokuwiki/data.orig/ /var/lib/dokuwiki/data/
fi
mkdir -p /var/lib/dokuwiki/lib/plugins /var/lib/dokuwiki/lib/tpl
rsync -a /opt/app/dokuwiki/lib/plugins.orig/ /var/lib/dokuwiki/lib/plugins/
rsync -a /opt/app/dokuwiki/lib/tpl.orig/ /var/lib/dokuwiki/lib/tpl/
rsync -a /opt/app/plugin/sandstorm/ /var/lib/dokuwiki/lib/plugins/sandstorm/
cp /opt/app/local.protected.php /var/lib/dokuwiki/conf/local.protected.php
cp /opt/app/acl.auth.php /var/lib/dokuwiki/conf/acl.auth.php
cp /opt/app/version.txt /var/lib/dokuwiki/VERSION

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
  [[ -S /var/run/php-fpm.sock ]] && break
  kill -0 "$fpm_pid"
  sleep 0.2
done
[[ -S /var/run/php-fpm.sock ]]
wait -n "$nginx_pid" "$fpm_pid"
