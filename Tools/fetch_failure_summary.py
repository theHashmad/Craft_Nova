#!/usr/bin/env python3
"""
CRAFT Test Failure Summary Tool
================================
Fetches the Latest CRAFT Test Summary HTML page, extracts all defect and test-run
references, queries the Codebeamer REST API for full details of each defect /
test case / test run, and renders a rich self-contained HTML report.

Usage
-----
    python Tools/fetch_failure_summary.py [options]

Options
-------
    --summary-url URL       URL of the CRAFT summary page
                            (default: https://code.mdtcreate.com/artf-f20c52/Latest_CRAFT_Test_Summary.html)
    --cb-url URL            Codebeamer base URL
                            (default: https://crdn.codebeamer.com)
    --username USER         Codebeamer username  (default: craft-runner)
    --password PASS         Codebeamer password  (default: craft-runner)
    --output FILE           Output HTML report path
                            (default: Reports/RF/failure_analysis_<timestamp>.html)
    --no-browser            Do not open the report in a browser after generation
    --timeout N             HTTP request timeout in seconds (default: 30)
    --skip-pass             Skip fetching CB details for PASS rows (faster)

Requirements
------------
    pip install requests beautifulsoup4
"""

import argparse
import re
import sys
import json
import webbrowser
import textwrap
from datetime import datetime
from difflib import SequenceMatcher
from html import escape
from pathlib import Path

try:
    import requests
    from bs4 import BeautifulSoup
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
except ImportError as exc:
    sys.exit(
        f"Missing dependency: {exc}\n"
        "Install with:  pip install requests beautifulsoup4"
    )

# ─────────────────────────────────────────────────────────────────────────────
# Codebeamer API helpers
# ─────────────────────────────────────────────────────────────────────────────

CB_BASE_DEFAULT = "https://crdn.codebeamer.com"
SUMMARY_URL_DEFAULT = (
    "https://code.mdtcreate.com/artf-f20c52/Latest_CRAFT_Test_Summary.html"
)
LEARNED_PATTERNS_FILE = Path(__file__).resolve().parent / "CBConfiguration" / "learned_patterns.json"

# ─────────────────────────────────────────────────────────────────────────────
# Topic clustering — driven by the @{topics} variable in Keyword_Common_API.robot
# ─────────────────────────────────────────────────────────────────────────────

# Fallback used if the robot file cannot be parsed.
DEFAULT_TOPICS = ["kCatheter", "kPatientCircuit", "kRfChannelData", "kDisplay", "kRfControl"]
KEYWORD_COMMON_API_FILE = (
    Path(__file__).resolve().parent.parent / "Keywords" / "Keyword_Common_API.robot"
)


def load_topics() -> list[str]:
    """Parse the @{topics} variable from Keyword_Common_API.robot.

    Falls back to ``DEFAULT_TOPICS`` if the file/variable cannot be read.
    """
    try:
        if KEYWORD_COMMON_API_FILE.exists():
            text = KEYWORD_COMMON_API_FILE.read_text(encoding="utf-8", errors="ignore")
            m = re.search(r"^@\{topics\}\s+(.+)$", text, re.MULTILINE)
            if m:
                # Robot Framework separates list items by 2+ spaces or tabs.
                tokens = [t.strip() for t in re.split(r"\s{2,}|\t+", m.group(1)) if t.strip()]
                if tokens:
                    return tokens
    except Exception as exc:  # noqa: BLE001
        print(f"  [warn] Could not parse topics from {KEYWORD_COMMON_API_FILE.name}: {exc}")
    return list(DEFAULT_TOPICS)


TOPICS: list[str] = load_topics()

# Stable color palette per topic (cycles if there are more topics than colors)
_TOPIC_PALETTE = [
    ("#0d47a1", "#e3f2fd"),  # blue
    ("#bf360c", "#fbe9e7"),  # deep orange
    ("#1b5e20", "#e8f5e9"),  # green
    ("#4a148c", "#f3e5f5"),  # purple
    ("#006064", "#e0f7fa"),  # cyan
    ("#5d4037", "#efebe9"),  # brown
    ("#37474f", "#eceff1"),  # blue-grey
]


def classify_topics(detail: str, suite: str = "", reason: str = "") -> list[str]:
    """Return all topic names whose token appears (case-sensitive) in any of
    detail / suite / reason. A failure may map to zero or multiple topics."""
    if not TOPICS:
        return []
    haystack = " ".join(s for s in (detail, suite, reason) if s)
    return [t for t in TOPICS if t in haystack]



class CodebeamerClient:
    """Thin wrapper around the Codebeamer REST v3 API."""

    def __init__(self, base_url: str, username: str, password: str, timeout: int = 30):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.auth = (username, password)
        self.session.headers.update({"Accept": "application/json"})
        self.session.verify = False
        self.timeout = timeout
        self._cache: dict[str, dict] = {}

    def get_item(self, item_id: str | int) -> dict:
        """Return a CB item by ID (cached)."""
        key = str(item_id)
        if key in self._cache:
            return self._cache[key]
        url = f"{self.base_url}/rest/v3/items/{key}"
        try:
            resp = self.session.get(url, timeout=self.timeout)
            if resp.status_code == 200:
                data = resp.json()
                self._cache[key] = data
                return data
            else:
                result = {"_error": f"HTTP {resp.status_code}", "id": item_id}
                self._cache[key] = result
                return result
        except Exception as exc:  # noqa: BLE001
            result = {"_error": str(exc), "id": item_id}
            self._cache[key] = result
            return result

    def get_item_relations(self, item_id: str | int) -> list[dict]:
        """Return the relations list for a CB item."""
        url = f"{self.base_url}/rest/items/{item_id}/relations"
        try:
            resp = self.session.get(url, timeout=self.timeout)
            if resp.status_code == 200:
                return resp.json() if isinstance(resp.json(), list) else []
            return []
        except Exception:  # noqa: BLE001
            return []

    def get_test_run_results(self, test_run_id: str | int) -> dict:
        """Return a test run item (same as get_item but alias for clarity)."""
        return self.get_item(test_run_id)


# ─────────────────────────────────────────────────────────────────────────────
# HTML summary page parser
# ─────────────────────────────────────────────────────────────────────────────

# Matches patterns like  "112730 (TC 109051)"  or  "112730(TC109051)"
DEFECT_PATTERN = re.compile(
    r"(\d{4,7})\s*\(TC\s+(\d{4,7})\)", re.IGNORECASE
)


def parse_summary_page(html: str) -> tuple[dict, list[dict]]:
    """
    Parse the CRAFT test-summary HTML.

    Returns
    -------
    meta : dict  – top-level build/pipeline/date info
    rows : list[dict]  – one entry per table row
    """
    soup = BeautifulSoup(html, "html.parser")

    # ── meta info ──────────────────────────────────────────────────────────
    meta: dict[str, str] = {
        "project": "N/A",
        "build_id": "N/A",
        "pipeline_id": "N/A",
        "date_generated": "N/A",
        "pass_percentage": "N/A",
        "total_suites": "N/A",
        "passed": "N/A",
        "failed": "N/A",
        "skipped": "N/A",
        "suite_setup_failures": "N/A",
    }

    # Harvest every table cell that might contain meta data
    for table in soup.find_all("table"):
        for row in table.find_all("tr"):
            cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
            for i, cell in enumerate(cells):
                lc = cell.lower()
                if "project" in lc and i + 1 < len(cells):
                    meta["project"] = cells[i + 1]
                elif "build id" in lc and i + 1 < len(cells):
                    meta["build_id"] = cells[i + 1]
                elif "pipeline id" in lc and i + 1 < len(cells):
                    meta["pipeline_id"] = cells[i + 1]
                elif "date generated" in lc and i + 1 < len(cells):
                    meta["date_generated"] = cells[i + 1]
                elif "pass percentage" in lc and i + 1 < len(cells):
                    meta["pass_percentage"] = cells[i + 1]
                elif "total test suites" in lc and i + 1 < len(cells):
                    meta["total_suites"] = cells[i + 1]
                if cells and cells[0] == "Passed" and i + 1 < len(cells):
                    meta["passed"] = cells[i + 1]
                if "passed" in lc and i + 1 < len(cells) and cells[i + 1].isdigit():
                    meta["passed"] = cells[i + 1]
                if "failed" in lc and "suite" not in lc and i + 1 < len(cells) and cells[i + 1].isdigit():
                    meta["failed"] = cells[i + 1]
                if "skipped" in lc and i + 1 < len(cells):
                    meta["skipped"] = cells[i + 1]
                if "suite setup" in lc and i + 1 < len(cells):
                    meta["suite_setup_failures"] = cells[i + 1]

    # ── suite result rows ──────────────────────────────────────────────────
    rows: list[dict] = []

    for table in soup.find_all("table"):
        headers = [th.get_text(strip=True).lower() for th in table.find_all("th")]
        # Identify the main results table by its columns
        if not (
            any("suite" in h for h in headers)
            and any("status" in h for h in headers)
        ):
            continue

        for tr in table.find_all("tr"):
            cells_raw = tr.find_all(["td", "th"])
            if not cells_raw:
                continue
            cells = [c.get_text(strip=True) for c in cells_raw]
            if len(cells) < 4:
                continue
            # Skip header row
            if cells[0].strip() == "#" or cells[0].lower() == "#":
                continue
            # Must start with a row number
            if not cells[0].strip().isdigit():
                continue

            row_num = cells[0].strip()
            suite_name = cells[1].strip() if len(cells) > 1 else "N/A"
            test_run_id = cells[2].strip() if len(cells) > 2 else "N/A"
            status = cells[3].strip() if len(cells) > 3 else "N/A"
            defect_raw = cells[4].strip() if len(cells) > 4 else "N/A"

            # Parse defect references
            defects: list[dict] = []
            if defect_raw.upper() != "N/A" and defect_raw:
                for m in DEFECT_PATTERN.finditer(defect_raw):
                    defects.append(
                        {"defect_id": m.group(1), "tc_id": m.group(2)}
                    )

            rows.append(
                {
                    "row_num": row_num,
                    "suite_name": suite_name,
                    "test_run_id": test_run_id,
                    "status": status,
                    "defect_raw": defect_raw,
                    "defects": defects,
                    # To be filled by CB API calls
                    "test_run_details": None,
                    "defect_details": [],
                    "tc_details": [],
                }
            )
        # Only process the first matching table
        if rows:
            break

    return meta, rows


# ─────────────────────────────────────────────────────────────────────────────
# CB data enrichment
# ─────────────────────────────────────────────────────────────────────────────

def _extract_field(item: dict, *field_names: str, default: str = "N/A") -> str:
    """Safely drill into nested dicts / lists to extract a scalar value."""
    for fn in field_names:
        val = item.get(fn)
        if val is None:
            continue
        if isinstance(val, dict):
            return val.get("name") or val.get("value") or str(val)
        if isinstance(val, list) and val:
            first = val[0]
            if isinstance(first, dict):
                return first.get("name") or first.get("value") or str(first)
            return str(first)
        return str(val)
    return default


def _extract_custom_field(item: dict, field_id: int, default: str = "N/A") -> str:
    """Extract a named custom field value by its fieldId."""
    for cf in item.get("customFields", []):
        if cf.get("fieldId") == field_id:
            values = cf.get("values", [])
            if values:
                v = values[0]
                return v.get("value") or v.get("name") or str(v)
            return cf.get("value", default)
    return default


def _clean_description(desc: str, max_chars: int = 2000) -> str:
    """Strip excessive whitespace / embedded HTML from CB description text."""
    if not desc:
        return ""
    # Remove base64 image blobs
    desc = re.sub(r"!\[.*?\]\(data:image/[^)]+\)", "[image]", desc, flags=re.DOTALL)
    desc = re.sub(r"<img[^>]+>", "[image]", desc, flags=re.IGNORECASE | re.DOTALL)
    # Collapse whitespace
    desc = re.sub(r"\n{3,}", "\n\n", desc)
    desc = desc.strip()
    if len(desc) > max_chars:
        desc = desc[:max_chars] + f"… [truncated, {len(desc)} chars total]"
    return desc


def enrich_rows(
    rows: list[dict],
    cb: CodebeamerClient,
    skip_pass: bool = False,
) -> None:
    """Populate 'test_run_details', 'defect_details', 'tc_details' in place."""
    total = len(rows)
    for idx, row in enumerate(rows, 1):
        status = row["status"].upper()
        is_fail = status not in ("PASS",)

        print(
            f"  [{idx:>2}/{total}] {row['suite_name'][:55]:<55} "
            f"[{row['status']}]",
            end="",
            flush=True,
        )

        # ── Test Run details (always fetch for failed/error rows) ──────────
        if row["test_run_id"].isdigit() and (is_fail or not skip_pass):
            row["test_run_details"] = cb.get_item(row["test_run_id"])
            print(" TR✓", end="", flush=True)

        # ── Defect + TC details ────────────────────────────────────────────
        for ref in row["defects"]:
            defect = cb.get_item(ref["defect_id"])
            row["defect_details"].append(defect)
            print(f" D{ref['defect_id']}✓", end="", flush=True)

            tc = cb.get_item(ref["tc_id"])
            row["tc_details"].append(tc)
            print(f" TC{ref['tc_id']}✓", end="", flush=True)

        print()  # newline after status line


# ─────────────────────────────────────────────────────────────────────────────
# Report rendering
# ─────────────────────────────────────────────────────────────────────────────

STATUS_COLORS = {
    "PASS": ("#1a7a1a", "#d6f5d6"),
    "FAIL": ("#a00000", "#ffe0e0"),
    "FAIL-SS": ("#b36b00", "#fff3cd"),
}

def _status_style(status: str) -> tuple[str, str]:
    key = status.upper().strip()
    return STATUS_COLORS.get(key, ("#555555", "#f0f0f0"))


def _cb_item_url(cb_base: str, item_id: str | int) -> str:
    return f"{cb_base}/item/{item_id}"


def _render_defect_card(defect: dict, tc: dict, cb_base: str) -> str:
    if "_error" in defect:
        return f'<div class="defect-card error">Defect {defect.get("id")}: {escape(defect["_error"])}</div>'

    defect_id = defect.get("id", "?")
    tc_id = tc.get("id", "?") if "_error" not in tc else "?"
    defect_name = escape(_extract_field(defect, "name", default="(no name)"))
    defect_status = escape(_extract_field(defect, "status", default="N/A"))
    defect_priority = escape(_extract_field(defect, "priority", default="N/A"))
    defect_severity = _extract_field(defect, "severities", default="N/A")
    if isinstance(defect.get("severities"), list) and defect["severities"]:
        defect_severity = escape(defect["severities"][0].get("name", "N/A"))
    else:
        defect_severity = escape(str(defect_severity))

    defect_desc = escape(_clean_description(defect.get("description") or ""))
    defect_created = escape(_extract_field(defect, "createdAt", default="N/A"))
    defect_modified = escape(_extract_field(defect, "modifiedAt", default="N/A"))
    defect_url = _cb_item_url(cb_base, defect_id)

    # Found-in-build custom field (fieldId 10000)
    found_in_build = escape(_extract_custom_field(defect, 10000))

    # Assigned to
    assigned_to = "N/A"
    for field in ["assignedTo", "owners", "assignees"]:
        val = defect.get(field)
        if val:
            if isinstance(val, list) and val:
                assigned_to = escape(val[0].get("name", "N/A"))
            elif isinstance(val, dict):
                assigned_to = escape(val.get("name", "N/A"))
            break

    tc_name = "N/A"
    tc_url = ""
    if "_error" not in tc:
        tc_name = escape(_extract_field(tc, "name", default="(no name)"))
        tc_url = _cb_item_url(cb_base, tc_id)

    status_color = "#a00000"
    if "closed" in defect_status.lower():
        status_color = "#1a7a1a"
    elif "open" in defect_status.lower() or "new" in defect_status.lower():
        status_color = "#a00000"

    return textwrap.dedent(f"""\
        <div class="defect-card">
          <div class="defect-header">
            <span class="defect-id">
              <a href="{defect_url}" target="_blank">DEFECT-{defect_id}</a>
            </span>
            <span class="defect-status" style="background:{status_color}20;color:{status_color};border:1px solid {status_color}">
              {defect_status}
            </span>
            <span class="defect-priority">Priority: {defect_priority}</span>
            <span class="defect-severity">Severity: {defect_severity}</span>
          </div>
          <div class="defect-name">{defect_name}</div>
          <table class="defect-meta">
            <tr><th>Linked TC</th>
                <td>{"<a href='" + tc_url + "' target='_blank'>" + str(tc_id) + "</a> – " + tc_name if tc_url else tc_name}</td></tr>
            <tr><th>Assigned To</th><td>{assigned_to}</td></tr>
            <tr><th>Found In Build</th><td>{found_in_build}</td></tr>
            <tr><th>Created</th><td>{defect_created}</td></tr>
            <tr><th>Last Modified</th><td>{defect_modified}</td></tr>
          </table>
          {"<details><summary>Description</summary><pre class='desc-pre'>" + defect_desc + "</pre></details>" if defect_desc else ""}
        </div>
    """)


def _render_test_run_card(tr_details: dict | None, test_run_id: str, cb_base: str) -> str:
    if tr_details is None:
        return ""
    if "_error" in tr_details:
        return f'<div class="tr-card error">Test Run {test_run_id}: {escape(tr_details["_error"])}</div>'

    conclusion = escape(_clean_description(tr_details.get("conclusion") or "", max_chars=800))
    result = escape(_extract_field(tr_details, "result", default="N/A"))
    run_time = escape(_extract_field(tr_details, "runTime", default="N/A"))
    tr_name = escape(_extract_field(tr_details, "name", default=""))
    tr_url = _cb_item_url(cb_base, test_run_id)

    return textwrap.dedent(f"""\
        <div class="tr-card">
          <div class="tr-header">
            <a href="{tr_url}" target="_blank">Test Run {test_run_id}</a>
            {"– " + tr_name if tr_name else ""}
            <span class="tr-result">Result: {result}</span>
            <span class="tr-runtime">Runtime: {run_time}s</span>
          </div>
          {"<details><summary>Conclusion / Error message</summary><pre class='desc-pre'>" + conclusion + "</pre></details>" if conclusion else ""}
        </div>
    """)


# ─────────────────────────────────────────────────────────────────────────────
# Known failure patterns  (checked in order, first match wins)
# ─────────────────────────────────────────────────────────────────────────────

# Each entry: (key, display_name, regex, color_fg, color_bg, description)
KNOWN_PATTERNS: list[tuple[str, str, re.Pattern, str, str, str]] = [
    # ── Specific errors first so they win over generic "Setup failed" catch-all ──
    (
        "grpc_timeout",
        "Audio Service / gRPC Timeout",
        re.compile(
            r"_InactiveRpcError|DEADLINE_EXCEEDED|StatusCode\.DEADLINE"
            r"|TimeoutError.*timed out|timed out.*audio|audio.*timed out",
            re.IGNORECASE,
        ),
        "#7a1a00", "#fff0eb",
        "Audio service gRPC call timed out (_InactiveRpcError / DEADLINE_EXCEEDED / TimeoutError). "
        "The audio service was unreachable or unresponsive during setup or test execution. "
        "Affects both direct gRPC audio tests and suites whose setup invokes the audio service.",
    ),
    (
        "language_mismatch",
        "Language / Locale Mismatch",
        re.compile(r"English.*!=.*Language|Language.*!=.*English|does not match default.*English", re.IGNORECASE),
        "#003d7a", "#e8f0fc",
        "UI language was not set to English before the test ran. "
        "Likely a DUT state leak from a previous test session.",
    ),
    (
        "archiver_config_diff",
        "Archiver Config Schema Change",
        re.compile(r"storage\.filename.*therapy\.db|therapy\.db.*storage\.filename"
                   r"|max_ablation_recordings|csv\.enabled|csv\.filename", re.IGNORECASE),
        "#3a005c", "#f5eaff",
        "Archiver config schema changed on the DUT — fields like storage.filename / "
        "max_ablation_recordings / csv.enabled no longer exist. "
        "Test setup diff detects the mismatch before any steps run.",
    ),
    (
        "hdd_csv_header",
        "HDD CSV Header Mismatch",
        re.compile(r"Header of hdd\.csv.*different|hdd\.csv.*header", re.IGNORECASE),
        "#5c0000", "#fff0f0",
        "The hdd.csv schema changed — column headers no longer match what the test expects.",
    ),
    (
        "hdd_no_data",
        "HDD Archiver – No New Data",
        re.compile(r"No new data added.*hdd\.csv|Line count did not increase", re.IGNORECASE),
        "#005c3a", "#eafaf3",
        "HDD archiver did not write new rows to therapy/hdd.csv within the expected window.",
    ),
    (
        "squish_connect_aut",
        "Squish Error: Connect to AUT refused",
        re.compile(r"Connect\s*To\s*AUT|attachToApplication\s*\(\s*\)", re.IGNORECASE),
        "#4a148c", "#f3e5f5",
        "Squish could not attach to the Application Under Test "
        "(Connect To AUT / attachToApplication() failed). "
        "Typically the AUT was not running, the Squish server was unreachable, "
        "or the application crashed before the test could connect.",
    ),
    # ── Generic catch-all — only matches if nothing above matched ──────────
    (
        "setup_failed",
        "Test Setup Failure (Other)",
        re.compile(r"Test Setup Failed|Setup failed", re.IGNORECASE),
        "#5c3a00", "#fff8e8",
        "Suite/test setup keyword failed before any test steps could execute "
        "(no more specific pattern matched).",
    ),
]


# ─────────────────────────────────────────────────────────────────────────────
# Learned patterns  –  persisted to / loaded from learned_patterns.json
# ─────────────────────────────────────────────────────────────────────────────

_PALETTE_CYCLE = [
    ("#004d40", "#e0f2f1"),  # teal
    ("#1a237e", "#e8eaf6"),  # indigo
    ("#4a148c", "#f3e5f5"),  # deep-purple
    ("#bf360c", "#fbe9e7"),  # deep-orange
    ("#006064", "#e0f7fa"),  # cyan-dark
    ("#33691e", "#f1f8e9"),  # light-green-dark
    ("#37474f", "#eceff1"),  # blue-grey
]


def load_learned_patterns() -> list[tuple[str, str, re.Pattern, str, str, str]]:
    """Load confirmed learned patterns from JSON and return in KNOWN_PATTERNS format."""
    if not LEARNED_PATTERNS_FILE.exists():
        return []
    try:
        records = json.loads(LEARNED_PATTERNS_FILE.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"  [warn] Could not load {LEARNED_PATTERNS_FILE}: {exc}")
        return []
    loaded = []
    for rec in records:
        if not rec.get("confirmed", False):
            continue
        try:
            pat = re.compile(rec["regex"], re.IGNORECASE)
        except re.error:
            continue
        loaded.append((
            rec["key"],
            rec["display_name"],
            pat,
            rec.get("color_fg", "#333"),
            rec.get("color_bg", "#f5f5f5"),
            rec.get("description", ""),
        ))
    return loaded


def _extract_error_signature(detail: str) -> str:
    """
    Pull the most distinctive single-line error clause from a detail string.
    Tries in order:
      1. Text after 'Error Message :' or 'Error:'
      2. A line containing an exception class name (Error|Exception|Failure)
      3. First non-empty line
    """
    # 1. After 'Error Message :'
    m = re.search(r"Error Message\s*:\s*(.+?)(?:\.|\n|$)", detail, re.IGNORECASE)
    if m:
        sig = m.group(1).strip()
        # Trim trailing boilerplate
        sig = re.sub(r"\s*Total Steps:.*", "", sig)
        if len(sig) > 15:
            return sig[:200]
    # 2. Exception class line
    for line in detail.splitlines():
        if re.search(r"[A-Z][a-z]+(?:Error|Exception|Failure|Timeout)", line):
            return line.strip()[:200]
    # 3. First non-empty line
    for line in detail.splitlines():
        if line.strip():
            return line.strip()[:200]
    return detail[:200]


def _auto_regex_from_signature(sig: str) -> str:
    """
    Build a conservative regex from an error signature by:
    - Extracting the exception class name (if any)
    - Keeping the first distinctive noun phrase (quoted strings, CamelCase tokens, etc.)
    """
    # Exception / Error class names
    exc_names = re.findall(r"[A-Z][a-zA-Z]*(?:Error|Exception|Failure|Timeout)", sig)
    if exc_names:
        return "|".join(re.escape(n) for n in dict.fromkeys(exc_names))
    # Quoted literals
    quoted = re.findall(r"'([^']{4,40})'", sig)
    if quoted:
        return re.escape(quoted[0])
    # CamelCase identifiers
    camel = re.findall(r"[A-Z][a-z]+[A-Z][a-zA-Z]+", sig)
    if camel:
        return re.escape(camel[0])
    # Fallback: first 5 meaningful words
    words = [w for w in re.split(r"\W+", sig) if len(w) > 4]
    return "|".join(re.escape(w) for w in words[:3]) if words else re.escape(sig[:40])


def propose_and_save_candidates(
    failure_info: list[dict],
    interactive: bool = False,
) -> int:
    """
    1. Collect all failure_info entries that are still 'other' (no pattern matched).
    2. Cluster them by text similarity (reuse _similarity).
    3. For each cluster generate a candidate record.
    4. Merge with existing JSON file (skip keys already present).
    5. If interactive=True, prompt user to confirm/name each new candidate.
    Returns the number of new candidates written.
    """
    other_entries = [fi for fi in failure_info if fi.get("pattern_key") == "other" and fi["detail"].strip()]
    if not other_entries:
        return 0

    # Load existing records to avoid duplicates
    existing: list[dict] = []
    if LEARNED_PATTERNS_FILE.exists():
        try:
            existing = json.loads(LEARNED_PATTERNS_FILE.read_text(encoding="utf-8"))
        except Exception:
            existing = []
    existing_keys = {r["key"] for r in existing}
    existing_regexes = {r["regex"] for r in existing}

    # Cluster other_entries by text similarity
    clusters: list[list[dict]] = []
    for entry in other_entries:
        placed = False
        for cluster in clusters:
            if _similarity(entry["detail"], cluster[0]["detail"]) >= 0.40:
                cluster.append(entry)
                placed = True
                break
        if not placed:
            clusters.append([entry])

    new_candidates: list[dict] = []
    palette = _PALETTE_CYCLE
    pal_offset = len(existing)  # cycle from where we left off

    for ci, cluster in enumerate(clusters):
        sig = _extract_error_signature(cluster[0]["detail"])
        auto_regex = _auto_regex_from_signature(sig)

        if auto_regex in existing_regexes:
            continue

        auto_key = f"learned_{abs(hash(auto_regex)) % 100000:05d}"
        if auto_key in existing_keys:
            continue

        fg, bg = palette[(pal_offset + ci) % len(palette)]
        suites = list(dict.fromkeys(e["suite"] for e in cluster))

        candidate: dict = {
            "key": auto_key,
            "display_name": sig[:80],
            "regex": auto_regex,
            "color_fg": fg,
            "color_bg": bg,
            "description": f"Auto-detected from {len(cluster)} failure(s): {sig[:120]}",
            "confirmed": False,
            "added_date": datetime.now().strftime("%Y-%m-%d"),
            "example": cluster[0]["detail"][:300],
            "affected_suites": suites,
        }

        if interactive:
            print(f"\n{'='*70}")
            print(f"New pattern candidate #{ci+1} ({len(cluster)} occurrence(s)):")
            print(f"  Signature : {sig[:120]}")
            print(f"  Auto-regex: {auto_regex}")
            print(f"  Suites    : {', '.join(suites)}")
            print(f"  Example   : {cluster[0]['detail'][:200]}")
            print()
            try:
                answer = input("  Confirm this pattern? [y/N/rename]: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                answer = "n"
            if answer == "y":
                candidate["confirmed"] = True
            elif answer == "rename" or answer.startswith("r"):
                try:
                    new_name = input("  New display name: ").strip()
                    new_rx = input(f"  Regex [{auto_regex}]: ").strip()
                    new_desc = input("  Description: ").strip()
                except (EOFError, KeyboardInterrupt):
                    new_name = new_rx = new_desc = ""
                if new_name:
                    candidate["display_name"] = new_name
                if new_rx:
                    candidate["regex"] = new_rx
                if new_desc:
                    candidate["description"] = new_desc
                candidate["confirmed"] = True
            else:
                print("  Skipped (saved as unconfirmed — re-run with --learn to confirm later).")

        new_candidates.append(candidate)

    if not new_candidates:
        return 0

    all_records = existing + new_candidates
    LEARNED_PATTERNS_FILE.parent.mkdir(parents=True, exist_ok=True)
    LEARNED_PATTERNS_FILE.write_text(
        json.dumps(all_records, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    confirmed = sum(1 for c in new_candidates if c["confirmed"])
    unconfirmed = len(new_candidates) - confirmed
    print(f"\n  Learned patterns: {confirmed} confirmed, {unconfirmed} pending — {LEARNED_PATTERNS_FILE}")
    if unconfirmed:
        print(f"  Run with --learn to interactively confirm pending patterns.")
    return len(new_candidates)


def classify_pattern(detail: str) -> str:
    """Return the key of the first matching KNOWN_PATTERNS entry, or 'other'."""
    for key, _name, pat, *_rest in KNOWN_PATTERNS:
        if pat.search(detail):
            return key
    return "other"


def _rebuild_pattern_index() -> None:
    """Rebuild _PATTERN_BY_KEY from KNOWN_PATTERNS (call after loading learned patterns)."""
    global _PATTERN_BY_KEY
    _PATTERN_BY_KEY = {k: (k, name, pat, fg, bg, desc)
                       for k, name, pat, fg, bg, desc in KNOWN_PATTERNS}


_PATTERN_BY_KEY: dict = {k: (k, name, pat, fg, bg, desc)
                          for k, name, pat, fg, bg, desc in KNOWN_PATTERNS}


def _render_root_cause_summary(failure_info: list[dict], cb_base: str) -> str:
    """Build the top-level root-cause summary table."""
    from collections import defaultdict
    buckets: dict[str, list[dict]] = defaultdict(list)
    for fi in failure_info:
        buckets[fi["pattern_key"]].append(fi)

    # Ordered: known patterns first (in definition order), then 'other'
    ordered_keys = [k for k, *_ in KNOWN_PATTERNS if k in buckets]
    if "other" in buckets:
        ordered_keys.append("other")

    rows_html = ""
    for key in ordered_keys:
        entries = buckets[key]
        count = len(entries)
        if key in _PATTERN_BY_KEY:
            _, name, _pat, fg, bg, desc = _PATTERN_BY_KEY[key]
        else:
            name, fg, bg, desc = "Other / Uncategorised", "#555", "#f5f5f5", ""

        # Unique suites
        suites = list(dict.fromkeys(e["suite"] for e in entries))  # preserve order, dedupe
        suites_html = " ".join(
            f'<span class="rc-chip">{escape(s)}</span>' for s in suites
        )

        # Unique defect IDs with CB links
        defect_ids = list(dict.fromkeys(
            e["defect_id"] for e in entries if e.get("defect_id")
        ))
        defects_html = ", ".join(
            f'<a href="{_cb_item_url(cb_base, d)}" target="_blank">DEFECT-{escape(d)}</a>'
            for d in defect_ids
        ) or "<span style='color:#aaa'>none</span>"

        bar_pct = min(100, count * 14)  # rough visual bar

        rows_html += textwrap.dedent(f"""\
            <tr class="rc-row" style="border-left:5px solid {fg}">
              <td style="background:{bg};padding:10px 14px;min-width:200px">
                <div style="font-weight:700;font-size:13px;color:{fg}">{escape(name)}</div>
                <div style="font-size:11px;color:#555;margin-top:3px">{escape(desc)}</div>
              </td>
              <td style="text-align:center;font-size:28px;font-weight:700;color:{fg};width:60px">{count}</td>
              <td>
                <div style="background:#e8e8e8;border-radius:4px;height:8px;width:100%;margin-bottom:6px">
                  <div style="background:{fg};height:8px;border-radius:4px;width:{bar_pct}%"></div>
                </div>
                <div class="rc-suites">{suites_html}</div>
              </td>
              <td style="font-size:11px;vertical-align:top;padding-top:10px">{defects_html}</td>
            </tr>
        """)  # noqa: E501

    return textwrap.dedent(f"""\
        <table class="rc-table">
          <thead>
            <tr>
              <th style="width:240px">Root Cause</th>
              <th style="width:60px;text-align:center">Count</th>
              <th>Affected Suites</th>
              <th style="width:180px">Defects</th>
            </tr>
          </thead>
          <tbody>{rows_html}</tbody>
        </table>
    """)


def _render_topic_summary(failure_info: list[dict], cb_base: str) -> str:
    """Build a topic-bucketed summary table (kCatheter, kPatientCircuit, …).

    A failure may appear in multiple topic buckets, or in the synthetic
    "No Topic" bucket if its detail/suite/reason mentions none of the
    known topics.
    """
    from collections import defaultdict
    buckets: dict[str, list[dict]] = defaultdict(list)
    for fi in failure_info:
        topics = fi.get("topics") or []
        if not topics:
            buckets["__none__"].append(fi)
        else:
            for t in topics:
                buckets[t].append(fi)

    # Order: declared topics first (preserve TOPICS order), then No Topic.
    ordered_keys = [t for t in TOPICS if t in buckets]
    if "__none__" in buckets:
        ordered_keys.append("__none__")

    if not ordered_keys:
        return "<p style='color:#888;font-size:12px'>No failures to bucket by topic.</p>"

    rows_html = ""
    for idx, key in enumerate(ordered_keys):
        entries = buckets[key]
        count = len(entries)
        if key == "__none__":
            name = "No Topic"
            desc = "Failures whose detail/suite text did not mention any known topic."
            fg, bg = "#555555", "#f0f0f0"
        else:
            name = key
            desc = f"Failures referencing the gRPC topic '{key}'."
            fg, bg = _TOPIC_PALETTE[idx % len(_TOPIC_PALETTE)]

        suites = list(dict.fromkeys(e["suite"] for e in entries))
        suites_html = " ".join(
            f'<span class="rc-chip">{escape(s)}</span>' for s in suites
        )

        defect_ids = list(dict.fromkeys(
            e["defect_id"] for e in entries if e.get("defect_id")
        ))
        defects_html = ", ".join(
            f'<a href="{_cb_item_url(cb_base, d)}" target="_blank">DEFECT-{escape(d)}</a>'
            for d in defect_ids
        ) or "<span style='color:#aaa'>none</span>"

        bar_pct = min(100, count * 14)

        rows_html += textwrap.dedent(f"""\
            <tr class="rc-row" style="border-left:5px solid {fg}">
              <td style="background:{bg};padding:10px 14px;min-width:200px">
                <div style="font-weight:700;font-size:13px;color:{fg};font-family:Consolas,monospace">{escape(name)}</div>
                <div style="font-size:11px;color:#555;margin-top:3px">{escape(desc)}</div>
              </td>
              <td style="text-align:center;font-size:28px;font-weight:700;color:{fg};width:60px">{count}</td>
              <td>
                <div style="background:#e8e8e8;border-radius:4px;height:8px;width:100%;margin-bottom:6px">
                  <div style="background:{fg};height:8px;border-radius:4px;width:{bar_pct}%"></div>
                </div>
                <div class="rc-suites">{suites_html}</div>
              </td>
              <td style="font-size:11px;vertical-align:top;padding-top:10px">{defects_html}</td>
            </tr>
        """)

    return textwrap.dedent(f"""\
        <table class="rc-table">
          <thead>
            <tr>
              <th style="width:240px">Topic</th>
              <th style="width:60px;text-align:center">Count</th>
              <th>Affected Suites</th>
              <th style="width:180px">Defects</th>
            </tr>
          </thead>
          <tbody>{rows_html}</tbody>
        </table>
    """)


# ─────────────────────────────────────────────────────────────────────────────
# Similarity grouping
# ─────────────────────────────────────────────────────────────────────────────

# Stop-words to ignore when comparing details
_STOP = frozenset(
    "the a an and or is are was were be been being have has had do does did"
    " will would could should may might shall to of in on at for with by from"
    " that this it its not no as up out so but if then than into about after"
    " before during while step test case suite run id please refer log file"
    " automation execution total steps passed failed blocked".split()
)


def _normalize_for_similarity(text: str) -> str:
    """Strip timestamps, IDs, paths and stop-words; return lowercased token string."""
    if not text:
        return ""
    # Strip timestamps
    text = re.sub(r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}", " ", text)
    # Strip pure numeric tokens (IDs, counts)
    text = re.sub(r"\b\d+\b", " ", text)
    # Strip file paths / extensions
    text = re.sub(r"[\w/\\.-]+\.(?:py|robot|log|txt|html|xml)\b", " ", text, flags=re.IGNORECASE)
    # Strip URLs
    text = re.sub(r"https?://\S+", " ", text)
    # Lower-case, keep only word characters
    tokens = re.findall(r"[a-z][a-z0-9_-]*", text.lower())
    meaningful = [t for t in tokens if t not in _STOP and len(t) > 2]
    return " ".join(meaningful)


def _similarity(a: str, b: str) -> float:
    """Return SequenceMatcher ratio on normalised token strings."""
    na, nb = _normalize_for_similarity(a), _normalize_for_similarity(b)
    if not na and not nb:
        return 1.0
    if not na or not nb:
        return 0.0
    return SequenceMatcher(None, na, nb).ratio()


def group_failure_reasons(
    entries: list[dict], threshold: float = 0.42
) -> list[dict]:
    """
    Greedily cluster failure entries by:
      1. Same defect_id  → always same group
      2. Detail text similarity >= threshold  → join best-matching group
      3. Otherwise       → start a new group

    Each group dict has: label, defect_id, count, entries, centroid_detail.
    """
    groups: list[dict] = []

    for entry in entries:
        did = entry.get("defect_id", "")
        placed = False

        # 1. Same defect ID
        if did:
            for g in groups:
                if g["defect_id"] == did:
                    g["entries"].append(entry)
                    placed = True
                    break

        # 2. Text similarity
        if not placed:
            best_ratio, best_group = 0.0, None
            for g in groups:
                ratio = _similarity(entry["detail"], g["centroid_detail"])
                if ratio > best_ratio:
                    best_ratio, best_group = ratio, g
            if best_ratio >= threshold and best_group is not None:
                best_group["entries"].append(entry)
                if len(entry["detail"]) > len(best_group["centroid_detail"]):
                    best_group["centroid_detail"] = entry["detail"]
                placed = True

        # 3. New group
        if not placed:
            groups.append({
                "defect_id": did,
                "centroid_detail": entry["detail"],
                "entries": [entry],
            })

    # Label + sort
    for idx, g in enumerate(groups):
        first = g["entries"][0]
        if g["defect_id"]:
            raw_name = first["reason"].split("] ", 1)[-1] if "] " in first["reason"] else first["reason"]
            g["label"] = f"{raw_name}"
            g["label_prefix"] = f"DEFECT-{g['defect_id']}"
        else:
            sentences = re.split(r"[.\n!]", g["centroid_detail"])
            label_text = next(
                (s.strip() for s in sentences if len(s.strip()) > 15), g["centroid_detail"][:100]
            )
            g["label"] = label_text[:120]
            g["label_prefix"] = "Similar error"
        g["color_idx"] = idx
        g["count"] = len(g["entries"])

    groups.sort(key=lambda g: -g["count"])
    return groups


# Palette for group headers (cycles)
_GROUP_PALETTES = [
    ("#1a3a5c", "#e8f0f8"),  # navy
    ("#7a1a1a", "#f8e8e8"),  # crimson
    ("#1a5c2a", "#e8f8ec"),  # forest
    ("#5c3a00", "#fdf3e0"),  # amber
    ("#3a005c", "#f3e8f8"),  # purple
    ("#005c5c", "#e0f6f6"),  # teal
    ("#3a3a00", "#f8f8e0"),  # olive
    ("#003a5c", "#e0f0fa"),  # steel
]


def _render_grouped_section(groups: list[dict], cb_base: str) -> str:
    """Render the 'Root-Cause Groups' section HTML."""
    if not groups:
        return ""

    parts: list[str] = []
    for g in groups:
        fg, bg = _GROUP_PALETTES[g["color_idx"] % len(_GROUP_PALETTES)]
        cb_link = ""
        if g["defect_id"]:
            url = _cb_item_url(cb_base, g["defect_id"])
            cb_link = f' &nbsp;<a href="{url}" target="_blank" style="color:{fg};font-size:11px">↗ View in CB</a>'

        # Suite chips
        suite_chips = " ".join(
            f'<span class="grp-chip">{escape(e["suite"])}</span>'
            for e in g["entries"]
        )

        # Representative detail
        detail_html = escape(g["centroid_detail"][:600])
        if len(g["centroid_detail"]) > 600:
            detail_html += escape(f"… [{len(g['centroid_detail'])} chars total]")

        # Per-entry defect statuses (may differ if similarity-grouped)
        statuses_html = ""
        seen_statuses: set[str] = set()
        for e in g["entries"]:
            s = e.get("defect_status", "")
            if s and s not in seen_statuses:
                seen_statuses.add(s)
                color = "#1a7a1a" if "close" in s.lower() else "#a00000"
                statuses_html += f'<span class="grp-status" style="border-color:{color};color:{color}">{escape(s)}</span> '

        parts.append(textwrap.dedent(f"""\
            <div class="grp-block" style="border-left:4px solid {fg};background:{bg}">
              <div class="grp-header" style="color:{fg}">
                <span class="grp-badge" style="background:{fg}">{g['count']}</span>
                <span class="grp-label-prefix">{escape(g['label_prefix'])}</span>
                &nbsp;<span class="grp-label">{escape(g['label'])}</span>
                {cb_link}
                <span class="grp-statuses">{statuses_html}</span>
              </div>
              <div class="grp-suites">{suite_chips}</div>
              {'<details><summary>Representative detail</summary><pre class="grp-detail">' + detail_html + '</pre></details>' if detail_html.strip() else ''}
            </div>
        """))

    return "\n".join(parts)


def render_report(
    meta: dict,
    rows: list[dict],
    cb_base: str,
    summary_url: str,
    generated_at: str,
) -> str:
    """Return the full self-contained HTML report string."""

    total_fail = sum(1 for r in rows if r["status"].upper() not in ("PASS",))
    total_pass = sum(1 for r in rows if r["status"].upper() == "PASS")
    unique_defects: set[str] = set()
    for r in rows:
        for d in r["defect_details"]:
            if "_error" not in d:
                unique_defects.add(str(d.get("id", "")))
    open_defects = sum(
        1
        for r in rows
        for d in r["defect_details"]
        if "_error" not in d
        and "closed" not in _extract_field(d, "status", default="").lower()
    )

    # ── Failure reasons summary ────────────────────────────────────────────
    failure_info: list[dict] = []  # richer entries used for both flat table and grouping
    for r in rows:
        if r["status"].upper() == "PASS":
            continue
        suite = r["suite_name"]
        added = 0

        for d in r["defect_details"]:
            if "_error" in d:
                # Defect fetch failed – use test-run conclusion as detail if available
                conc = ""
                if r["test_run_details"] and "_error" not in r["test_run_details"]:
                    conc = _clean_description(
                        r["test_run_details"].get("conclusion") or "", max_chars=600
                    )
                detail_text = conc or d["_error"]
                failure_info.append({
                    "suite": suite,
                    "reason": f"Defect {d.get('id','?')} – CB fetch error",
                    "detail": detail_text,
                    "defect_id": str(d.get("id", "")),
                    "defect_status": "fetch-error",
                    "pattern_key": classify_pattern(detail_text),
                })
                added += 1
            else:
                name = _extract_field(d, "name", default="")
                desc = _clean_description(d.get("description") or "", max_chars=600)
                status = _extract_field(d, "status", default="N/A")
                failure_info.append({
                    "suite": suite,
                    "reason": f"[{status}] {name}",
                    "detail": desc,
                    "defect_id": str(d.get("id", "")),
                    "defect_status": status,
                    "pattern_key": classify_pattern(desc),
                })
                added += 1

        # No defect refs at all – fall back to test-run conclusion
        if added == 0:
            if r["test_run_details"] and "_error" not in r["test_run_details"]:
                conc = _clean_description(
                    r["test_run_details"].get("conclusion") or "", max_chars=600
                )
                failure_info.append({
                    "suite": suite,
                    "reason": "No linked defect",
                    "detail": conc,
                    "defect_id": "",
                    "defect_status": "",
                    "pattern_key": classify_pattern(conc),
                })
            else:
                failure_info.append({
                    "suite": suite,
                    "reason": "No linked defect / no CB data",
                    "detail": "",
                    "defect_id": "",
                    "defect_status": "",
                    "pattern_key": "other",
                })

    # ── Topic classification (kCatheter, kPatientCircuit, …) ───────────────
    for fi in failure_info:
        fi["topics"] = classify_topics(
            fi.get("detail", ""), fi.get("suite", ""), fi.get("reason", "")
        )

    # ── Root-cause summary (pattern-based) ──────────────────────────────────
    rc_summary_html = _render_root_cause_summary(failure_info, cb_base)
    topic_summary_html = _render_topic_summary(failure_info, cb_base)

    reason_rows_html = ""
    for fi in failure_info:
        pk = fi.get("pattern_key", "other")
        if pk in _PATTERN_BY_KEY:
            _, pname, _pat, pfg, pbg, _desc = _PATTERN_BY_KEY[pk]
            tag_html = f'<span class="pattern-tag" style="background:{pbg};color:{pfg};border-color:{pfg}">{escape(pname)}</span> '
        else:
            tag_html = ""
        reason_rows_html += textwrap.dedent(f"""\
            <tr>
              <td>{escape(fi['suite'])}</td>
              <td>{tag_html}{escape(fi['reason'])}</td>
              <td><pre class="reason-pre">{escape(fi['detail'])}</pre></td>
            </tr>
        """)

    # ── Per-suite rows ─────────────────────────────────────────────────────
    suite_rows_html = ""
    for row in rows:
        fg, bg = _status_style(row["status"])
        defect_cards = "".join(
            _render_defect_card(d, t, cb_base)
            for d, t in zip(row["defect_details"], row["tc_details"])
        )
        tr_card = _render_test_run_card(
            row["test_run_details"], row["test_run_id"], cb_base
        )
        tr_link = f'<a href="{_cb_item_url(cb_base, row["test_run_id"])}" target="_blank">{escape(row["test_run_id"])}</a>'

        suite_rows_html += textwrap.dedent(f"""\
            <tr>
              <td class="center">{escape(row["row_num"])}</td>
              <td>{escape(row["suite_name"])}</td>
              <td class="center">{tr_link}</td>
              <td class="center status-cell" style="color:{fg};background:{bg}">{escape(row["status"])}</td>
              <td>
                {defect_cards if defect_cards else "<span class='na'>N/A</span>"}
                {tr_card}
              </td>
            </tr>
        """)

    return textwrap.dedent(f"""\
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CRAFT Failure Analysis – {escape(generated_at)}</title>
        <style>
          :root {{
            --primary: #1a3a5c;
            --accent: #e84d4d;
            --pass-fg: #1a7a1a; --pass-bg: #d6f5d6;
            --fail-fg: #a00000; --fail-bg: #ffe0e0;
            --ss-fg: #b36b00;   --ss-bg: #fff3cd;
            --card-bg: #f8f8f8;
            --border: #ddd;
          }}
          * {{ box-sizing: border-box; margin: 0; padding: 0; }}
          body {{ font-family: "Segoe UI", Arial, sans-serif; font-size: 13px;
                 color: #222; background: #fff; padding: 24px; }}
          h1 {{ color: var(--primary); margin-bottom: 6px; }}
          h2 {{ color: var(--primary); margin: 28px 0 10px; border-bottom: 2px solid var(--primary); padding-bottom: 4px; }}
          h3 {{ color: #444; margin: 14px 0 6px; }}
          a {{ color: var(--primary); }}
          a:hover {{ text-decoration: underline; }}

          /* Meta strip */
          .meta-strip {{ display: flex; flex-wrap: wrap; gap: 12px; margin: 12px 0 20px;
                         background: #f0f4fa; border-radius: 6px; padding: 12px 16px; }}
          .meta-item {{ display: flex; flex-direction: column; }}
          .meta-label {{ font-size: 10px; text-transform: uppercase; color: #666; letter-spacing: .5px; }}
          .meta-value {{ font-weight: 600; font-size: 14px; }}

          /* KPI row */
          .kpi-row {{ display: flex; gap: 16px; margin-bottom: 24px; }}
          .kpi {{ flex: 1; border-radius: 8px; padding: 14px 20px; text-align: center; }}
          .kpi .kpi-num {{ font-size: 32px; font-weight: 700; }}
          .kpi .kpi-lbl {{ font-size: 11px; text-transform: uppercase; color: #555; }}
          .kpi-fail {{ background: var(--fail-bg); color: var(--fail-fg); }}
          .kpi-pass {{ background: var(--pass-bg); color: var(--pass-fg); }}
          .kpi-defect {{ background: #fff0e0; color: #7a3800; }}
          .kpi-open {{ background: #fff0e0; color: #a00000; }}

          /* Failure-reason table */
          table.reason-table {{ width: 100%; border-collapse: collapse; margin-bottom: 20px; }}
          table.reason-table th {{ background: var(--primary); color: #fff; padding: 7px 10px; text-align: left; }}
          table.reason-table td {{ border: 1px solid var(--border); padding: 7px 10px; vertical-align: top; }}
          table.reason-table tr:nth-child(even) td {{ background: #fafafa; }}
          pre.reason-pre {{ white-space: pre-wrap; word-break: break-word; font-family: Consolas, monospace; font-size: 11px; }}

          /* Root-cause summary table */
          table.rc-table {{ width: 100%; border-collapse: collapse; margin-bottom: 8px; box-shadow: 0 2px 8px rgba(0,0,0,.08); border-radius: 8px; overflow: hidden; }}
          table.rc-table th {{ background: var(--primary); color: #fff; padding: 9px 14px; text-align: left; font-size: 12px; }}
          .rc-row td {{ border-bottom: 1px solid #e8e8e8; padding: 10px 14px; vertical-align: middle; }}
          .rc-row:last-child td {{ border-bottom: none; }}
          .rc-suites {{ display: flex; flex-wrap: wrap; gap: 5px; margin-top: 4px; }}
          .rc-chip {{ background: rgba(0,0,0,.07); border-radius: 4px; padding: 2px 8px; font-size: 11px; }}
          .pattern-tag {{ display: inline-block; border: 1px solid; border-radius: 10px;
                           padding: 1px 8px; font-size: 10px; font-weight: 700;
                           margin-right: 4px; white-space: nowrap; vertical-align: middle; }}

          /* Root-cause groups */
          .grp-block {{ border-radius: 6px; padding: 12px 14px; margin: 10px 0;
                        border: 1px solid #ddd; }}
          .grp-header {{ display: flex; flex-wrap: wrap; align-items: center;
                         gap: 8px; margin-bottom: 8px; font-size: 13px; font-weight: 600; }}
          .grp-badge {{ display: inline-block; color: #fff; border-radius: 12px;
                        padding: 1px 9px; font-size: 12px; font-weight: 700; white-space: nowrap; }}
          .grp-label-prefix {{ font-size: 11px; opacity: .75; }}
          .grp-label {{ flex: 1; }}
          .grp-statuses {{ display: flex; gap: 4px; flex-wrap: wrap; }}
          .grp-status {{ border: 1px solid; border-radius: 10px; padding: 1px 7px;
                         font-size: 10px; font-weight: 600; white-space: nowrap; }}
          .grp-suites {{ display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 6px; }}
          .grp-chip {{ background: rgba(0,0,0,.07); border-radius: 4px;
                       padding: 2px 8px; font-size: 11px; }}
          pre.grp-detail {{ white-space: pre-wrap; word-break: break-word;
                            font-family: Consolas, monospace; font-size: 11px;
                            background: rgba(255,255,255,.7); padding: 8px;
                            border-radius: 4px; max-height: 220px; overflow-y: auto;
                            margin-top: 6px; border: 1px solid rgba(0,0,0,.1); }}

          /* Main suite table */
          table.main-table {{ width: 100%; border-collapse: collapse; }}
          table.main-table th {{ background: var(--primary); color: #fff; padding: 8px 10px; text-align: left; position: sticky; top: 0; z-index: 2; }}
          table.main-table td {{ border: 1px solid var(--border); padding: 8px 10px; vertical-align: top; }}
          table.main-table tr:hover td {{ background: #f5f9ff; }}
          td.center {{ text-align: center; }}
          td.status-cell {{ font-weight: 700; font-size: 13px; border-radius: 4px; }}

          /* Defect card */
          .defect-card {{ background: var(--card-bg); border: 1px solid #e0c0c0; border-radius: 6px;
                          padding: 10px 12px; margin: 6px 0; }}
          .defect-card.error {{ border-color: #ccc; color: #888; }}
          .defect-header {{ display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-bottom: 6px; }}
          .defect-id {{ font-weight: 700; font-size: 13px; }}
          .defect-status {{ padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }}
          .defect-priority, .defect-severity {{ font-size: 11px; color: #555; }}
          .defect-name {{ font-weight: 600; margin-bottom: 6px; }}
          table.defect-meta {{ width: 100%; border-collapse: collapse; font-size: 11px; }}
          table.defect-meta th {{ color: #555; text-align: left; padding: 2px 8px 2px 0; white-space: nowrap; width: 110px; }}
          table.defect-meta td {{ padding: 2px 0; word-break: break-word; }}
          pre.desc-pre {{ white-space: pre-wrap; word-break: break-word; font-family: Consolas, monospace;
                          font-size: 11px; background: #fff; padding: 8px; border: 1px solid #e0e0e0;
                          border-radius: 4px; max-height: 300px; overflow-y: auto; margin-top: 6px; }}
          details summary {{ cursor: pointer; color: var(--primary); font-size: 11px; margin-top: 4px; }}

          /* Test Run card */
          .tr-card {{ background: #f0f4fa; border: 1px solid #b0c4de; border-radius: 6px;
                      padding: 8px 12px; margin: 6px 0; }}
          .tr-card.error {{ border-color: #ccc; color: #888; }}
          .tr-header {{ font-size: 12px; display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }}
          .tr-result, .tr-runtime {{ font-size: 11px; color: #555; }}

          .na {{ color: #aaa; font-style: italic; }}
          .source-link {{ font-size: 11px; color: #888; }}

          @media print {{
            details {{ display: block; }}
            summary {{ display: none; }}
          }}
        </style>
        </head>
        <body>

        <h1>CRAFT Test Failure Analysis</h1>
        <p class="source-link">Source: <a href="{escape(summary_url)}" target="_blank">{escape(summary_url)}</a>
           &nbsp;|&nbsp; Generated: {escape(generated_at)}</p>

        <div class="meta-strip">
          <div class="meta-item"><span class="meta-label">Project</span><span class="meta-value">{escape(meta.get("project","N/A"))}</span></div>
          <div class="meta-item"><span class="meta-label">Build ID</span><span class="meta-value">{escape(meta.get("build_id","N/A"))}</span></div>
          <div class="meta-item"><span class="meta-label">Pipeline ID</span><span class="meta-value">{escape(meta.get("pipeline_id","N/A"))}</span></div>
          <div class="meta-item"><span class="meta-label">Date Generated</span><span class="meta-value">{escape(meta.get("date_generated","N/A"))}</span></div>
          <div class="meta-item"><span class="meta-label">Pass %</span><span class="meta-value">{escape(meta.get("pass_percentage","N/A"))}</span></div>
        </div>

        <div class="kpi-row">
          <div class="kpi kpi-fail"><div class="kpi-num">{total_fail}</div><div class="kpi-lbl">Failed Suites</div></div>
          <div class="kpi kpi-pass"><div class="kpi-num">{total_pass}</div><div class="kpi-lbl">Passed Suites</div></div>
          <div class="kpi kpi-defect"><div class="kpi-num">{len(unique_defects)}</div><div class="kpi-lbl">Unique Defects</div></div>
          <div class="kpi kpi-open"><div class="kpi-num">{open_defects}</div><div class="kpi-lbl">Open Defects</div></div>
        </div>

        <h2>Root-Cause Summary</h2>
        <p style="font-size:11px;color:#666;margin-bottom:10px">
          Failures classified by known error patterns. Each row links out to the affected suites and Codebeamer defects.
        </p>
        {rc_summary_html}

        <h2>Topic Summary</h2>
        <p style="font-size:11px;color:#666;margin-bottom:10px">
          Failures bucketed by gRPC topic name (from <code>@{{topics}}</code> in <code>Keyword_Common_API.robot</code>).
          A single failure may appear under more than one topic, or under <em>No Topic</em> if none matched.
        </p>
        {topic_summary_html}

        <h2>Failure Reason Summary</h2>
        <table class="reason-table">
          <thead><tr><th style="width:28%">Suite</th><th style="width:30%">Defect / Reason</th><th>Details</th></tr></thead>
          <tbody>{reason_rows_html}</tbody>
        </table>

        <h2>All Suite Results with Defect Details</h2>
        <table class="main-table">
          <thead>
            <tr>
              <th style="width:36px">#</th>
              <th>Suite</th>
              <th style="width:90px">Test Run</th>
              <th style="width:80px">Status</th>
              <th>Defects &amp; Details</th>
            </tr>
          </thead>
          <tbody>{suite_rows_html}</tbody>
        </table>

        </body>
        </html>
    """)


# ─────────────────────────────────────────────────────────────────────────────
# CLI entry point
# ─────────────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Fetch CRAFT test summary and enrich with Codebeamer defect details.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument("--summary-url", default=SUMMARY_URL_DEFAULT,
                   help="URL of the CRAFT HTML summary page")
    p.add_argument("--cb-url", default=CB_BASE_DEFAULT,
                   help="Codebeamer base URL")
    p.add_argument("--username", default="craft-runner",
                   help="Codebeamer username")
    p.add_argument("--password", default="craft-runner",
                   help="Codebeamer password")
    p.add_argument("--output", default=None,
                   help="Output HTML file path (default: Reports/RF/failure_analysis_<ts>.html)")
    p.add_argument("--no-browser", action="store_true",
                   help="Do not open the report in a browser")
    p.add_argument("--timeout", type=int, default=30,
                   help="HTTP timeout in seconds (default: 30)")
    p.add_argument("--skip-pass", action="store_true",
                   help="Skip CB API calls for PASS rows")
    p.add_argument("--learn", action="store_true",
                   help="Interactively confirm new pattern candidates found in 'Other' failures")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # ── Load learned patterns and inject before catch-all entries ────────────
    learned = load_learned_patterns()
    if learned:
        # Insert confirmed learned patterns just before the generic catch-all
        catchall_keys = {"setup_failed"}  # stay at the end
        insert_at = next(
            (i for i, (k, *_) in enumerate(KNOWN_PATTERNS) if k in catchall_keys),
            len(KNOWN_PATTERNS),
        )
        for entry in reversed(learned):
            if entry[0] not in {k for k, *_ in KNOWN_PATTERNS}:
                KNOWN_PATTERNS.insert(insert_at, entry)
        _rebuild_pattern_index()
        print(f"  Loaded {len(learned)} confirmed learned pattern(s) from {LEARNED_PATTERNS_FILE.name}")

    # ── Output path ──────────────────────────────────────────────────────────
    if args.output:
        output_path = Path(args.output)
    else:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = Path(__file__).resolve().parent.parent / "Reports" / "RF" / f"failure_analysis_{ts}.html"
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # ── Step 1: fetch summary page ───────────────────────────────────────────
    print(f"\n[1/4] Loading CRAFT summary page…")
    print(f"      {args.summary_url}")
    try:
        if args.summary_url.startswith(("http://", "https://")):
            resp = requests.get(args.summary_url, timeout=args.timeout, verify=False)
            resp.raise_for_status()
            summary_html = resp.text
        else:
            # Treat as a local filesystem path (or file:// URI)
            local = args.summary_url
            if local.startswith("file://"):
                local = local[7:]
            summary_html = Path(local).read_text(encoding="utf-8")
    except Exception as exc:
        sys.exit(f"ERROR loading summary page: {exc}")
    print(f"      OK ({len(summary_html):,} bytes)")

    # ── Step 2: parse ────────────────────────────────────────────────────────
    print("\n[2/4] Parsing summary table…")
    meta, rows = parse_summary_page(summary_html)
    fail_rows = [r for r in rows if r["status"].upper() != "PASS"]
    print(f"      {len(rows)} suites found  |  {len(fail_rows)} failures")
    print(f"      Build: {meta['build_id']}  Pipeline: {meta['pipeline_id']}")

    # ── Step 3: enrich via CB API ────────────────────────────────────────────
    print(f"\n[3/4] Querying Codebeamer ({args.cb_url})…")
    cb = CodebeamerClient(args.cb_url, args.username, args.password, args.timeout)
    enrich_rows(rows, cb, skip_pass=args.skip_pass)

    # ── Step 4: render report ────────────────────────────────────────────────
    print("\n[4/4] Rendering HTML report…")
    # Build failure_info for both the report AND candidate mining
    # (render_report builds it internally; we need it here too for proposal)
    from collections import defaultdict as _defaultdict
    _fi_scratch: list[dict] = []
    for r in rows:
        if r["status"].upper() == "PASS":
            continue
        _suite = r["suite_name"]
        _added = 0
        for d in r["defect_details"]:
            _conc = ""
            if "_error" in d and r["test_run_details"] and "_error" not in r["test_run_details"]:
                _conc = _clean_description(r["test_run_details"].get("conclusion") or "", max_chars=600)
            _detail = _conc or d.get("_error", "") if "_error" in d else _clean_description(d.get("description") or "", max_chars=600)
            _fi_scratch.append({"suite": _suite, "detail": _detail, "pattern_key": classify_pattern(_detail)})
            _added += 1
        if _added == 0 and r["test_run_details"] and "_error" not in r["test_run_details"]:
            _conc = _clean_description(r["test_run_details"].get("conclusion") or "", max_chars=600)
            _fi_scratch.append({"suite": _suite, "detail": _conc, "pattern_key": classify_pattern(_conc)})

    html = render_report(meta, rows, args.cb_url, args.summary_url, generated_at)
    output_path.write_text(html, encoding="utf-8")
    print(f"      Saved → {output_path}")

    # ── Pattern learning ─────────────────────────────────────────────────────
    print("\n[+] Checking for new pattern candidates…")
    propose_and_save_candidates(_fi_scratch, interactive=args.learn)

    if not args.no_browser:
        print("      Opening in browser…")
        webbrowser.open(output_path.as_uri())

    print("\nDone.\n")


if __name__ == "__main__":
    main()
