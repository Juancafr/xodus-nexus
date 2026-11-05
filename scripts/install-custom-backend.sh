#!/usr/bin/env bash
# Installs a locally built Xodus backend (xodus-cli + xodus-service) as the
# launcher's managed backend, so the launcher uses it instead of the release.
# Usage: install-custom-backend.sh FOLDER_WITH_xodus-cli_AND_xodus-service
# Close Xodus Nexus first. Open Settings > Xodus backend afterwards to check it.
set -euo pipefail

source_dir=${1:-}
if [[ -z $source_dir || ! -x $source_dir/xodus-cli || ! -x $source_dir/xodus-service ]]; then
  echo "Usage: $0 FOLDER_WITH_xodus-cli_AND_xodus-service (both must be executable)" >&2
  exit 2
fi
source_dir=$(realpath -e -- "$source_dir")

mapfile -t roots < <(find "$HOME/.config" -maxdepth 2 -type d -name xodus-backends 2>/dev/null)
if [[ ${#roots[@]} -ne 1 ]]; then
  echo "Could not find the launcher's xodus-backends folder under ~/.config (found ${#roots[@]})." >&2
  echo "Open Xodus Nexus once, close it, and run this again." >&2
  exit 1
fi
root=${roots[0]}
target=$root/custom-multi-account
if pgrep -f "[Xx]odus.?[Nn]exus" >/dev/null 2>&1; then
  echo "Close Xodus Nexus first, then run this again." >&2
  exit 1
fi

mkdir -p -- "$target"
install -m 0755 -- "$source_dir/xodus-cli" "$target/xodus-cli"
install -m 0755 -- "$source_dir/xodus-service" "$target/xodus-service"
[[ -f $root/current.json ]] && cp -- "$root/current.json" "$root/current.json.before-custom"
python3 - "$root/current.json" "$target/xodus-cli" <<'PY'
import json, sys, datetime
path, binary = sys.argv[1:3]
pointer = {"commit": "custom-multi-account", "binaryPath": binary,
           "builtAt": datetime.datetime.now(datetime.timezone.utc).isoformat(), "delivery": "release",
           "linuxRunPatch": "linux-run-v25", "version": "99.0.0"}
with open(path, "w") as handle:
    json.dump(pointer, handle, indent=2)
PY
echo "Installed. Backend: $target"
echo "To go back to the normal backend: mv '$root/current.json.before-custom' '$root/current.json'"
