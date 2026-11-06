#!/usr/bin/env python3
"""Build inventory/SUMMARY.md and inventory/packages.tsv from a collect.sh snapshot.

Usage: summarize.py <inventory dir>
Only reads files produced by collect.sh; never talks to the TV.
"""
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

INV = Path(sys.argv[1])


def read(rel):
    p = INV / rel
    return p.read_text(errors="replace") if p.exists() else ""


def mb(n):
    return round(n / 1024 / 1024, 1)


# ---------------------------------------------------------------- device facts
props = dict(re.findall(r"^\[(.+?)\]: \[(.*)\]$", read("device/getprop.txt"), re.M))
meminfo = {k: int(v) for k, v in re.findall(r"^(\w+):\s+(\d+) kB", read("runtime/meminfo_proc.txt"), re.M)}

# ---------------------------------------------------------------- packages
pkgs = defaultdict(dict)

for line in read("packages/all.txt").splitlines():
    m = re.match(r"^(?P<path>\S+\.apk)=(?P<pkg>\S+)(?P<rest>.*)$", line)
    if not m:
        continue
    d = pkgs[m["pkg"]]
    d["apk"] = m["path"]
    for k, v in re.findall(r"(\w+)[:=](\S+)", m["rest"]):
        d[k] = v

installed = set(read("packages/installed.txt").split())
system = set(read("packages/system.txt").split())
disabled = set(read("packages/disabled.txt").split())

# dumpsys package: only the "Packages:" section (skip "Hidden system packages:").
dp = read("raw/dumpsys_package.txt")
sec = re.search(r"^Packages:\n(.*?)(?=^\S)", dp, re.M | re.S)
if sec:
    for block in re.split(r"^  Package \[", sec.group(1), flags=re.M)[1:]:
        name = block.split("]", 1)[0]
        d = pkgs[name]
        for key in ("versionName", "installerPackageName", "firstInstallTime", "lastUpdateTime"):
            m = re.search(rf"^\s+{key}=(.*)$", block, re.M)
            if m:
                d[key] = m.group(1).strip()
        m = re.search(r"^\s+pkgFlags=\[(.*)\]", block, re.M)
        flags = m.group(1).split() if m else []
        d["updated_system"] = "UPDATED_SYSTEM_APP" in flags
        m = re.search(r"^\s+User 0:.*?enabled=(\d)", block, re.M)
        if m:
            d["enabled_state"] = {"0": "default", "1": "enabled", "2": "disabled", "3": "disabled-user", "4": "disabled-until-used"}[m.group(1)]
        m = re.search(r"^\s+User 0:.*?stopped=(\w+)", block, re.M)
        if m:
            d["stopped"] = m.group(1)

# Disk usage per package.
ds = read("packages/diskstats.txt")
arrays = {k: json.loads(v) for k, v in re.findall(r"^(Package Names|App Sizes|App Data Sizes|Cache Sizes): (\[.*\])$", ds, re.M)}
if "Package Names" in arrays:
    for i, name in enumerate(arrays["Package Names"]):
        pkgs[name]["apk_bytes"] = arrays["App Sizes"][i]
        pkgs[name]["data_bytes"] = arrays["App Data Sizes"][i]
        pkgs[name]["cache_bytes"] = arrays["Cache Sizes"][i]


def pkgs_in(text):
    return {m.group(1) for m in re.finditer(r"^\s*([\w.]+)/", text, re.M)}


boot = pkgs_in(read("packages/boot_receivers.txt"))
launcher = pkgs_in(read("packages/launcher_apps.txt"))

for line in read("packages/standby_buckets.txt").splitlines():
    m = re.match(r"^([\w.]+): (\d+)$", line)
    if m:
        pkgs[m.group(1)]["bucket"] = int(m.group(2))
BUCKETS = {5: "exempt", 10: "active", 20: "working_set", 30: "frequent", 40: "rare", 45: "restricted", 50: "never"}

for line in read("packages/appops_run_any_in_background.txt").splitlines():
    m = re.match(r"^([\w.]+): RUN_ANY_IN_BACKGROUND: (\w+)", line)
    if m:
        pkgs[m.group(1)]["bg"] = m.group(2)
for line in read("packages/appops_app_auto_start.txt").splitlines():
    m = re.match(r"^([\w.]+): (?:APP_AUTO_START: (\w+)|No operations\. Default mode: (\w+))", line)
    if m:
        pkgs[m.group(1)]["autostart"] = m.group(2) or m.group(3)
for line in read("packages/dexopt.txt").splitlines():
    m = re.match(r"^\[([\w.]+)\] \[status=([\w-]+)\]", line)
    if m:
        pkgs[m.group(1)].setdefault("dexopt", m.group(2))

# Memory: Total PSS by process, summed per package (process "com.foo:bar" -> "com.foo").
pss_by_proc = []
mi = read("runtime/meminfo_dumpsys.txt")
sec = re.search(r"Total PSS by process:\n(.*?)\n\n", mi, re.S)
if sec:
    for kb, proc in re.findall(r"^\s*([\d,]+)K: (\S+) \(pid", sec.group(1), re.M):
        kb = int(kb.replace(",", ""))
        pss_by_proc.append((kb, proc))
        base = proc.split(":")[0]
        if base in pkgs:
            pkgs[base]["pss_kb"] = pkgs[base].get("pss_kb", 0) + kb
pss_by_proc.sort(reverse=True)

services = Counter()
for line in read("runtime/services_running.txt").splitlines():
    m = re.search(r"([\w.]+)/", line)
    if m:
        services[m.group(1)] += 1

for line in read("runtime/usage_yearly.txt").splitlines():
    m = re.search(r'package=(\S+) totalTimeUsed="([^"]*)" lastTimeUsed="([^"]*)".*?appLaunchCount=(\d+)', line)
    if m:
        d = pkgs[m.group(1)]
        d["time_used"], d["last_used"], d["launches"] = m.group(2), m.group(3), int(m.group(4))

kills = Counter()
for line in read("runtime/kills.txt").splitlines():
    m = re.search(r" am_kill : \[\d+,\d+,([^,]+),", line)
    if m:
        kills[m.group(1).split(":")[0]] += 1

# ---------------------------------------------------------------- packages.tsv
cols = ["package", "type", "state", "version", "installer", "apk_mb", "data_mb", "cache_mb",
        "pss_mb", "services", "boot", "launcher", "bucket", "bg", "autostart", "dexopt", "launches", "time_used", "last_used", "lmk_kills"]
rows = []
for name in sorted(n for n in pkgs if "." in n):
    d = pkgs[name]
    if name not in installed and name not in disabled and "apk" not in d:
        continue
    typ = ("system+upd" if d.get("updated_system") else "system") if name in system else "user"
    state = "uninstalled-user0" if name not in installed and name not in disabled else (
        "disabled" if name in disabled else "enabled")
    last = d.get("last_used", "")
    if last.startswith("1969") or last.startswith("1970"):
        last = ""
    rows.append({
        "package": name, "type": typ, "state": state,
        "version": d.get("versionName", ""), "installer": d.get("installerPackageName", d.get("installer", "")),
        "apk_mb": mb(d.get("apk_bytes", 0)), "data_mb": mb(d.get("data_bytes", 0)),
        "cache_mb": mb(d.get("cache_bytes", 0)), "pss_mb": round(d.get("pss_kb", 0) / 1024, 1),
        "services": services.get(name, 0), "boot": "y" if name in boot else "",
        "launcher": "y" if name in launcher else "", "bucket": BUCKETS.get(d.get("bucket"), d.get("bucket", "")),
        "bg": d.get("bg", "allow"), "autostart": d.get("autostart", ""), "dexopt": d.get("dexopt", ""), "launches": d.get("launches", ""), "time_used": d.get("time_used", ""),
        "last_used": last, "lmk_kills": kills.get(name, 0),
    })

with open(INV / "packages.tsv", "w") as f:
    f.write("\t".join(cols) + "\n")
    for r in rows:
        f.write("\t".join(str(r[c]) for c in cols) + "\n")

# ---------------------------------------------------------------- SUMMARY.md
settings = {}
for ns in ("global", "system", "secure"):
    for line in read(f"settings/{ns}.txt").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            settings[f"{ns}/{k}"] = v

INTERESTING = [
    "global/window_animation_scale", "global/transition_animation_scale", "global/animator_duration_scale",
    "global/cached_apps_freezer", "global/activity_manager_constants", "global/package_verifier_enable",
    "global/verifier_verify_adb_installs", "global/wifi_scan_always_enabled", "global/ble_scan_always_enabled",
    "global/network_recommendations_enabled", "global/stay_on_while_plugged_in", "global/hdmi_control_enabled",
    "global/hdmi_control_auto_wakeup_enabled", "global/hdmi_control_auto_device_off_enabled",
    "global/adb_enabled", "global/development_settings_enabled", "global/auto_time", "global/private_dns_mode",
    "secure/screensaver_enabled", "secure/screensaver_components", "secure/screensaver_activate_on_sleep",
    "secure/screensaver_activate_on_dock", "secure/sleep_timeout", "system/screen_off_timeout",
    "secure/default_input_method", "secure/enabled_accessibility_services", "secure/accessibility_enabled",
    "secure/install_non_market_apps", "secure/backup_enabled", "secure/location_mode",
    "secure/voice_interaction_service", "secure/assistant",
]

out = []
w = out.append
w("# TV inventory summary\n")
w(f"_Generated by `scripts/collect.sh` on {datetime.now().strftime('%Y-%m-%d %H:%M')}. Do not edit by hand._\n")

w("## Device\n")
w("| Item | Value |\n|---|---|")
for label, val in [
    ("Model", f"{props.get('ro.product.brand', '')} {props.get('ro.product.model', '')} ({props.get('ro.product.name', '')} / {props.get('ro.product.device', '')})"),
    ("Android", f"{props.get('ro.build.version.release', '')} (SDK {props.get('ro.build.version.sdk', '')})"),
    ("Build", f"{props.get('ro.build.display.id', '')} — {props.get('ro.build.fingerprint', '')}"),
    ("Security patch", props.get("ro.build.version.security_patch", "")),
    ("TCL software version", props.get("ro.software.version_id", props.get("ro.tcl.software.version", props.get("ro.vendor.build.version.incremental", "")))),
    ("SoC / board", f"{props.get('ro.board.platform', '')} / {props.get('ro.hardware', '')}"),
    ("ABIs", props.get("ro.product.cpu.abilist", "")),
    ("RAM", f"{round(meminfo.get('MemTotal', 0) / 1024)} MB (low_ram={props.get('ro.config.low_ram', '?')})"),
    ("Swap (zram)", f"{round(meminfo.get('SwapTotal', 0) / 1024)} MB total, {round(meminfo.get('SwapFree', 0) / 1024)} MB free"),
    ("Dalvik heap", f"growthlimit={props.get('dalvik.vm.heapgrowthlimit', '')} max={props.get('dalvik.vm.heapsize', '')}"),
]:
    w(f"| {label} | {val} |")
for f in ("device/cpufreq.txt", "device/display.txt"):
    w(f"\n`{f}`:\n```\n{read(f).strip()}\n```")

w("\n## Memory and load right now\n")
w("```")
w(read("runtime/uptime.txt").strip())
for k in ("MemTotal", "MemFree", "MemAvailable", "Cached", "SwapTotal", "SwapFree"):
    w(f"{k:>13}: {round(meminfo.get(k, 0) / 1024):>6} MB")
w("```")
w("\nTop 25 processes by PSS (`dumpsys meminfo`):\n")
w("| PSS MB | Process |\n|---:|---|")
for kb, proc in pss_by_proc[:25]:
    w(f"| {kb / 1024:.1f} | {proc} |")

top = read("runtime/top.txt").strip().split("\n")
if top:
    # second frame of top -n 2 reflects real CPU usage over the sample window
    idx = [i for i, l in enumerate(top) if l.lstrip().startswith("Tasks:")]
    frame = top[idx[-1]:] if idx else top
    w("\nCPU snapshot (`top`, second sample):\n```\n" + "\n".join(frame[:30]) + "\n```")

w("\n## Packages\n")
counts = Counter(r["type"] for r in rows)
states = Counter(r["state"] for r in rows)
w(f"- Total: {len(rows)} — " + ", ".join(f"{k}: {v}" for k, v in sorted(counts.items())))
w("- State: " + ", ".join(f"{k}: {v}" for k, v in sorted(states.items())))
w(f"- Default home: `{read('packages/default_home.txt').strip().splitlines()[-1] if read('packages/default_home.txt').strip() else '?'}`")
w(f"- Start on boot (BOOT_COMPLETED receivers, enabled): {len([r for r in rows if r['boot'] and r['state'] == 'enabled'])} packages")
w("- Full per-package table: [`packages.tsv`](packages.tsv)\n")


def table(title, rs, extra):
    w(f"\n### {title}\n")
    w("| Package | Type | State | " + " | ".join(extra) + " |")
    w("|---|---|---|" + "---:|" * len(extra))
    for r in rs:
        w(f"| `{r['package']}` | {r['type']} | {r['state']} | " + " | ".join(str(r[e]) for e in extra) + " |")


enabled_rows = [r for r in rows if r["state"] == "enabled"]
table("Heaviest in RAM (enabled)", sorted(enabled_rows, key=lambda r: -r["pss_mb"])[:25], ["pss_mb", "services", "boot", "bucket"])
table("Running services right now", sorted([r for r in rows if r["services"]], key=lambda r: -r["services"]), ["services", "pss_mb", "boot"])
table("Start on boot", [r for r in rows if r["boot"] and r["state"] == "enabled"], ["pss_mb", "launcher", "last_used"])
table("Apps with a launcher icon", [r for r in rows if r["launcher"]], ["version", "launches", "time_used", "last_used"])
table("Third-party apps", [r for r in rows if r["type"] == "user"], ["version", "installer", "apk_mb", "data_mb", "cache_mb", "autostart", "dexopt"])
table("Disabled / removed for user 0", [r for r in rows if r["state"] != "enabled"], ["version"])
table("Largest on disk (apk+data+cache)",
      sorted(rows, key=lambda r: -(r["apk_mb"] + r["data_mb"] + r["cache_mb"]))[:20], ["apk_mb", "data_mb", "cache_mb"])

if kills:
    w("\n## Low-memory kills in the event log\n")
    w("| Process | Kills |\n|---|---:|")
    for p, n in kills.most_common(20):
        w(f"| `{p}` | {n} |")
errtags = read("runtime/logcat_error_tags.txt").strip()
if errtags:
    w("\n## Most frequent error log tags\n```\n" + "\n".join(errtags.splitlines()[:25]) + "\n```")

w("\n## Relevant settings\n")
w("| Setting | Value |\n|---|---|")
for k in INTERESTING:
    w(f"| `{k}` | `{settings.get(k, '(unset)')}` |")

(INV / "SUMMARY.md").write_text("\n".join(out) + "\n")
print(f"summary: {len(rows)} packages, {len(pss_by_proc)} processes")
