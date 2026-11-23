#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
# Run the three verification cases with Run42 and collect their verdicts in build/verdicts.json, the file the report reads.
# Run42 runs one case per execution file, so each case has its own file in verification/. Set RUN42 to the run42 executable.
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run42="${RUN42:?set RUN42 to the run42 executable}"
mkdir -p "${repo}/build"
for case in warms-up holds-temperature sensor-fault; do
  rm -rf "${repo}/build/${case}.json" "${repo}/build/traces/${case}"   # never read the results of an earlier run
  "${run42}" verify "${repo}/model" --driver "${repo}/verification/${case}.json" --out "${repo}/build/${case}.json" \
    --trace-dir "${repo}/build/traces/${case}" --trace-points 1000 >"${repo}/build/${case}.log" 2>&1 || true
done
python3 - "${repo}" <<'PY'
import json, sys
from pathlib import Path
repo = Path(sys.argv[1])
chosen = []
for case in ("warms-up", "holds-temperature", "sensor-fault"):
    driver = json.loads((repo / "verification" / f"{case}.json").read_text())
    path = repo / "build" / f"{case}.json"
    if not path.exists():
        print(f"run42 wrote no verdicts for {case}:", file=sys.stderr)
        print((repo / "build" / f"{case}.log").read_text()[-2000:], file=sys.stderr)
        sys.exit(2)
    for record in json.loads(path.read_text()):
        if record["case_name"] == driver["case"]:
            chosen.append(record)
(repo / "build" / "verdicts.json").write_text(json.dumps(chosen, indent=2) + "\n")
for record in chosen:
    print(f"{record['verdict']:5}  {record['case_name']}  {record.get('detail') or ''}")
sys.exit(0 if all(r["verdict"] == "pass" for r in chosen) else 1)
PY
