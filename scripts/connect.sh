#!/usr/bin/env bash
# Connect to the TV over ADB (idempotent) and print basic identity.
source "$(dirname "$0")/lib.sh"

ensure_connected
printf '%s  %s %s  Android %s  launcher=%s\n' \
  "$TV_SERIAL" \
  "$(tv_shell getprop ro.product.brand)" \
  "$(tv_shell getprop ro.product.model)" \
  "$(tv_shell getprop ro.build.version.release)" \
  "$(tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n1)"
