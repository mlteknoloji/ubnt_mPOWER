#!/bin/sh
ROOT=/etc/persistent/mpower
WWW=$ROOT/www

# rc.prestart can run before all stock paths are ready. Keep this bounded and
# never block the stock boot process.
i=0
while [ "$i" -lt 30 ]; do
  [ -d "$WWW" ] && [ -x /sbin/httpd ] && break
  sleep 1
  i=$((i + 1))
done
[ -d "$WWW" ] || exit 0

if ! ps w 2>/dev/null | grep 'httpd -p 8088' | grep -vq grep; then
  /sbin/httpd -p 8088 -h "$WWW"
fi
[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" web.8088.early
exit 0
