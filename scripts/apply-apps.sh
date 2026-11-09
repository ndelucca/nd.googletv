#!/usr/bin/env bash
# Install the APKs listed in config/apps.conf (apps from outside the Play Store, such as the launcher).
# Installs only when an app is missing or older than the pinned versionCode. Each download is
# checked against the pinned SHA-256 before installing; Android itself refuses an update signed
# with a different key than the installed copy. Optional grants=PERM,... are given with pm grant.
source "$(dirname "$0")/lib.sh"
parse_apply_args "$@"
ensure_connected
require curl sha256sum

CACHE="$REPO_ROOT/.cache/apks"

installed_vc() { tv_shell pm list packages --show-versioncode "$1" | sed -nE "s/^package:${1//./\\.} versionCode:([0-9]+)$/\1/p"; }
granted()      { tv_shell dumpsys package "$1" | grep -qE "^ +$2: granted=true"; }

# fetch <url> <sha256> <file>: download unless the cached copy already matches; 1 on a mismatch.
fetch() {
  local url="$1" sha="$2" f="$3"
  if [[ ! -f "$f" || "$(sha256sum "$f" | cut -d' ' -f1)" != "$sha" ]]; then
    mkdir -p "$(dirname "$f")"
    curl -fsSL -o "$f.part" "$url" || { rm -f "$f.part"; return 1; }
    mv "$f.part" "$f"
  fi
  [[ "$(sha256sum "$f" | cut -d' ' -f1)" == "$sha" ]] || { rm -f "$f"; return 1; }
}

log "apps (waves <= $MAX_WAVE)"
while read -r pkg vc sha url extra; do
  [[ -z "$pkg" ]] && continue
  cur="$(installed_vc "$pkg")"
  if [[ -n "$cur" && "$cur" -ge "$vc" ]]; then
    report ok "$pkg" "versionCode $cur"
  else
    report change "$pkg" "${cur:-not installed} -> versionCode $vc"
    if [[ $APPLY -eq 1 ]]; then
      f="$CACHE/${pkg}_$vc.apk"
      if ! fetch "$url" "$sha" "$f"; then
        report fail "$pkg" "download failed or SHA-256 mismatch: $url"; continue
      fi
      out="$(tv_adb install -r "$f" 2>&1 || true)"
      now="$(installed_vc "$pkg")"
      if [[ -n "$now" && "$now" -ge "$vc" ]]; then
        record_change "install $pkg ${cur:-none} -> $now"
      else
        report fail "$pkg" "install failed: $(tail -n1 <<<"$out")"; continue
      fi
    fi
  fi
  # grants=PERM1,PERM2 (permissions only adb can give)
  if [[ "$extra" =~ grants=([^[:space:]]+) ]]; then
    IFS=, read -ra perms <<<"${BASH_REMATCH[1]}"
    for perm in "${perms[@]}"; do
      [[ -z "$(installed_vc "$pkg")" ]] && { report change "$pkg ${perm##*.}" "grant after install"; continue; }
      if granted "$pkg" "$perm"; then report ok "$pkg ${perm##*.}" "granted"; continue; fi
      report change "$pkg ${perm##*.}" "grant"
      if [[ $APPLY -eq 1 ]]; then
        tv_shell pm grant "$pkg" "$perm"
        if granted "$pkg" "$perm"; then record_change "grant $pkg $perm"; else report fail "$pkg ${perm##*.}" "grant did not stick"; fi
      fi
    done
  fi
done < <(conf_wave_lines "$CONFIG_DIR/apps.conf")

print_totals
