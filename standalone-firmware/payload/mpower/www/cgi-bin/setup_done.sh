#!/bin/sh
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
require_token || exit 0
touch "$MP_ROOT/.setup_done"
cfgmtd -w -p /etc >/dev/null 2>&1
json_header
printf '{"ok":true}'
# Let the CGI response reach the browser before closing the recovery AP.
( sleep 2; /bin/sh "$MP_ROOT/bin/ap-control.sh" sync >/tmp/mpower-ap.log 2>&1 ) >/dev/null 2>&1 &
