# from robot.api import Listener
# from robot.result import ForLoop
from email.mime import text

from robot.libraries.BuiltIn import BuiltIn
from datetime import datetime,date
import collections
import os
import re
from pathlib import Path
from string import Template
import requests
from requests.auth import HTTPBasicAuth
import json
import re
import urllib3
import io
import zipfile
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
 

class StepResult:
    ROBOT_LISTENER_API_VERSION = 3
    ROBOT_LIBRARY_SCOPE = "SUITE"
    ROBOT_LIBRARY_VERSION = "1.0"
    TEMPLATES_BASE_PATH = Path("Tools/LogManager/templates")

    def __init__(self):
        if BuiltIn().get_variable_value("${cbEnabled}").lower() == 'true':
            self.ROBOT_LIBRARY_LISTENER = self
            self.templateName = None
            self.current_test_name = None
            self._html_steps = []
            self._reports_dir = None
            self._test_start_time = None
            self._test_source = None
            self._test_counter = 0
            self._seen_filenames = set()
            self._dd_html_steps = {}

    @staticmethod
    def strip_style_markup(text):
        """Removes CodeBeamer style markup %%(...) and decodes wiki escape sequences to HTML"""
        # Remove %%(color:...;) style markup
        cleaned = re.sub(r'%%\(.*?;\)', '', text)
        # Remove trailing %! markers
        cleaned = re.sub(r'%!', '', cleaned)
        # Decode CodeBeamer tilde-escaped special characters
        cleaned = cleaned.replace('~{', '{').replace('~}', '}')
        cleaned = cleaned.replace('~[', '[').replace('~]', ']')
        cleaned = cleaned.replace('~,', ',').replace('~|', '|')
        cleaned = cleaned.replace('~%', '%')
        # Convert CodeBeamer line breaks (\\ ) to HTML <br>
        cleaned = re.sub(r'\\\\\s*', '<br>', cleaned)
        # Strip CodeBeamer inline formatting markers (bold __, italic '', strikethrough --)
        cleaned = re.sub(r'__(.*?)__', r'\1', cleaned)
        cleaned = re.sub(r"''(.*?)''", r'\1', cleaned)
        cleaned = re.sub(r'--(.*?)--', r'\1', cleaned)
        # Strip CodeBeamer table/plugin markup [{Tag attr='...' | ... }]
        cleaned = re.sub(r'\[\{[^|]*\|', '', cleaned, flags=re.DOTALL)
        cleaned = re.sub(r'\}\]', '', cleaned)
        return cleaned.strip()

    @staticmethod
    def _strip_image_html(text):
        """Remove <img ...> tags entirely from message text.
        Used for CodeBeamer step results and console output."""
        return re.sub(r'<img\b[^>]*/?>',  '', text, flags=re.IGNORECASE | re.DOTALL).strip()

    def strip_image_markup(self, text):
        """Public Robot keyword: strips both <img> HTML tags and [{Image src='...'}] CB wiki markup
        from a string. Use this for any CodeBeamer plain-text field (bug description, conclusion, etc.)
        where image markup cannot be rendered."""
        text = str(text)
        # Strip HTML <img> tags
        text = re.sub(r'<img\b[^>]*/?>',  '', text, flags=re.IGNORECASE | re.DOTALL)
        # Strip CodeBeamer JSPWiki [{Image src='...'}] plugin markup
        text = re.sub(r"\[\{Image src='[^']*'\}\]", '', text, flags=re.IGNORECASE)
        return text.strip()

    def extract_image_for_upload(self, text):
        """Public Robot keyword: extracts the LAST base64 image embedded in text.
        ${value}[4] is the full list of all step results as a string, so there may be
        multiple images (one per step). Using findall and taking [-1] ensures we always
        upload the most recent screenshot rather than the first one.
        Searches for both CB [{Image src='data:...'}] wiki markup (stored in TCResults)
        and HTML <img src="data:..."> tags.
        Returns a (filename, bytes, mime_type) tuple suitable for the RequestsLibrary
        'files' parameter in a multipart POST, or None if no image is found."""
        import base64 as _base64
        text = str(text)
        # Try CB wiki Image plugin syntax first — that's what's stored in TCResults/step logs
        matches = re.findall(
            r"\[\{Image src='data:([^;']+);base64,([A-Za-z0-9+/=\s]+)'\}\]",
            text, re.IGNORECASE
        )
        if not matches:
            # Fall back to HTML <img src="data:..."> format
            matches = re.findall(
                r'<img\b[^>]*src=[\'"]data:([^;]+);base64,([A-Za-z0-9+/=\s]+)[\'"]',
                text, re.IGNORECASE | re.DOTALL
            )
        if not matches:
            return None
        # Take the last match — most recent screenshot in the step results list
        mime_type, b64_data = matches[-1]
        mime_type = mime_type.strip()
        b64_data = re.sub(r'\s+', '', b64_data)               # strip any whitespace/newlines
        image_bytes = _base64.b64decode(b64_data)
        ext = mime_type.split('/')[-1]                        # e.g. 'png'
        return (f'screenshot.{ext}', image_bytes, mime_type)

    def create_zip_attachment(self, report_path, filename):
        """Return a CodeBeamer-compatible ZIP attachment containing an HTML report."""
        report_file = Path(report_path)
        with io.BytesIO() as archive_buffer:
            with zipfile.ZipFile(archive_buffer, "w", zipfile.ZIP_DEFLATED) as archive:
                archive.write(report_file, arcname=report_file.name)
            return (filename, archive_buffer.getvalue(), "application/zip")

    @staticmethod
    def _normalize_html_message(text):
        """Ensure every <img> tag starts on its own line in the HTML report.
        Inserts a <br> before any <img> that is preceded by non-whitespace text,
        preventing the image from rendering inline in the middle of a sentence."""
        return re.sub(r'(\S)(\s*)(<img\b)', r'\1<br>\3', text, flags=re.IGNORECASE | re.DOTALL)

    @staticmethod
    def _html_img_to_cb_wiki(text):
        """Convert <img src="..."> HTML tags to CodeBeamer JSPWiki [{Image src='...'}] plugin format.
        The Image plugin is built-in to JSPWiki and supports data: URIs, so no server-side plugin
        installation is required."""
        def _replace(m):
            # Extract the src attribute value from the <img> tag
            src_match = re.search(r'src=[\'"]([^\'"]*)[\'"]', m.group(0), re.IGNORECASE)
            if src_match:
                src = src_match.group(1)
                return "[{{Image src='{}'}}]".format(src)
            # Fallback: strip the tag if src can't be extracted
            return ''
        return re.sub(r'<img\b[^>]*/?>',  _replace, text, flags=re.IGNORECASE | re.DOTALL).strip()

    @staticmethod
    def getCBPath(tcID,stepIndex):
        username="karvec2"
        password="karvec2"
        session=requests.session()
        session.verify=False
        session.auth=HTTPBasicAuth(username,password)
        url="https://crdn.codebeamer.com/rest/v3/items/"+str(tcID)+"/"
        response=session.get(url)
        step_entry = response.json().get("customFields")[-1].get("values")[stepIndex - 1]
        step_text = StepResult.strip_style_markup(step_entry[0]["value"]) if len(step_entry) > 0 else ''
        expected_result = StepResult.strip_style_markup(step_entry[1]["value"]) if len(step_entry) > 1 else ''
        return {'step_text': step_text, 'expected_result': expected_result}

    def start_test(self,data,result):
        tcInstanceCount=1
        BuiltIn().set_suite_variable("${tmpTCInstance}",tcInstanceCount)
        print(data.name)
        print("Datadriver Keyword Name:",data.template)
        totaltests=BuiltIn().get_variable_value("${totalTCs}")
        print("Total Tests in Suite:",totaltests)
        self.templateName=data.template        
        tmpFileName=data.name.split(':')
        BuiltIn().set_suite_variable("${tmpTCID}",tmpFileName[0])
        BuiltIn().set_suite_variable("${dataTCName}",data.name)
        BuiltIn().set_suite_variable("${TCResults}",[])
        self.current_test_name=data.name
        print(data.tags)
        self.keyword_counts = collections.defaultdict(int)
        tmptime = datetime.today()
        time=int(tmptime.timestamp())
        BuiltIn().set_suite_variable("${start_time}",time)
        self._html_steps = []
        self._test_start_time = result.starttime
        self._test_source = str(data.source) if hasattr(data, 'source') and data.source else ''


    def end_test(self, data, result):
        suiteType=BuiltIn().get_variable_value("${SuiteType}")
        if suiteType == 'datadriven':
            tmpTCResult=BuiltIn().get_variable_value("${TCResults}")
            tmpSuiteResult=BuiltIn().get_variable_value("${tmpStepResult}")
            tmpSuiteResult.append(tmpTCResult)
            BuiltIn().set_suite_variable("${tmpStepResult}",tmpSuiteResult)
            tmpSuiteResult=BuiltIn().get_variable_value("${tmpStepResult}")
            # Accumulate steps per TC ID - file written once in end_suite
            tc_id = data.name.split(':')[0].strip() if ':' in data.name else data.name
            if tc_id not in self._dd_html_steps:
                self._dd_html_steps[tc_id] = {
                    'steps': [],
                    'data': data,
                    'start_time': self._test_start_time,
                    'source': self._test_source,
                    'status': 'PASS',
                }
            # Renumber steps so each data row continues from the last row's steps
            offset = len(self._dd_html_steps[tc_id]['steps'])
            for s in self._html_steps:
                step_copy = dict(s)
                step_copy['step'] = offset + s['step']
                self._dd_html_steps[tc_id]['steps'].append(step_copy)
            if result.status == 'FAIL':
                self._dd_html_steps[tc_id]['status'] = 'FAIL'
        else:
            self._write_step_html_report(data, result)

    


    def start_user_keyword(self, name, attrs,result):
        # Only count keywords within the current test case
        temp_parent = name.parent
        parent_tags = getattr(temp_parent, 'tags', [])
        matching_elements = [item for item in attrs.tags if 'datadriven' in item]
        if matching_elements:
            print("\nSkip counting occurances of Keywords in Test Case for Data Driven tests..")
        else:
            if self.current_test_name:
                if attrs.tags:
                    if attrs.tags != 'teardown' and ('USER KEYWORD' not in name.parent.type or 'datadriven' in parent_tags): 
                        self.keyword_counts[name.name] += 1

    def end_user_keyword(self, name, attrs,result):
        if 'IF' in attrs.parent.type or 'ELSE IF' in attrs.parent.type or 'ELSE' in attrs.parent.type:
            if 'NOT RUN' in result.parent.status:
                #print("\nSkipping part of IF block that is not executed..also reverting keyword count for keywords in this block..")
                self.keyword_counts[name.name] -= 1
                return
        while name.parent.type is not None and 'Keyword' in name.parent.type:
            if name.type is not None and ('SETUP' in name.type or 'TEARDOWN' in name.type):
                return
            name=name.parent

        if attrs.tags is not None and ('Codebeamer' in attrs.tags or name==self.templateName):
            return
        else:
            suiteType=BuiltIn().get_variable_value("${SuiteType}")
            try:
                if suiteType == 'datadriven':
                    if attrs.tags is not None and "internal" not in attrs.tags:
                        tmpName=name.name
                        print(name.name)
                        pTCID=BuiltIn().get_variable_value("${tmpTCID}")
                        matching_elements = [item for item in attrs.tags if pTCID in item]
                        if matching_elements:
                            getTCStepData=  (matching_elements[0]).split('=')
                            tmpSteps=(getTCStepData[1]).split(',')
                            tmpStepsInt=[int(s) for s in tmpSteps]
                            tmpStepsInt.sort()
                            tmpCount = self.keyword_counts.get(tmpName)
                            step=tmpStepsInt[tmpCount-1]
                            timestamp = result.endtime.split('.')
                            format_string="%Y%m%d %H:%M:%S"
                            timestamp = datetime.strptime(timestamp[0],format_string)
                            newTime=timestamp.isoformat()
                            TCResults = BuiltIn().get_variable_value("${TCResults}")
                            tmpmsg = BuiltIn().get_variable_value("${keyword_result_message}")
                            if tmpmsg is None:
                                tmpmsg = ""
                            # Use JSPWiki Image plugin (built-in) to embed image in CB; HTML report keeps raw <img>
                            cb_msg = StepResult._html_img_to_cb_wiki(tmpmsg)
                            # tmpResultDict= {"Step-"+str(step):result.status+"|"+newTime+"|"+tmpmsg+ "|"+name.name}
                            tmpResultDict= result.status+"|"+newTime+"|"+cb_msg+"|"+name.name
                            TCResults.append(tmpResultDict)
                            BuiltIn().set_suite_variable("${TCResults}",TCResults)
                            self._html_steps.append({
                                'step': step,
                                'keyword_name': tmpName,
                                'timestamp': newTime,
                                'message': StepResult._normalize_html_message(tmpmsg),
                                'status': result.status
                            })

                else:
                    if name.name is not None and "Codebeamer" not in name.name and attrs.tags is not None and  "internal" not in attrs.tags:
                        if 'SETUP' not in name.type and 'SETUP' not in name.parent.type and 'TEARDOWN' not in name.type and 'TEARDOWN' not in name.parent.type and 'USER KEYWORD' not in name.parent.type:
                            tmpName=name.name
                            pTCID=BuiltIn().get_variable_value("${tmpTCID}")
                            matching_elements = [item for item in attrs.tags if pTCID in item]
                            if matching_elements:
                                getTCStepData=  (matching_elements[0]).split('=')
                                tmpTCID=getTCStepData[0]
                                tmpSteps=(getTCStepData[1]).split(',')
                                tmpStepsInt=[int(s) for s in tmpSteps]
                                tmpStepsInt.sort()
                                tmpCount = self.keyword_counts.get(tmpName)
                                step=tmpStepsInt[tmpCount-1]
                                if tmpCount > len(tmpStepsInt):
                                    print("\nKeyword is used multiple times in Test Case. Number of steps in tags are lesser..skipping result as Step Number not known..")
                                else:
                                    timestamp = result.endtime.split('.')
                                    format_string="%Y%m%d %H:%M:%S"
                                    timestamp = datetime.strptime(timestamp[0],format_string)
                                    newTime=timestamp.isoformat()
                                    # self.fh.write(f"{tmpTCID}|{step}|{result.status}|{newTime}\n")
                                    TCResults = BuiltIn().get_variable_value("${TCResults}")
                                    tmpmsg = BuiltIn().get_variable_value("${keyword_result_message}")
                                    if tmpmsg is None:
                                        tmpmsg = ""
                                    # Use JSPWiki Image plugin (built-in) to embed image in CB; HTML report keeps raw <img>
                                    cb_msg = StepResult._html_img_to_cb_wiki(tmpmsg)
                                    tmpResultDict= {"Step-"+str(step):result.status+"|"+newTime+"|"+cb_msg}
                                    # tmpResultDict= {"Step-"+str(step):result.status+"|"+newTime+"|"+result.message}
                                    tmpResultList = [tmpTCID,tmpResultDict]
                                    console_msg = StepResult._strip_image_html(tmpmsg)
                                    print([tmpTCID, {"Step-"+str(step): result.status+"|"+newTime+"|"+console_msg}])
                                    print(StepResult._strip_image_html(result.message) if result.message else '')
                                    TCResults.append(tmpResultList)
                                    BuiltIn().set_suite_variable("${TCResults}",TCResults)
                                    BuiltIn().set_suite_variable("${keyword_result_message}","")
                                    self._html_steps.append({
                                        'step': step,
                                        'keyword_name': tmpName,
                                        'timestamp': newTime,
                                        'message': StepResult._normalize_html_message(tmpmsg),
                                        'status': result.status
                                    })
            except TypeError as e:
                print(f"Skipping result due to unexpected Tag for: {name.name}, error: {e}")
                return

    
    def start_suite(self, name, result):
        BuiltIn().set_suite_variable("${SuiteType}",'normal')

        if self._reports_dir is None:
            output_dir = self._get_robot_output_dir()
            output_dir_path = Path(output_dir)
            if output_dir_path.name == 'RF':
                custom_reports_dir = output_dir_path.parent / 'CustomReports'
            else:
                custom_reports_dir = output_dir_path / 'CustomReports'
            custom_reports_dir.mkdir(parents=True, exist_ok=True)
            self._reports_dir = str(custom_reports_dir)

        if name.metadata:
            if 'datadriven' in name.metadata["Type"]:
                print("\n\n\nDatadriven Suite Identified")
                testSteps=name.metadata["Steps"]

                BuiltIn().set_suite_variable("${tmpStepResult}",[])
                BuiltIn().set_suite_variable("${SuiteType}",'datadriven')
                BuiltIn().set_suite_variable("${TotalSteps}",testSteps)

        # else:
        #     BuiltIn().set_suite_variable("${SuiteType}",'normal')

    def end_suite(self, name, result):
        for tc_id, acc in self._dd_html_steps.items():
            self._write_step_html_report(
                acc['data'], None,
                steps_override=acc['steps'],
                status_override=acc['status'],
                elapsed_override='N/A',
                start_time_override=acc['start_time'],
                source_override=acc['source']
            )
        self._dd_html_steps.clear()

    def _get_robot_output_dir(self) -> str:
        try:
            return BuiltIn().get_variable_value("${OUTPUTDIR}", default=".")
        except Exception:
            return "."

    def _load_template(self, name: str) -> Template:
        return Template((self.TEMPLATES_BASE_PATH / name).read_text(encoding='utf-8'))

    def _write_step_html_report(self, data, result, steps_override=None, status_override=None, elapsed_override=None, start_time_override=None, source_override=None):
        try:
            steps = steps_override if steps_override is not None else self._html_steps
            status = status_override if status_override is not None else result.status
            elapsed = elapsed_override if elapsed_override is not None else str(result.elapsed_time)
            start_time = start_time_override if start_time_override is not None else self._test_start_time
            source = source_override if source_override is not None else self._test_source

            if not self._reports_dir or not steps:
                return

            test_name = data.name
            test_id = test_name.split(':')[0].strip() if ':' in test_name else None
            test_display_name = test_name.split(':')[1].strip() if ':' in test_name else test_name

            row_template = self._load_template("step_table_row.html")
            rendered_rows = []
            for step_data in sorted(steps, key=lambda x: x['step']):
                cb_data = self.getCBPath(test_id, step_data['step'])
                try:
                    ts_dt = datetime.fromisoformat(step_data['timestamp'])
                    formatted_ts = ts_dt.strftime('%m/%d/%Y %I:%M:%S %p')
                except Exception:
                    formatted_ts = step_data['timestamp']
                row = row_template.substitute(
                    step_number=step_data['step'],
                    keyword_name=cb_data['step_text'],
                    expected_result=cb_data['expected_result'],
                    timestamp=formatted_ts,
                    result_message=step_data['message'],
                    result_status_class=step_data['status'].lower() if step_data['status'] else '',
                    result_status=step_data['status'] if step_data['status'] else 'N/A'
                )
                rendered_rows.append(row)

            step_table_template = self._load_template("step_table.html")
            table_html = step_table_template.substitute(rows='\n'.join(rendered_rows))

            footer_template = self._load_template("test_case_footer.html")
            footer_html = footer_template.substitute(
                status_class=status.lower(),
                test_case_status=status,
                elapsed_time=elapsed
            )

            test_case_template = self._load_template("test_case.html")
            test_case_html = test_case_template.substitute(
                test_case_steps=table_html,
                test_case_footer=footer_html
            )

            builtin = BuiltIn()
            tester_name = builtin.get_variable_value("${TESTER_NAME}", default='N/A') or 'N/A'
            build_id = builtin.get_variable_value("${BUILD_ID}", default='N/A') or 'N/A'
            test_config = builtin.get_variable_value("${test_config}", default='N/A') or 'N/A'
            parent_folder = Path(source).parent.name if source else 'N/A'

            formatted_date = 'N/A'
            if start_time:
                try:
                    parsed = datetime.strptime(start_time, "%Y%m%d %H:%M:%S.%f")
                    ms = round(parsed.microsecond / 1000)
                    formatted_date = f"{parsed.strftime('%m/%d/%Y %I:%M:%S')}.{ms:03d} {parsed.strftime('%p')}"
                except Exception:
                    formatted_date = str(start_time)

            header_table_template = self._load_template("header_table.html")
            header_table_html = header_table_template.substitute(
                test_case_name=test_display_name,
                test_case_id=f'<a href="https://crdn.codebeamer.com/issue/{test_id}" target="_blank">{test_id}</a>' if test_id else 'N/A',
                test_case_folder=parent_folder,
                test_case_configuration=test_config,
                test_case_build_info=build_id,
                tester_name=tester_name,
                date_of_execution=formatted_date
            )

            report_header_template = self._load_template("report_header.html")
            report_header_html = report_header_template.substitute(
                test_case_name=test_display_name,
                test_case_header=header_table_html
            )

            test_section_template = self._load_template("test_section.html")
            test_section_html = test_section_template.substitute(
                test_section_data=test_case_html
            )

            base_template = self._load_template("base.html")
            full_html = base_template.substitute(
                report_title="Step Results Report",
                report_header=report_header_html,
                suite_setup='',
                test_cases=test_section_html,
                suite_teardown=''
            )

            safe_id = re.sub(r'[^A-Za-z0-9._-]+', '_', test_id).strip('_') if test_id else f"{self._test_counter:03d}"
            filename = safe_id + ".html"
            filepath = os.path.join(self._reports_dir, filename)
            i = 1
            while os.path.exists(filepath) or filename in self._seen_filenames:
                filename = f"{safe_id}_{i}.html"
                filepath = os.path.join(self._reports_dir, filename)
                i += 1
            self._seen_filenames.add(filename)

            with open(filepath, "w", encoding="utf-8") as f:
                f.write(full_html)
            self._test_counter += 1

            # Append to the sidecar index so Summary.py can map suite → custom reports
            try:
                builtin = BuiltIn()
                suite_name = builtin.get_variable_value("${SUITE_NAME}", default='N/A') or 'N/A'
                index_path = Path(self._reports_dir).parent / 'RF' / 'custom_report_index.csv'
                index_path.parent.mkdir(parents=True, exist_ok=True)
                with open(index_path, 'a', encoding='utf-8') as idx:
                    idx.write(f"{suite_name},{filename}\n")
            except Exception as idx_e:
                print(f"Warning: could not write custom report index entry: {idx_e}")

        except Exception as e:
            print(f"Error writing step HTML report: {e}")

    # def end_suite(self, name, result):
    #     if name.metadata:
    #         if 'datadriven' in name.metadata["Type"]:
    #             print("\n\n\nDatadriven Suite Identified")
    #             testSteps=name.metadata["Steps"]

    #             BuiltIn().set_suite_variable("${tmpStepResult}",[])
    #             BuiltIn().set_suite_variable("${SuiteType}",'')
    #             BuiltIn().set_suite_variable("${TotalSteps}",None)
 
    #     else:
    #         BuiltIn().set_suite_variable("${SuiteType}",'')