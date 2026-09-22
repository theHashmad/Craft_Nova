# from robot.api import Listener
# from robot.result import ForLoop
from robot.libraries.BuiltIn import BuiltIn
from datetime import datetime, date
from pathlib import Path
from string import Template
import requests
from requests.auth import HTTPBasicAuth
import json
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class Traceability:
    ROBOT_LISTENER_API_VERSION = 3
    ROBOT_LIBRARY_SCOPE = "SUITE"
    ROBOT_LIBRARY_VERSION = "1.0"
    TEMPLATES_BASE_PATH = Path("Tools/LogManager/templates")

    def __init__(self):
        self._rendered_rows = []
        self._row_counter = 0
        self._row_template = None
        self._session = None

    @staticmethod
    def load_template(file_path: Path) -> Template:
        return Template(file_path.read_text(encoding='utf-8'))

    def _build_cb_folder_path(self, session, cb_testcaseId):
        path = ""
        parent = ""
        tcID = cb_testcaseId
        while parent is not None:
            url = "https://crdn.codebeamer.com/rest/v3/items/" + str(tcID) + "/"
            response = session.get(url)
            parent = response.json().get("parent")
            if parent is not None:
                tcID = parent.get("id")
            path = "/" + response.json().get("name") + path
        return path

    def start_suite(self, data, result):
        # Initialise session and row template only once across all suites
        if self._session is None:
            self._session = requests.session()
            self._session.verify = False
            self._session.auth = HTTPBasicAuth("karvec2", "karvec2")

        if self._row_template is None:
            self._row_template = self.load_template(self.TEMPLATES_BASE_PATH / "traceability_row.html")

        suiteType = 'normal'
        testDataPath = 'N/A'
        if data.metadata:
            if 'datadriven' in data.metadata.get("Type", ""):
                suiteType = 'datadriven'
                libInstance = BuiltIn().get_library_instance('DataDriver')
                libArgs = getattr(libInstance, 'reader_config', None)
                testDataPath = getattr(libArgs, 'file', None)

        for test in data.tests:
            self._row_counter += 1
            cb_testcaseId = test.name.split(':')[0].strip()
            test_script_full_path = str(test.parent.source)
            index = test_script_full_path.rfind("Test_Cases")
            test_script_path = test_script_full_path[index:]

            folder_path = self._build_cb_folder_path(self._session, cb_testcaseId)
            cb_url = "https://crdn.codebeamer.com/item/" + str(cb_testcaseId)
            tags = ", ".join(str(t) for t in test.tags) if test.tags else "N/A"

            # Append to legacy text file
            with open("traceability.txt", "a") as f:
                f.write(f"{cb_testcaseId}\t{suiteType}\t{testDataPath}\t{test_script_path}\t{cb_url}\t{folder_path}\n")

            # Accumulate HTML row
            self._rendered_rows.append(self._row_template.substitute(
                row_number=self._row_counter,
                test_case_id=cb_testcaseId,
                suite_type=suiteType,
                test_data_path=testDataPath,
                test_script_path=test_script_path,
                cb_url=cb_url,
                folder_path=folder_path,
                tags=tags
            ))

    def close(self):
        """Called once by Robot Framework when execution ends — writes the final HTML report."""
        if not self._rendered_rows:
            return
        report_template = self.load_template(self.TEMPLATES_BASE_PATH / "traceability_report.html")
        html = report_template.substitute(
            report_date=datetime.now().strftime("%m/%d/%Y %I:%M:%S %p"),
            rows='\n'.join(self._rendered_rows)
        )
        with open("traceability.html", "w", encoding="utf-8") as f:
            f.write(html)
                