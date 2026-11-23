#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
# Run the verification cases with Run42 and collect their verdicts in build/verdicts.json, the file the report reads.
# Run42 runs one case per execution file, so each case has its own file in verification/. Set RUN42 to the run42 executable.
#
# The verdicts of the chosen design go to build/verdicts.json and those of the alternative to build/alternative-verdicts.json,
# so that each table of the report reads only its own. The three cases of the chosen design must pass. The fourth case, the rejected 25 W alternative, must FAIL: a check that
# can never fail proves nothing, so the script exits non-zero if the alternative passes as well as when a chosen-design
# case fails.
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run42="${RUN42:?set RUN42 to the run42 executable}"
mkdir -p "${repo}/build"
cases="warms-up:pass:verdicts holds-temperature:pass:verdicts sensor-fault:pass:verdicts low-power:fail:alternative-verdicts"
for entry in ${cases}; do
  case="${entry%%:*}"
  rm -rf "${repo}/build/${case}.json" "${repo}/build/traces/${case}"   # never read the results of an earlier run
  "${run42}" verify "${repo}/model" --driver "${repo}/verification/${case}.json" --out "${repo}/build/${case}.json" \
    --trace-dir "${repo}/build/traces/${case}" --trace-points 1000 >"${repo}/build/${case}.log" 2>&1 || true
done
python3 - "${repo}" ${cases} <<'PY'
import json, sys
from pathlib import Path
repo = Path(sys.argv[1])
groups, problems = {}, 0
for entry in sys.argv[2:]:
    case, expected, group = entry.split(":")
    driver = json.loads((repo / "verification" / f"{case}.json").read_text())
    path = repo / "build" / f"{case}.json"
    if not path.exists():
        print(f"run42 wrote no verdicts for {case}:", file=sys.stderr)
        print((repo / "build" / f"{case}.log").read_text()[-2000:], file=sys.stderr)
        sys.exit(2)
    for record in json.loads(path.read_text()):
        if record["case_name"] == driver["case"]:
            groups.setdefault(group, []).append(record)
            as_expected = record["verdict"] == expected
            problems += not as_expected
            note = "" if as_expected else f"   <-- expected {expected}"
            print(f"{record['verdict']:5}  {record['case_name']}{note}")
for group, records in groups.items():
    (repo / "build" / f"{group}.json").write_text(json.dumps(records, indent=2) + "\n")
sys.exit(1 if problems else 0)
PY
