#!/bin/sh
# Replaces /usr/bin/wevent after button-watch covers that directory.
# wevent is a ubntbox symlink; do not mount this file onto the symlink
# (that would replace ubntbox). Init respawns this path, so do not exit.
# Do not read /dev/gpio_reset — button-watch.sh is the only reader.
while true; do
  sleep 3600
done
