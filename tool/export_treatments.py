#!/usr/bin/env python3
"""Export lib/services/treatment_db.dart as SQL that seeds public.treatments.

Usage (from the repo root):
    python3 tool/export_treatments.py > supabase/migrations/<timestamp>_seed_treatments.sql

The seed uses `on conflict do nothing`, so it never overwrites text an
agronomist has already edited in the Supabase dashboard.
"""
import re
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "lib/services/treatment_db.dart"
FIELDS = ("cause", "organic", "chemical", "prevent")


def dart_string(s: str) -> str:
    """Decode a single-quoted Dart string body (only the escapes the file uses)."""
    s = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), s)
    return s.replace("\\'", "'").replace("\\\\", "\\")


def sql_string(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def main() -> None:
    src = SRC.read_text(encoding="utf-8")
    # Only the _db map, not the generic fallback inside lookup().
    body = src[src.index("_db = {"): src.index("static Treatment lookup(")]

    entry_re = re.compile(r"^    '([a-z0-9_]+)': \{(.*?)^    \},", re.S | re.M)
    lang_re = re.compile(r"'(en|lg)': Treatment\((.*?)\),", re.S)
    field_re = re.compile(r"(\w+):\s*'((?:[^'\\]|\\.)*)'", re.S)

    rows = []
    for label, entry in entry_re.findall(body):
        for lang, args in lang_re.findall(entry):
            fields = {k: dart_string(v) for k, v in field_re.findall(args)}
            missing = [f for f in FIELDS if f not in fields]
            if missing:
                sys.exit(f"{label}/{lang}: missing {missing}")
            rows.append((label, lang, fields))

    if not rows:
        sys.exit("No treatments found - has the file format changed?")

    out = [
        "-- Initial treatment text, generated from lib/services/treatment_db.dart",
        "-- by tool/export_treatments.py. Edit treatments in the dashboard, not here.",
        "insert into public.treatments (label, lang, cause, organic, chemical, prevent) values",
    ]
    values = []
    for label, lang, f in rows:
        cols = [label, lang] + [f[k] for k in FIELDS]
        values.append("  (" + ",\n   ".join(sql_string(c) for c in cols) + ")")
    out.append(",\n".join(values))
    out.append("on conflict (label, lang) do nothing;")
    print("\n".join(out))
    print(f"exported {len(rows)} treatments", file=sys.stderr)


if __name__ == "__main__":
    main()
