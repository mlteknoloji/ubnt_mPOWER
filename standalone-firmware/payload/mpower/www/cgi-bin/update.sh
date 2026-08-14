#!/bin/sh
# Overlay firmware update via browser (raw tar body or ?url=).
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
require_token || exit 0
action=$(query_get action)
[ -z "$action" ] && action=upload
STATUS=/etc/persistent/mpower-update-status.json
LOCK=/tmp/mpower-fw-update.lock

set_status() {
  state=$1; message=$2; version=$3
  printf '{"ok":true,"state":"%s","message":"%s","version":"%s"}' \
    "$state" "$message" "$version" > "$STATUS.tmp"
  mv "$STATUS.tmp" "$STATUS"
}

run_install() {
  set_status installing installing "$TARGET_VERSION"
  if cd /tmp/mpower-fwnew && chmod +x install.sh && sh ./install.sh >/tmp/mpower-fw.log 2>&1 &&
     grep -q 'Flash persistence: OK' /tmp/mpower-fw.log &&
     grep -q 'OK installed' /tmp/mpower-fw.log; then
    version=$(tr -cd 'A-Za-z0-9._-' < /etc/persistent/mpower/.installed 2>/dev/null)
    set_status success updated "$version"
  else
    set_status failed install_failed ""
  fi
  rmdir "$LOCK" 2>/dev/null || true
}

case "$action" in
  status)
    json_header
    [ -f "$STATUS" ] && cat "$STATUS" || printf '{"ok":true,"state":"idle","message":"idle","version":""}'
    ;;
  upload)
    # Expect application/octet-stream raw tar on stdin
    len=${CONTENT_LENGTH:-0}
    case "$len" in ''|*[!0-9]*|0) json_header; printf '{"ok":false,"error":"empty body"}'; exit 0;; esac
    [ "$len" -gt 800000 ] && { json_header; printf '{"ok":false,"error":"too large"}'; exit 0; }
    mkdir "$LOCK" 2>/dev/null || { json_header; printf '{"ok":false,"error":"update already running"}'; exit 0; }
    rm -rf /tmp/mpower-fwnew
    mkdir -p /tmp/mpower-fwnew
    dd bs=1 count="$len" of=/tmp/mpower-fwnew/pkg.tar 2>/dev/null
    cd /tmp/mpower-fwnew || exit 0
    tar xf pkg.tar 2>/tmp/mpower-fw.err || {
      rmdir "$LOCK" 2>/dev/null
      json_header; printf '{"ok":false,"error":"bad tar"}'; exit 0
    }
    [ -f install.sh ] || { rmdir "$LOCK" 2>/dev/null; json_header; printf '{"ok":false,"error":"no install.sh"}'; exit 0; }
    TARGET_VERSION=$(tr -cd 'A-Za-z0-9._-' < VERSION 2>/dev/null)
    set_status accepted accepted "$TARGET_VERSION"
    json_header; printf '{"ok":true,"state":"accepted","version":"%s"}' "$TARGET_VERSION"
    ( sleep 1; run_install ) >/dev/null 2>&1 &
    ;;
  url)
    url=$(url_decode "$(query_get url)")
    # github.com/.../blob|raw/... → raw.githubusercontent.com (blob is an HTML page)
    url=$(printf '%s' "$url" | sed \
      -e 's|^https://github.com/\([^/]*\)/\([^/]*\)/blob/|https://raw.githubusercontent.com/\1/\2/|' \
      -e 's|^https://github.com/\([^/]*\)/\([^/]*\)/raw/|https://raw.githubusercontent.com/\1/\2/|')
    case "$url" in http://*|https://*) ;; *) json_header; printf '{"ok":false,"error":"url"}'; exit 0;; esac
    mkdir "$LOCK" 2>/dev/null || { json_header; printf '{"ok":false,"error":"update already running"}'; exit 0; }
    rm -rf /tmp/mpower-fwnew; mkdir -p /tmp/mpower-fwnew
    wget -O /tmp/mpower-fwnew/pkg.tar "$url" >/tmp/mpower-fw.err 2>&1 || \
      curl -L -o /tmp/mpower-fwnew/pkg.tar "$url" >/tmp/mpower-fw.err 2>&1 || {
      rmdir "$LOCK" 2>/dev/null
      json_header; printf '{"ok":false,"error":"download failed"}'; exit 0
    }
    head=$(dd if=/tmp/mpower-fwnew/pkg.tar bs=1 count=16 2>/dev/null)
    case "$head" in
      '<'*|*'html'*|*'HTML'*)
        rmdir "$LOCK" 2>/dev/null
        json_header; printf '{"ok":false,"error":"not a tar (HTML page)"}'; exit 0
        ;;
    esac
    sz=$(wc -c < /tmp/mpower-fwnew/pkg.tar 2>/dev/null)
    case "$sz" in ''|0|*[!0-9]*) sz=0 ;; esac
    if [ "$sz" -lt 200 ]; then
      rmdir "$LOCK" 2>/dev/null
      json_header; printf '{"ok":false,"error":"download failed"}'; exit 0
    fi
    cd /tmp/mpower-fwnew && tar xf pkg.tar 2>/tmp/mpower-fw.err || {
      rmdir "$LOCK" 2>/dev/null
      json_header; printf '{"ok":false,"error":"bad tar"}'; exit 0
    }
    [ -f install.sh ] || { rmdir "$LOCK" 2>/dev/null; json_header; printf '{"ok":false,"error":"no install.sh"}'; exit 0; }
    TARGET_VERSION=$(tr -cd 'A-Za-z0-9._-' < VERSION 2>/dev/null)
    set_status accepted accepted "$TARGET_VERSION"
    json_header; printf '{"ok":true,"state":"accepted","version":"%s"}' "$TARGET_VERSION"
    ( sleep 1; run_install ) >/dev/null 2>&1 &
    ;;
  *) json_header; printf '{"ok":false,"error":"unknown"}' ;;
esac
