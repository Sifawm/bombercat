#!/bin/sh
# Runs the rules-layer tests headless. Exits non-zero on a failed check or a script error,
# or when the JSON exported for the online server was stale.
cd "$(dirname "$0")" || exit 1
godot --headless --import >/dev/null 2>&1  # refreshes the class_name cache
exported() { cat ../shared/src/config.json ../shared/src/maps/*.json 2>/dev/null | cksum; }
before=$(exported)
if timeout 120 godot --headless -s tools/export_shared.gd 2>&1 | grep -E "ERROR|at: "; then
	echo "FAIL the export of shared/src did not run cleanly."
	exit 1
fi
if [ "$before" != "$(exported)" ]; then
	echo "FAIL shared/src was stale: a Map or a balance value changed. It is exported again now; commit it."
	exit 1
fi
output=$(godot --headless -s tests/run_tests.gd 2>&1)
status=$?
echo "$output" | grep -E "^(FAIL|     |[0-9]+ tests)|ERROR|at: |Parse Error" | head -40
if echo "$output" | grep -q "ERROR"; then exit 1; fi
exit $status
