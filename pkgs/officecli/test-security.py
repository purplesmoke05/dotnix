#!/usr/bin/env python3
"""Focused regression checks for the packaged OfficeCLI executable.

The test deliberately uses only the Python standard library.  It creates a
normal workbook with OfficeCLI, replaces its sheet/shared-string payload with
a small valid rich-text fixture, renders the workbook to HTML, and parses the
result without executing the preview in a browser.
"""

from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
import zipfile
from html.parser import HTMLParser
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET


MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
PACKAGE_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
DOCUMENT_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
CONTENT_TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"

MARKER = "OFFICECLI_XSS_MARKER"
MALICIOUS_TEXT = "MALICIOUS_RICH_RUN"
NORMAL_TEXT = "NORMAL_RICH_RUN"
MALICIOUS_FONT = (
    f'Arial" onmouseover="{MARKER} '
    f'<svg onload="{MARKER}">'
)


def qname(namespace: str, local_name: str) -> str:
    return f"{{{namespace}}}{local_name}"


def run_cli(executable: Path, args: list[str], workdir: Path) -> subprocess.CompletedProcess[str]:
    """Run the package entry point in the supplied isolated working directory."""

    try:
        result = subprocess.run(
            [str(executable), *args],
            cwd=workdir,
            env=os.environ.copy(),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise AssertionError(f"officecli timed out running {' '.join(args) or '<bare startup>'}") from exc

    if result.returncode != 0:
        output = (result.stdout + "\n" + result.stderr).strip()
        raise AssertionError(
            f"officecli failed ({result.returncode}) running {' '.join(args)}:\n{output[-4000:]}"
        )
    return result


def _fingerprint(path: Path) -> Any:
    """Capture content and names for one known profile path without creating it."""

    try:
        stat = path.lstat()
    except FileNotFoundError:
        return None

    if path.is_symlink():
        return ("symlink", os.readlink(path))
    if path.is_file():
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        return ("file", stat.st_mode, stat.st_size, digest)
    if not path.is_dir():
        return ("other", stat.st_mode, stat.st_size)

    entries: list[tuple[str, Any]] = []
    for child in sorted(path.iterdir(), key=lambda item: item.name):
        entries.append((child.name, _fingerprint(child)))
    return ("directory", tuple(entries))


def profile_snapshot() -> dict[str, Any]:
    """List only existing profile targets that OfficeCLI could mutate.

    The test never creates agent directories or changes HOME.  Missing paths
    remain part of the snapshot so an unexpected self-install is detected.
    """

    home = Path.home()
    paths = [
        home / ".local" / "bin" / "officecli",
        home / ".local" / "bin" / "officecli.old",
        home / ".officecli",
        home / ".claude" / "skills" / "officecli",
        home / ".copilot" / "skills" / "officecli",
        home / ".agents" / "skills" / "officecli",
        home / ".cursor" / "skills" / "officecli",
        home / ".pi" / "agent" / "skills" / "officecli",
        home / ".windsurf" / "skills" / "officecli",
        home / ".minimax" / "skills" / "officecli",
        home / ".config" / "opencode" / "skills" / "officecli",
        home / ".hermes" / "skills" / "officecli",
        home / ".openclaw" / "skills" / "officecli",
        home / ".nanobot" / "workspace" / "skills" / "officecli",
        home / ".zeroclaw" / "workspace" / "skills" / "officecli",
        home / ".dsh" / "skills" / "officecli",
        home / ".claude.json",
        home / ".cursor" / "mcp.json",
        home / ".vscode" / "mcp.json",
        home / ".cache" / "lm-studio" / "mcp-bridge-config.json",
        Path("/tmp/officecli-config.json"),
    ]
    return {str(path): _fingerprint(path) for path in paths}


def _rich_run(
    parent: ET.Element,
    text: str,
    *,
    font: str,
    color: str,
    bold: bool = False,
    size: str = "11",
) -> None:
    run = ET.SubElement(parent, qname(MAIN_NS, "r"))
    run_properties = ET.SubElement(run, qname(MAIN_NS, "rPr"))
    ET.SubElement(run_properties, qname(MAIN_NS, "rFont"), {"val": font})
    if bold:
        ET.SubElement(run_properties, qname(MAIN_NS, "b"))
    ET.SubElement(run_properties, qname(MAIN_NS, "color"), {"rgb": color})
    ET.SubElement(run_properties, qname(MAIN_NS, "sz"), {"val": size})
    ET.SubElement(run, qname(MAIN_NS, "t")).text = text


def _build_shared_strings() -> bytes:
    shared_strings = ET.Element(
        qname(MAIN_NS, "sst"),
        {"count": "1", "uniqueCount": "1"},
    )
    item = ET.SubElement(shared_strings, qname(MAIN_NS, "si"))
    # The first run carries deliberately hostile font/color metadata.  The
    # second run proves that rich formatting still survives the safety fix.
    _rich_run(
        item,
        MALICIOUS_TEXT,
        font=MALICIOUS_FONT,
        color="1234567",
    )
    _rich_run(
        item,
        NORMAL_TEXT,
        font="Aptos Display",
        color="FFFF0000",
        bold=True,
        size="12",
    )
    ET.register_namespace("", MAIN_NS)
    return ET.tostring(shared_strings, encoding="utf-8", xml_declaration=True)


def _add_shared_string_relationship(entries: dict[str, bytes]) -> None:
    rels_name = "xl/_rels/workbook.xml.rels"
    if rels_name not in entries:
        raise AssertionError("created workbook has no workbook relationships part")

    relationships = ET.fromstring(entries[rels_name])
    shared_type = f"{DOCUMENT_REL_NS}/sharedStrings"
    if any(
        child.get("Type") == shared_type for child in relationships
    ):
        entries[rels_name] = ET.tostring(relationships, encoding="utf-8", xml_declaration=True)
        return

    used_ids = {child.get("Id") for child in relationships}
    relationship_id = "rIdSharedStrings"
    suffix = 1
    while relationship_id in used_ids:
        suffix += 1
        relationship_id = f"rIdSharedStrings{suffix}"
    ET.SubElement(
        relationships,
        qname(PACKAGE_REL_NS, "Relationship"),
        {
            "Id": relationship_id,
            "Type": shared_type,
            "Target": "sharedStrings.xml",
        },
    )
    ET.register_namespace("", PACKAGE_REL_NS)
    entries[rels_name] = ET.tostring(relationships, encoding="utf-8", xml_declaration=True)


def _add_shared_string_content_type(entries: dict[str, bytes]) -> None:
    content_types_name = "[Content_Types].xml"
    if content_types_name not in entries:
        raise AssertionError("created workbook has no content-types part")

    content_types = ET.fromstring(entries[content_types_name])
    shared_part = "/xl/sharedStrings.xml"
    if not any(child.get("PartName") == shared_part for child in content_types):
        ET.SubElement(
            content_types,
            qname(CONTENT_TYPES_NS, "Override"),
            {
                "PartName": shared_part,
                "ContentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml",
            },
        )
    ET.register_namespace("", CONTENT_TYPES_NS)
    entries[content_types_name] = ET.tostring(content_types, encoding="utf-8", xml_declaration=True)


def _set_rich_cell(entries: dict[str, bytes]) -> None:
    worksheet_names = sorted(
        name
        for name in entries
        if name.startswith("xl/worksheets/") and name.endswith(".xml")
    )
    if not worksheet_names:
        raise AssertionError("created workbook has no worksheet part")

    worksheet = ET.fromstring(entries[worksheet_names[0]])
    sheet_data = worksheet.find(qname(MAIN_NS, "sheetData"))
    if sheet_data is None:
        raise AssertionError("created worksheet has no sheetData element")
    for child in list(sheet_data):
        sheet_data.remove(child)
    row = ET.SubElement(sheet_data, qname(MAIN_NS, "row"), {"r": "1"})
    cell = ET.SubElement(row, qname(MAIN_NS, "c"), {"r": "A1", "t": "s"})
    ET.SubElement(cell, qname(MAIN_NS, "v")).text = "0"
    ET.register_namespace("", MAIN_NS)
    entries[worksheet_names[0]] = ET.tostring(worksheet, encoding="utf-8", xml_declaration=True)


def inject_rich_text_fixture(workbook: Path) -> None:
    """Replace the generated workbook's payload while keeping a valid OPC package."""

    entries: dict[str, bytes] = {}
    with zipfile.ZipFile(workbook, "r") as source:
        for info in source.infolist():
            entries[info.filename] = source.read(info.filename)

    _set_rich_cell(entries)
    _add_shared_string_relationship(entries)
    _add_shared_string_content_type(entries)
    entries["xl/sharedStrings.xml"] = _build_shared_strings()

    temporary = workbook.with_name(workbook.name + ".rewrite")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as target:
            for name, payload in entries.items():
                target.writestr(name, payload)
        os.replace(temporary, workbook)
    finally:
        temporary.unlink(missing_ok=True)


class PreviewParser(HTMLParser):
    """Collect enough DOM structure to identify injected tags/attributes."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.elements: list[dict[str, Any]] = []
        self._open: list[dict[str, Any]] = []

    def _start(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        element: dict[str, Any] = {
            "tag": tag.lower(),
            "attrs": {name.lower(): value or "" for name, value in attrs},
            "text": [],
        }
        self.elements.append(element)
        if tag.lower() not in {"meta", "link", "img", "input", "br", "hr"}:
            self._open.append(element)

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self._start(tag, attrs)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self._start(tag, attrs)
        if self._open and self._open[-1]["tag"] == tag.lower():
            self._open.pop()

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        for index in range(len(self._open) - 1, -1, -1):
            if self._open[index]["tag"] == tag:
                del self._open[index:]
                break

    def handle_data(self, data: str) -> None:
        if self._open:
            self._open[-1]["text"].append(data)


def assert_safe_preview(html: str) -> None:
    parser = PreviewParser()
    parser.feed(html)
    parser.close()

    for element in parser.elements:
        attrs = element["attrs"]
        text = "".join(element["text"])
        for name, value in attrs.items():
            if name.startswith("on") and (
                MARKER in value or element["tag"] in {"span", "sup", "sub"}
            ):
                raise AssertionError(
                    f"rich-text preview contains an event attribute: <{element['tag']} {name}=...>"
                )
        if element["tag"] in {"script", "svg"} and MARKER in (text + repr(attrs)):
            raise AssertionError(f"rich-text preview contains attacker-controlled <{element['tag']}>")

    malicious_spans = [
        element
        for element in parser.elements
        if element["tag"] == "span" and MALICIOUS_TEXT in "".join(element["text"])
    ]
    normal_spans = [
        element
        for element in parser.elements
        if element["tag"] == "span" and NORMAL_TEXT in "".join(element["text"])
    ]
    if len(malicious_spans) != 1 or len(normal_spans) != 1:
        raise AssertionError("rich-text fixture did not render both runs as spans")

    malicious_style = malicious_spans[0]["attrs"].get("style", "")
    if "#1234567" in malicious_style:
        raise AssertionError("malformed rich-text color reached the CSS style")
    if "color:#000" not in malicious_style:
        raise AssertionError("malformed rich-text color did not use the safe CSS fallback")

    normal_style = normal_spans[0]["attrs"].get("style", "")
    for expected in (
        "font-weight:bold",
        "color:#FF0000",
        "font-size:12pt",
        "font-family:'Aptos Display'",
    ):
        if expected not in normal_style:
            raise AssertionError(f"normal rich-text formatting missing from style: {expected}")


def run_security_checks(executable: Path) -> None:
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise AssertionError(f"executable is missing or not executable: {executable}")

    before = profile_snapshot()
    with tempfile.TemporaryDirectory(prefix="officecli-security-") as temporary:
        workdir = Path(temporary)

        startup = run_cli(executable, [], workdir)
        if "officecli" not in startup.stdout.lower():
            raise AssertionError("bare officecli startup did not return the CLI help text")

        workbook = workdir / "rich-text.xlsx"
        run_cli(executable, ["create", str(workbook), "--locale", "en-US"], workdir)
        run_cli(
            executable,
            ["set", str(workbook), "/Sheet1/A1", "--prop", "value=fixture"],
            workdir,
        )
        inject_rich_text_fixture(workbook)

        html_path = workdir / "rich-text.html"
        run_cli(executable, ["view", str(workbook), "html", "--out", str(html_path)], workdir)
        assert_safe_preview(html_path.read_text(encoding="utf-8"))

    after = profile_snapshot()
    if before != after:
        changed = [path for path in before if before[path] != after[path]]
        raise AssertionError("clean CLI startup mutated profile paths: " + ", ".join(changed))


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {Path(argv[0]).name} /path/to/officecli", file=sys.stderr)
        return 2
    run_security_checks(Path(argv[1]).resolve())
    print("officecli security regression checks passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except Exception as exc:
        print(f"officecli security regression checks failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
