import re
import os
from datetime import datetime
from pathlib import Path
from typing import Optional
from string import Template


from robot.libraries.BuiltIn import BuiltIn
from robot.running.model import Keyword as ExecutableKeyword
from robot.result.model import Keyword as ResultKeyword
from robot.running.model import TestCase as ExecutableTestCase
from robot.result.model import TestCase as ResultTestCase
from robot.running.model import TestSuite as ExecutableTestSuite
from robot.result.model import TestSuite as ResultTestSuite


class TestCase:
    TEST_CASE_NAME_SEPARATOR = ":"

    def __init__(self, name: str, start: str, end: Optional[str], status: str, steps: list, source: str,
                 elapsed_time: str, tester_name: str):
        self.long_name = name
        self.id, self.name = self.get_data_from_name(self.long_name)
        self.start = start
        self.end = end
        self.status = status
        self.steps = steps
        self.source = source
        self.elapsed_time = elapsed_time
        self.tester_name = tester_name

    def render(self):
        footer = TestCaseFooter(self.status, self.elapsed_time)
        test_case_template = Report.load_template(Report.TEMPLATES_BASE_PATH / "test_case.html")
        return test_case_template.substitute(
            test_case_steps=Table(self.steps).render(),
            test_case_footer=footer.render()
        )

    def get_parent_folder(self) -> str:
        return Path(self.source).parent.name

    @staticmethod
    def get_data_from_name(test_case_name: str) -> tuple:
        if TestCase.TEST_CASE_NAME_SEPARATOR in test_case_name:
            test_case_id, test_case_name, *_ = test_case_name.split(TestCase.TEST_CASE_NAME_SEPARATOR)
        else:
            test_case_id = None
        return test_case_id, test_case_name


class TestCaseHeader:
    def __init__(self, name: str, long_name: str, test_case_id: str, test_folder: str, date: str, tester_name: str,
                 build_id: str = 'N/A', test_config: str = 'N/A'):
        self.test_case_name = name
        self.long_name = long_name
        self.test_case_id = test_case_id
        self.test_folder = test_folder
        self.date = date
        self.tester_name = tester_name
        self.build_id = build_id
        self.test_config = test_config

    def render(self) -> str:
        tc_header_template = Report.load_template(Report.TEMPLATES_BASE_PATH / "header_table.html")
        return tc_header_template.substitute(
            test_case_name=self.test_case_name,
            test_case_id=self.test_case_id,
            test_case_folder=self.test_folder,
            test_case_configuration=self.test_config,
            test_case_build_info=self.build_id,
            tester_name=self.tester_name,
            date_of_execution=self.get_test_case_date(True)
        )

    def get_test_case_name(self, should_be_long_name: bool) -> str:
        return self.long_name if should_be_long_name else self.test_case_name

    def get_test_case_id(self) -> str:
        return self.test_case_id if self.test_case_id is not None else 'N/A'

    def get_test_case_date(self, format_date: bool) -> str:
        timestamp = Report.format_timestamp(self.date)
        return self.date if not format_date else timestamp


class TestCaseFooter:
    def __init__(self, test_case_status: str, elapsed_time: str):
        self.test_case_status = test_case_status
        self.elapsed_time = elapsed_time

    def render(self):
        tc_footer_template = Report.load_template(Report.TEMPLATES_BASE_PATH / "test_case_footer.html")
        return tc_footer_template.substitute(
            status_class=self.test_case_status.lower(),
            test_case_status=self.test_case_status,
            elapsed_time=self.elapsed_time
        )


class Report:
    TEMPLATES_BASE_PATH = Path(__file__).resolve().parent / "templates"

    def __init__(self, suite_name="", tester_name: str = 'N/A', build_id: str = 'N/A', test_config: str = 'N/A'):
        self.suite_name = suite_name
        self.suite_setup = []
        self.suite_teardown = []
        self.tests = []
        self.tester_name = tester_name
        self.build_id = build_id
        self.test_config = test_config

    def add_suite_info(self, name):
        self.suite_name = name

    def add_test(self, test_data):
        self.tests.append(TestCase(tester_name=self.tester_name, **test_data))

    def render(self):
        base_template = self.load_template(self.TEMPLATES_BASE_PATH / "base.html")

        rendered_suite_setup = SuiteSection("Suite Setup", self.suite_setup).render() if self.suite_setup else ''
        rendered_test_section = self._render_test_section() if self.tests else ''
        rendered_suite_teardown = SuiteSection("Suite Teardown", self.suite_teardown).render() if self.suite_teardown else ''

        return base_template.substitute(
            report_title="Test Report",
            report_header=ReportHeader(self.suite_name, None, self.build_id, self.test_config).render(),
            suite_setup=rendered_suite_setup,
            test_cases=rendered_test_section,
            suite_teardown=rendered_suite_teardown
        )

    def _render_test_section(self):
        test_section_template = Report.load_template(Report.TEMPLATES_BASE_PATH / "test_section.html")
        rendered_tests: list[str] = []
        for test in self.tests:
            rendered_tests.append(test.render())
        return test_section_template.substitute(
            test_section_data='\n'.join(rendered_tests)
        )

    def render_single_test(self, test_obj: TestCase, include_suite_sections: bool = False, wrap_in_section: bool = False) -> str:
        base_template = self.load_template(self.TEMPLATES_BASE_PATH / "base.html")

        # Optional suite sections (default: off)
        rendered_suite_setup = SuiteSection("Suite Setup", self.suite_setup).render() if include_suite_sections else ''
        rendered_suite_teardown = SuiteSection("Suite Teardown",
                                               self.suite_teardown).render() if include_suite_sections else ''

        # Either wrap in your test_section.html or just drop the test directly
        if wrap_in_section:
            test_section_template = self.load_template(self.TEMPLATES_BASE_PATH / "test_section.html")
            test_block = test_section_template.substitute(test_section_data=test_obj.render())
        else:
            test_block = test_obj.render()

        return base_template.substitute(
            report_title="Test Case",
            report_header=ReportHeader(self.suite_name, test_obj, self.build_id, self.test_config).render(),
            suite_setup=rendered_suite_setup,
            test_cases=test_block,
            suite_teardown=rendered_suite_teardown
        )

    @staticmethod
    def load_template(file_path: Path) -> Template:
        return Template(file_path.read_text(encoding='utf-8'))

    @staticmethod
    def format_timestamp(timestamp: str, source_time_format: str = "%Y%m%d %H:%M:%S.%f") -> str:
        parsed_timestamp = datetime.strptime(timestamp, source_time_format)
        milliseconds = round(parsed_timestamp.microsecond / 1000)
        base_timestamp = parsed_timestamp.strftime("%m/%d/%Y %I:%M:%S")
        am_pm_part = parsed_timestamp.strftime("%p")  # Get AM or PM
        return f"{base_timestamp}.{milliseconds:03d} {am_pm_part}"


class ReportHeader:
    def __init__(self, suite_name: str, test_case_obj: TestCase, build_id: str = 'N/A', test_config: str = 'N/A'):
        self.suite_name = suite_name
        self.test_case = test_case_obj
        self.build_id = build_id
        self.test_config = test_config

    def render(self) -> str:
        report_header_template = Report.load_template(Report.TEMPLATES_BASE_PATH / "report_header.html")
        tc_header = TestCaseHeader(
            self.test_case.name, self.test_case.long_name, self.test_case.id,
            self.test_case.get_parent_folder(), self.test_case.start, self.test_case.tester_name,
            self.build_id, self.test_config
        )
        return report_header_template.substitute(
            test_case_name=self.test_case.name,
            test_case_header=tc_header.render()
        )


class SuiteSection:
    def __init__(self, title, steps):
        self.title = title
        self.steps = steps

    def render(self):
        if not self.steps:
            return ""
        suite_section_template = Report.load_template(Report.TEMPLATES_BASE_PATH / "suite_section.html")
        return suite_section_template.substitute(
            section_title=self.title,
            steps=Table(self.steps).render()
        )


class Table:
    def __init__(self, rows: list):
        self.rows = rows

    def render(self):
        rendered_rows: list[str] = []
        table_template = Report.load_template(Report.TEMPLATES_BASE_PATH / "table.html")
        row_template = Report.load_template(Report.TEMPLATES_BASE_PATH / "table_row.html")

        for r in self.rows:
            row_status: str = r.get('result_status')
            rendered_row = row_template.substitute(
                timestamp=r['timestamp'],
                step_description=r['step_description'],
                result_message=r['result_message'],
                result_status_class=row_status.lower() if row_status is not None else '',
                result_status=row_status if row_status is not None else 'N/A'
                )
            rendered_rows.append(rendered_row)

        return table_template.substitute(rows='\n'.join(rendered_rows))


class ReportListener:
    ROBOT_LIBRARY_SCOPE = "GLOBAL"
    ROBOT_LISTENER_API_VERSION = 3
    DATA_DRIVEN_TAG = "data_driven"

    def __init__(self, filename=None):
        self.filename = filename  # may still be None here
        self.fh = None
        self.report = None
        self._in_test_case = False
        self._is_data_driven_test = False
        self._in_suite_setup = False
        self._in_suite_teardown = False
        self._keyword_stack = []
        self._reports_dir = None
        self._test_counter = 0
        self._seen_filenames = set()

    def _safe_segment(self, s: Optional[str]) -> str:
        if s is None:
            return ""
        return re.sub(r'[^A-Za-z0-9._-]+', '_', str(s)).strip('_')

    def _test_filepath(self, test_obj: TestCase) -> str:
        if test_obj.id is not None:
            base = self._safe_segment(test_obj.id)
        else:
            base = f"{self._test_counter:03d}"

        filename = base + "_CR.html"
        path = os.path.join(self._reports_dir, filename)

        i = 1
        while os.path.exists(path) or filename in self._seen_filenames:
            filename = f"{base}_{i}_CR.html"
            path = os.path.join(self._reports_dir, filename)
            i += 1

        self._seen_filenames.add(filename)
        return path

    def _write_single_test_html(self, test_obj: TestCase):
        path = self._test_filepath(test_obj)
        html = self.report.render_single_test(test_obj, include_suite_sections=False, wrap_in_section=False)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        self._test_counter += 1

    def start_suite(self, data: ExecutableTestSuite, result: ResultTestSuite):
        self._in_suite_setup = False
        self._in_suite_teardown = False
        self.report = Report(
            tester_name=self.get_tester_name(),
            build_id=self.get_build_id(),
            test_config=self.get_test_config()
        )
        self.report.add_suite_info(result.name)

        # Get output dir dynamically now that Robot has initialized it
        output_dir = self._get_robot_output_dir()
        output_dir_path = Path(output_dir)

        # If the output dir ends with 'RF', go up one level and append 'CustomReports'
        if output_dir_path.name == 'RF':
            custom_reports_dir = output_dir_path.parent / 'CustomReports'
        else:
            custom_reports_dir = output_dir_path / 'CustomReports'

        custom_reports_dir.mkdir(parents=True, exist_ok=True)
        self._reports_dir = str(custom_reports_dir)

    def end_suite(self, data: ExecutableTestSuite, result: ResultTestSuite):
        return

    def start_test(self, data: ExecutableTestCase, result: ResultTestCase):
        current_test = {
            "name": result.name,
            "start": result.starttime,
            "steps": [],
            "status": result.status,
            "end": None,
            "elapsed_time": None,
            "source": result.source
        }
        self.report.add_test(current_test)
        self._is_data_driven_test = self.is_test_case_data_driven(result)
        self._in_test_case = True

    def end_test(self, data: ExecutableTestCase, result: ResultTestCase):
        if self.report.tests:
            t = self.report.tests[-1]
            t.end = result.endtime
            t.status = result.status
            t.elapsed_time = result.elapsed_time

            self._write_single_test_html(t)

        # mark end of test case
        self._in_test_case = False
        self._is_data_driven_test = False

    def start_keyword(self, data: ExecutableKeyword, result: ResultKeyword):
        self._keyword_stack.append(result)
        kw_type = result.type.lower()
        # Only set context if this is the root keyword for setup or teardown
        if kw_type == 'setup' and not self._in_test_case and len(self._keyword_stack) == 1:
            self._in_suite_setup = True
        elif kw_type == 'teardown' and not self._in_test_case and len(self._keyword_stack) == 1:
            self._in_suite_teardown = True

    def end_keyword(self, data: ExecutableKeyword, result: ResultKeyword):
        top_kw = self._keyword_stack[0]
        # we are processing keyword after it was executed - remove it from current keyword stack.
        self._pop_keyword_from_stack()

        kw_type = result.type.lower()
        kw_name = result.name
        kw_status = result.status

        # Process message to replace variables with actual values
        message = self._replace_variables(result.message or ', '.join([str(item) for item in result.args]) or '')

        if self.is_report_candidate(result, top_kw, message):
            if ( '<img src="data:image/png;base64,' in message):
                message = re.sub(r'(?:(?:,|;)\s*)?html\s*=\s*True\b', '', message, flags=re.IGNORECASE)
                kw_name = "Screenshot Captured"
                kw_status = None
            elif result.name == 'Document Keyword Outcome':
                builtIn = BuiltIn()
                message = builtIn.get_variable_value("\\${keyword_result_message}", default="") or message
                kw_status = builtIn.get_variable_value("\\${KEYWORD_STATUS}", default="")

                if result.parent.name == "Run Keywords":
                    kw_name = result.parent.parent.name
                else:
                    kw_name = result.parent.name

            step = self._form_step_data(kw_name, Report.format_timestamp(result.starttime), kw_name, message, kw_status)
            self._add_step_to_report(step)

        # if we are processing kw for teardown or setup - we finished it so set flags accordingly
        if kw_type == 'setup' and self._in_suite_setup:
            self._in_suite_setup = False
        elif kw_type == 'teardown' and self._in_suite_teardown:
            self._in_suite_teardown = False

    def is_report_candidate(self, result: ResultKeyword, top_kw: ResultKeyword, message) -> bool:
        """Determines if current keyword depending on context should be included in the report.

        Returns:
            bool:  `True` if keyword should be included in the report, `False` otherwise.
        """
        if result.name == "Document Keyword Outcome":
            # Check if current test case ID is in the parent keyword's tags
            if self._in_test_case and self.report.tests:
                current_test_id = self.report.tests[-1].id
                if current_test_id and result.parent and result.parent.tags:
                    # Extract tc_id from tags (format: "tc_id=step_number")
                    tag_test_ids = [tag.split('=')[0] for tag in result.parent.tags if '=' in tag]
                    if current_test_id not in tag_test_ids:
                        return False
            return True
        elif result.status != 'FAIL':
            # first, skip keywords which were not run
            if result.status.lower() == 'not run':
                return False

            if '<img src="data:image/png;base64,' in message:
                return True

            # Skip other deeply nested keywords unless allowed
            if self._has_kw_type_ancestor(result, 'keyword') and not self._is_data_driven_test:
                return False
        elif result.name == "Fail":
            return False
        else:
            return False

    @staticmethod
    def get_tester_name() -> str:
        builtin = BuiltIn()
        return builtin.get_variable_value(name="\\${TESTER_NAME}", default='N/A')

    @staticmethod
    def get_build_id() -> str:
        builtin = BuiltIn()
        return builtin.get_variable_value(name="\\${BUILD_ID}", default='N/A')

    @staticmethod
    def get_test_config() -> str:
        builtin = BuiltIn()
        return builtin.get_variable_value(name="\\${test_config}", default='N/A')

    @staticmethod
    def is_test_case_data_driven(result: ResultTestCase) -> bool:
        return ReportListener.DATA_DRIVEN_TAG in result.tags

    @staticmethod
    def _form_step_data(kw_name: str, start_time: str, step_description: str, result_message: str, result_status: str) -> dict:
        # Only suppress status if it's a generic Log statement with no real result
        if kw_name == "Log" and not step_description.startswith("Verification Passed:"):
            result_status = None
        return dict(timestamp=start_time, step_description=step_description, result_message=result_message,
                    result_status=result_status)

    def _add_step_to_report(self, step: dict):
        if self._in_suite_setup:
            self.report.suite_setup.append(step)
        elif self._in_suite_teardown:
            self.report.suite_teardown.append(step)
        elif self._in_test_case:
            self.report.tests[-1].steps.append(step)

    def _pop_keyword_from_stack(self):
        if self._keyword_stack:
            self._keyword_stack.pop()

    @staticmethod
    def _replace_variables(message):
        """Replace variable references with their actual values"""
        # This simplified implementation uses Robot's built-in variable access
        try:
            # Access Robot Framework's variables
            builtin = BuiltIn()

            # Replace variables in pattern ${var} and @{list} with their values
            def replace_var(match):
                var_name = match.group(1)
                try:
                    return str(builtin.get_variable_value(f"${{{var_name}}}"))
                except:
                    return match.group(0)

            res = re.sub(r'\$\{([^}]+)\}', replace_var, message)
            return res
        except:
            return message

    @staticmethod
    def _has_kw_type_ancestor(result, kw_type: str):
        parent = result.parent
        while parent:
            parent_type = getattr(parent, 'type', '').lower()
            if parent_type == kw_type.lower():
                return True
            parent = getattr(parent, 'parent', None)
        return False

    def _get_robot_output_dir(self):
        try:
            builtin = BuiltIn()
            return builtin.get_variable_value("${OUTPUTDIR}", default=".")
        except:
            return "."
