import argparse
from datetime import datetime
from html import escape
from pathlib import Path
from string import Template


class Summary:
    ROBOT_LISTENER_API_VERSION = 3
    ROBOT_LIBRARY_SCOPE = "SUITE"
    ROBOT_LIBRARY_VERSION = "1.0"

    def __init__(self, results_path: str | None = None, output_path: str | None = None, build_id: str | None = None, pipeline_id: str | None = None, pages_url: str | None = None, custom_report_index: str | None = None):
        self.project_root = Path(__file__).resolve().parent.parent
        self.templates_base_path = self.project_root / "Tools" / "LogManager" / "templates"
        self.results_path = self._resolve_path(results_path or "Reports/RF/results.txt")
        self.output_path = self._resolve_path(output_path or "Reports/RF/summary.html")
        self.build_id = build_id or "N/A"
        self.pipeline_id = pipeline_id or "N/A"
        self.pages_url = (pages_url or "").rstrip("/")
        self.custom_report_index_path = self._resolve_path(custom_report_index or "Reports/RF/custom_report_index.csv")
        self._row_template = self.load_template(self.templates_base_path / "summary_row.html")
        self._report_template = self.load_template(self.templates_base_path / "summary_report.html")

    @staticmethod
    def load_template(file_path: Path) -> Template:
        return Template(file_path.read_text(encoding="utf-8"))

    def _resolve_path(self, path_value: str) -> Path:
        path = Path(path_value)
        if path.is_absolute():
            return path
        return self.project_root / path

    def _parse_results(self) -> list[dict[str, str]]:
        if not self.results_path.exists():
            return []

        custom_report_index = self._load_custom_report_index()
        parsed_results: list[dict[str, str]] = []
        for line_number, raw_line in enumerate(self.results_path.read_text(encoding="utf-8").splitlines(), start=1):
            line = raw_line.strip()
            if not line:
                continue

            parts = [part.strip() for part in raw_line.split(",", 3)]
            if len(parts) < 3:
                parsed_results.append({
                    "row_number": str(line_number),
                    "suite": "Malformed Entry",
                    "test_case_id": "N/A",
                    "cb_url": "",
                    "status": "INVALID",
                    "status_class": "fail",
                    "defect_ids": escape(line),
                    "custom_report_links": "N/A",
                })
                continue

            suite_name, test_run_id, raw_status = parts[:3]
            defects_raw = parts[3] if len(parts) == 4 else ""
            cr_filenames = custom_report_index.get(suite_name.strip(), [])
            parsed_results.append({
                "row_number": str(len(parsed_results) + 1),
                "suite": escape(suite_name or "N/A"),
                "test_case_id": escape(test_run_id or "N/A"),
                "cb_url": self._build_codebeamer_url(test_run_id),
                "test_run_link": self._render_test_run_link(test_run_id),
                "status": escape(raw_status or "N/A"),
                "status_class": self._status_class(raw_status),
                "defect_ids": self._render_defect_ids(defects_raw),
                "custom_report_links": self._render_custom_report_links(cr_filenames),
            })

        return parsed_results

    def _load_custom_report_index(self) -> dict[str, list[str]]:
        """Returns a dict mapping suite_name -> list of custom report filenames."""
        index: dict[str, list[str]] = {}
        if not self.custom_report_index_path.exists():
            return index
        for line in self.custom_report_index_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            parts = line.split(",", 1)
            if len(parts) != 2:
                continue
            suite_name, filename = parts[0].strip(), parts[1].strip()
            index.setdefault(suite_name, []).append(filename)
        return index

    def _render_custom_report_links(self, filenames: list[str]) -> str:
        if not filenames or not self.pages_url:
            return "N/A"
        links = [
            f'<a href="{self.pages_url}/CustomReports/{fn}" target="_blank">{fn}</a>'
            for fn in filenames
        ]
        return "<br/>".join(links)

    @staticmethod
    def _build_codebeamer_url(item_id: str) -> str:
        cleaned_item_id = (item_id or "").strip()
        if not cleaned_item_id or cleaned_item_id.lower() == "none":
            return ""
        return f"https://crdn.codebeamer.com/item/{cleaned_item_id}"

    def _render_test_run_link(self, item_id: str) -> str:
        cleaned_item_id = escape((item_id or "").strip() or "N/A")
        item_url = self._build_codebeamer_url(item_id)
        if not item_url:
            return cleaned_item_id
        return f'<a href="{item_url}" target="_blank">{cleaned_item_id}</a>'

    @staticmethod
    def _status_class(status: str) -> str:
        normalized_status = (status or "").strip().upper()
        if normalized_status == "PASS":
            return "pass"
        if normalized_status in {"SKIP", "SKIPPED"}:
            return "skipped"
        return "fail"

    def _render_failure_analysis_link(self) -> str:
        if not self.pages_url:
            return "N/A"
        url = f"{self.pages_url}/Latest_CRAFT_Failure_Analysis.html"
        return f'<a href="{url}" target="_blank">Latest CRAFT Failure Analysis</a>'

    def _render_pipeline_id(self, pipeline_id: str) -> str:
        cleaned = (pipeline_id or "").strip()
        if not cleaned or cleaned.upper() == "N/A" or cleaned.lower() == "notapplicable":
            return escape(cleaned or "N/A")
        url = f"https://code.medtronic.com/crdn/aurora/artf/-/pipelines/{escape(cleaned)}"
        return f'<a href="{url}" target="_blank">{escape(cleaned)}</a>'

    def _render_defect_ids(self, defects_raw: str) -> str:
        cleaned_value = (defects_raw or "").strip()
        if not cleaned_value:
            return "N/A"

        rendered_items: list[str] = []
        for defect_entry in cleaned_value.split("|"):
            entry = defect_entry.strip()
            if not entry:
                continue

            if ":" in entry:
                test_case_id, defect_id = [part.strip() for part in entry.split(":", 1)]
                defect_link = self._build_codebeamer_url(defect_id)
                escaped_defect_id = escape(defect_id or "N/A")
                escaped_test_case_id = escape(test_case_id or "N/A")
                label = f"{escaped_defect_id} (TC {escaped_test_case_id})"
                if defect_link:
                    rendered_items.append(f'<a href="{defect_link}" target="_blank">{label}</a>')
                else:
                    rendered_items.append(label)
                continue

            rendered_items.append(escape(entry))

        return "<br/>".join(rendered_items) if rendered_items else "N/A"

    def _render_rows(self, parsed_results: list[dict[str, str]]) -> str:
        if not parsed_results:
            return (
                '<tr><td colspan="6" style="text-align:center; color:#666;">'
                'No test results were found in Reports/RF/results.txt.'
                '</td></tr>'
            )

        rendered_rows: list[str] = []
        for parsed_result in parsed_results:
            rendered_rows.append(self._row_template.substitute(**parsed_result))
        return "\n".join(rendered_rows)

    @staticmethod
    def _count_results(parsed_results: list[dict[str, str]]) -> dict[str, int]:
        counts = {
            "total": len(parsed_results),
            "pass": 0,
            "fail": 0,
            "skipped": 0,
            "suite_setup_failures": 0,
        }

        for parsed_result in parsed_results:
            status = parsed_result["status"].upper()
            if status == "PASS":
                counts["pass"] += 1
            elif status in {"SKIP", "SKIPPED"}:
                counts["skipped"] += 1
            else:
                counts["fail"] += 1
                if status.endswith("-SS"):
                    counts["suite_setup_failures"] += 1

        return counts

    def generate_report(self) -> Path:
        parsed_results = self._parse_results()
        counts = self._count_results(parsed_results)
        pass_percent_value = (counts["pass"] / counts["total"] * 100) if counts["total"] else 0.0
        pass_percentage = f"{pass_percent_value:.2f}%"

        if pass_percent_value > 90:
            pass_percentage_class = "pass-percent-high"
        elif pass_percent_value >= 70:
            pass_percentage_class = "pass-percent-medium"
        else:
            pass_percentage_class = "pass-percent-low"

        html = self._report_template.substitute(
            report_date=datetime.now().strftime("%m/%d/%Y %I:%M:%S %p"),
            build_id=self.build_id,
            pipeline_id=self._render_pipeline_id(self.pipeline_id),
            pass_percentage=pass_percentage,
            pass_percentage_class=pass_percentage_class,
            total_count=counts["total"],
            pass_count=counts["pass"],
            fail_count=counts["fail"],
            skipped_count=counts["skipped"],
            suite_setup_failure_count=counts["suite_setup_failures"],
            rows=self._render_rows(parsed_results),
            failure_analysis_link=self._render_failure_analysis_link(),
        )

        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        self.output_path.write_text(html, encoding="utf-8")
        return self.output_path

    def close(self):
        self.generate_report()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate CRAFT Test Execution Summary Report")
    parser.add_argument("--results-path", default=None, help="Path to results.txt")
    parser.add_argument("--output-path", default=None, help="Path for the output HTML report")
    parser.add_argument("--build-id", default=None, help="CI/CD Build ID")
    parser.add_argument("--pipeline-id", default=None, help="CI/CD Pipeline ID")
    parser.add_argument("--pages-url", default=None, help="GitLab Pages base URL for custom report links")
    parser.add_argument("--custom-report-index", default=None, help="Path to custom_report_index.csv")
    args = parser.parse_args()
    Summary(
        results_path=args.results_path,
        output_path=args.output_path,
        build_id=args.build_id,
        pipeline_id=args.pipeline_id,
        pages_url=args.pages_url,
        custom_report_index=args.custom_report_index,
    ).generate_report()
