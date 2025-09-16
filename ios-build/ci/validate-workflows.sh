#!/usr/bin/env bash
set -euo pipefail

ROOT=${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
WF_DIR="$ROOT/.github/workflows"

if [ ! -d "$WF_DIR" ]; then
  echo "Workflows dir not found: $WF_DIR" >&2
  exit 1
fi

echo "[lint] Python YAML parse check for workflow files"

# Ensure PyYAML is available; try to install if missing
if ! python3 - <<'PY'
try:
    import yaml  # noqa: F401
    print('OK')
except Exception:
    raise SystemExit(1)
PY
then
  echo "[lint] Installing PyYAML to user site-packages" >&2
  pip3 install --user pyyaml >/dev/null 2>&1 || true
fi

python3 - "$WF_DIR" <<'PY'
import sys, os
import yaml

# Monkeypatch PyYAML implicit bool resolver so that 'on'/'off' are NOT booleans
for ch in list('yYnNtTfFoO'):
    lst = yaml.resolver.Resolver.yaml_implicit_resolvers.get((ch, None))
    if not lst:
        continue
    yaml.resolver.Resolver.yaml_implicit_resolvers[(ch, None)] = [
        (tag, regexp) for tag, regexp in lst if tag != 'tag:yaml.org,2002:bool'
    ]

wf_dir = sys.argv[1]
errors = []
for name in os.listdir(wf_dir):
    if not (name.endswith('.yml') or name.endswith('.yaml')):
        continue
    path = os.path.join(wf_dir, name)
    with open(path, 'r', encoding='utf-8') as f:
        try:
            data = yaml.safe_load(f)
        except Exception as e:
            errors.append(f"YAML parse error in {name}: {e}")
            continue
        # Minimal structural checks
        if not isinstance(data, dict):
            errors.append(f"{name}: root must be a mapping")
            continue
        # Accept both literal 'on' and boolean True (PyYAML 1.1 quirk)
        if 'on' not in data and True not in data:
            errors.append(f"{name}: missing required 'on' section")
        if 'jobs' not in data or not isinstance(data['jobs'], dict) or not data['jobs']:
            errors.append(f"{name}: missing or empty 'jobs' section")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print("All workflow YAML files parsed successfully")
PY

echo "[lint] OK"
