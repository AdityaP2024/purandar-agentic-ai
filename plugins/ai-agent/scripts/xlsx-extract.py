#!/usr/bin/env python3
"""ai-agent plugin — .xlsx to TSV extraction (gap-analysis tooling).

Converts the module-wise user-story workbooks developers drop into
docs/input-specs/ into plain TSV that agents can Read — the Read tool cannot
open spreadsheet binaries. An .xlsx file is a zip of XML, so everything here
is python3 standard library (zipfile + xml.etree): no pip installs, no
network, reads exactly the one file it is given and writes nothing anywhere.

Usage:
  xlsx-extract.py <file.xlsx>             every sheet, each headed "# sheet: <name>"
  xlsx-extract.py <file.xlsx> <sheet>     one sheet, selected by name
  xlsx-extract.py --list <file.xlsx>      sheet names only, one per line

Cell handling: shared strings (including rich-text runs), inline strings,
cached formula results, booleans (TRUE/FALSE), and date-styled numbers —
converted to ISO dates/times so agents never see raw Excel serials. Embedded
tabs become spaces and embedded newlines the two characters "\\n", so one
spreadsheet row is always exactly one TSV line. Fully empty rows are dropped;
gaps between populated cells become empty TSV fields, so column positions
survive.

Exit 0 on success; exit 1 with a one-line stderr message when the file is
missing, is not a readable .xlsx, or the requested sheet does not exist.
"""

import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta

# Built-in Excel number-format ids that render as dates/times (14-22, the
# locale date set 27-36, elapsed-time 45-47, and the East Asian set 50-58).
BUILTIN_DATE_IDS = (
    set(range(14, 23)) | set(range(27, 37)) | set(range(45, 48)) | set(range(50, 59))
)


def fail(msg):
    print("xlsx-extract: %s" % msg, file=sys.stderr)
    sys.exit(1)


def local(tag):
    return tag.rsplit("}", 1)[-1]


def clean(value):
    return value.replace("\t", " ").replace("\r", "").replace("\n", "\\n")


def col_index(cell_ref):
    """'C7' -> 2. Falls back to None when the cell carries no reference."""
    letters = "".join(ch for ch in cell_ref if ch.isalpha())
    if not letters:
        return None
    n = 0
    for ch in letters.upper():
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def text_runs(el):
    """Concatenated text of every <t> descendant (plain and rich-text runs)."""
    return "".join(t.text or "" for t in el.iter() if local(t.tag) == "t")


def read_xml(zf, member):
    try:
        return ET.fromstring(zf.read(member))
    except KeyError:
        return None
    except ET.ParseError:
        fail("%s inside the workbook is not valid XML" % member)


def shared_strings(zf):
    root = read_xml(zf, "xl/sharedStrings.xml")
    if root is None:
        return []
    return [text_runs(si) for si in root if local(si.tag) == "si"]


def date_style_indices(zf):
    """Indices into cellXfs whose number format is a date/time format."""
    root = read_xml(zf, "xl/styles.xml")
    if root is None:
        return set()
    custom_date_ids = set()
    for el in root.iter():
        if local(el.tag) == "numFmt":
            code = re.sub(r'"[^"]*"|\[[^\]]*\]', "", el.get("formatCode", ""))
            if re.search(r"[ymdhs]", code, re.IGNORECASE):
                custom_date_ids.add(el.get("numFmtId"))
    indices = set()
    for el in root.iter():
        if local(el.tag) == "cellXfs":
            for i, xf in enumerate(el):
                fmt_id = xf.get("numFmtId", "0")
                if int(fmt_id) in BUILTIN_DATE_IDS or fmt_id in custom_date_ids:
                    indices.add(i)
            break
    return indices


def serial_to_iso(raw):
    """Excel date serial -> ISO string; returns the input untouched on any doubt."""
    try:
        serial = float(raw)
    except ValueError:
        return raw
    if serial < 0:
        return raw
    dt = datetime(1899, 12, 30) + timedelta(days=serial)
    dt = (dt + timedelta(seconds=0.5)).replace(microsecond=0)  # round to seconds
    if serial < 1:
        return dt.strftime("%H:%M:%S")
    if dt.hour or dt.minute or dt.second:
        return dt.strftime("%Y-%m-%d %H:%M")
    return dt.strftime("%Y-%m-%d")


def sheet_list(zf):
    """[(sheet name, zip member of its XML), ...] in workbook order."""
    workbook = read_xml(zf, "xl/workbook.xml")
    if workbook is None:
        fail("no xl/workbook.xml — not an .xlsx workbook")
    rels_root = read_xml(zf, "xl/_rels/workbook.xml.rels")
    rel_targets = {}
    if rels_root is not None:
        for rel in rels_root:
            target = rel.get("Target", "")
            if target.startswith("/"):
                target = target.lstrip("/")
            elif not target.startswith("xl/"):
                target = "xl/" + target
            rel_targets[rel.get("Id")] = target
    sheets = []
    for el in workbook.iter():
        if local(el.tag) != "sheet":
            continue
        name = el.get("name", "")
        rel_id = next(
            (v for k, v in el.attrib.items() if local(k) == "id"), None
        )
        target = rel_targets.get(rel_id)
        if name and target and target in zf.namelist():
            sheets.append((name, target))
    if not sheets:
        fail("workbook contains no readable sheets")
    return sheets


def sheet_rows(zf, member, shared, date_styles):
    root = read_xml(zf, member)
    rows = []
    for row in root.iter():
        if local(row.tag) != "row":
            continue
        cells = {}
        next_free = 0
        for c in row:
            if local(c.tag) != "c":
                continue
            idx = col_index(c.get("r", ""))
            if idx is None:
                idx = next_free
            next_free = idx + 1
            ctype = c.get("t", "n")
            value = ""
            if ctype == "inlineStr":
                value = text_runs(c)
            else:
                v = next((ch for ch in c if local(ch.tag) == "v"), None)
                if v is not None and v.text is not None:
                    value = v.text
                    if ctype == "s":
                        i = int(value)
                        value = shared[i] if i < len(shared) else ""
                    elif ctype == "b":
                        value = "TRUE" if value == "1" else "FALSE"
                    elif ctype == "n":
                        style = c.get("s")
                        if style is not None and int(style) in date_styles:
                            value = serial_to_iso(value)
            cells[idx] = clean(value)
        if any(cells.values()):
            width = max(k for k, v in cells.items() if v) + 1
            rows.append([cells.get(i, "") for i in range(width)])
    return rows


def main(argv):
    list_only = False
    args = list(argv)
    if args and args[0] == "--list":
        list_only = True
        args = args[1:]
    if not args or len(args) > 2 or (list_only and len(args) != 1):
        fail("usage: xlsx-extract.py [--list] <file.xlsx> [sheet-name]")
    path = args[0]
    wanted = args[1] if len(args) == 2 else None

    try:
        zf = zipfile.ZipFile(path)
    except FileNotFoundError:
        fail("%s: no such file" % path)
    except (zipfile.BadZipFile, IsADirectoryError, PermissionError):
        fail("%s is not readable as .xlsx (not a zip archive)" % path)

    with zf:
        sheets = sheet_list(zf)
        if list_only:
            for name, _ in sheets:
                print(name)
            return 0
        if wanted is not None:
            sheets = [(n, t) for n, t in sheets if n == wanted]
            if not sheets:
                fail(
                    '%s has no sheet named "%s" (sheets: %s)'
                    % (path, wanted, ", ".join(n for n, _ in sheet_list(zf)))
                )
        shared = shared_strings(zf)
        date_styles = date_style_indices(zf)
        first = True
        for name, target in sheets:
            if not first:
                print()
            first = False
            print("# sheet: %s" % name)
            for row in sheet_rows(zf, target, shared, date_styles):
                print("\t".join(row))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
