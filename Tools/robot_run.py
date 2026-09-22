import argparse
import sys
import os
from pathlib import Path
from datetime import datetime

from robot import run_cli

from exceptions import RFInternalError, RFInvalidUserData, RFExecutionStoppedByUser, SquishServerAlreadyRunning, PipelineTestFailure
from robot_return_codes import RFReturnCode

project_root = Path(__file__).resolve().parents[1]
root_dir = str(project_root)
sys.path.insert(0, root_dir)

com_lib = project_root / 'Common_Lib'
if com_lib.exists():
    sys.path.insert(0, str(com_lib))
    com_lib_g4 = com_lib / 'G4_API' / 'Core'
    if com_lib_g4.exists():
        sys.path.insert(0, str(com_lib_g4))

print(f"Project root added to sys.path: {root_dir}")

squish_tools = None
SQUISH_VARS = {}
try:
    import Common_Lib.Squish.squish_tools as squish_tools
    from Common_Lib.Squish.squish_tools import SQUISH_VARS
except ModuleNotFoundError:
    squish_tools = None
    SQUISH_VARS = {}




def setup_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=f"Wrapper script which allows running Robot tests and after "
                                                 f"that generates custom test log.")
    parser.add_argument('--tester', action='store', type=str)
    parser.add_argument('-d', '--outputdir', action='store', type=str)
    parser.add_argument('--tags', action='append', default=[],
                        help="Include tags. Comma separated. Can be used multiple times, e.g. "
                             "--tags smoke,critical --tags fast")
    parser.add_argument('--exclude-tags', '--xtags', dest='xtags', action='append', default=[],
                        help="Exclude tags. Comma separated. Can be used multiple times.")
    parser.add_argument('--custom-report', dest='custom_report', action='store_true', default=False,
                        help="Enable per-test custom HTML reports (True/False). Default: False.")
    parser.add_argument('--dashboard', dest='dashboard', action='store_true', default=False,
                        help="Enable Robot dashboard logging (True/False). Default: False.")
    parser.add_argument('--pipeline', dest='pipeline', action='store_true', default=False,
                        help="Trigger the script with pipeline configuration. Default: False.")
    parser.add_argument('--local', dest='local', action='store_true', default=False,
                        help="Trigger the script with local configuration. Default: False.")
    parser.add_argument('--ui-tests', dest='ui_tests', action='store_true', default=False,
                        help="Enable support for UI tests (setup squish environment). Currently, if specified this will"
                             " only run squishserver binary. Default: False.")
    return parser


def _split_tags(parts):
    """Splits comma separated tags into a list of tags"""
    out = []
    for entry in parts or []:
        if entry:
            out.extend([tag.strip() for tag in entry.split(',') if tag.strip()])
    return out


def get_test_metadata(parameters: dict):
    # Fetch tester
    tester = parameters.get('tester', None)
    if tester is None:
        tester = 'N/A'

    # Fetch build_id
    build_id = parameters.get('build_id', None)
    if build_id is None:
        build_id = 'N/A'

    # Fetch test configuration
    test_config = parameters.get('test_config', None)
    if test_config is None:
        test_config = 'N/A'

    return tester, build_id, test_config


def get_report_output_path_from_test_path(test_path: Path, pipeline: bool = False) -> Path:
    if pipeline:
        return Path('Reports') / 'RF'

    is_file = test_path.suffix.lower() == ".robot"
    date_str = datetime.now().strftime("%Y-%m-%d")
    time_str = datetime.now().strftime("%H-%M-%S")

    if 'Test_Cases' not in test_path.parts:
        leaf = test_path.stem if is_file else test_path.name
        return Path('Reports') / date_str / f"{leaf}_{time_str}" / 'RF'

    # Extract parts after 'Test_Cases'
    start_idx = test_path.parts.index('Test_Cases') + 1
    end_idx = -1 if is_file else None
    parts_after_root = test_path.parts[start_idx:end_idx]

    report_parts = ['Reports', date_str]
    report_parts += [f"{part}_Reports" for part in parts_after_root]
    test_name = test_path.stem if is_file else test_path.name
    report_parts.append(f"{test_name}_{time_str}")
    report_parts.append('RF')
    return Path(*report_parts)


def test_setup(cli_params):
    if cli_params.ui_tests:
        if squish_tools is None:
            raise RuntimeError(
                "UI tests requested, but Common_Lib/Squish dependencies are not available in this repo. "
                "This wrapper can still run non-UI Robot tests and custom reports without Squish."
            )
        # prepare setup for UI based test
        squish_tools.configure_squish_license_server(SQUISH_VARS.get("SQUISH_LICENSE_SERVER_HOST"),
                                                    SQUISH_VARS.get("SQUISH_LICENSE_SERVER_PORT"))
        squish_tools.add_attachable_aut(SQUISH_VARS.get("AUT"),
                                        SQUISH_VARS.get("HOST"),
                                        SQUISH_VARS.get("SQUISH_AUT_LISTENER_PORT"))

        squishserver_host = SQUISH_VARS.get("SQUISH_SERVER_DEFAULT_HOST")
        squishserver_port = SQUISH_VARS.get("SQUISH_SERVER_DEFAULT_PORT")
        squishserver_logfile = SQUISH_VARS.get("SQUISH_SERVER_LOG_FILE")

        try:
            squish_tools.start_squish_server(squishserver_host,
                                             squishserver_port,
                                             squishserver_logfile)
        except SquishServerAlreadyRunning:
            squish_tools.stop_squish_server(squishserver_host,
                                            squishserver_port)
            squish_tools.start_squish_server(squishserver_host,
                                             squishserver_port,
                                             squishserver_logfile)


def test_teardown(cli_params):
    if cli_params.ui_tests and squish_tools is not None:
        # clean after UI tests
        squish_tools.stop_squish_server(SQUISH_VARS.get("SQUISH_SERVER_DEFAULT_HOST"),
                                        SQUISH_VARS.get("SQUISH_SERVER_DEFAULT_PORT")
                                        )


def run_tests(robot_parameters, cli_params) -> int:
    test_setup(cli_params)
    rc = run_cli(robot_parameters, exit=False)
    test_teardown(cli_params)
    return rc


if __name__ == '__main__':
    # parse arguments which were defined to extract info from them e.g. --outputdir or --tester
    args_parser = setup_parser()
    args, unparsed = args_parser.parse_known_args()

    # Determine the report path: use provided -d or generate one
    test_path = None
    for item in reversed(unparsed):  # <— look from the end
        if item.startswith('-'):
            continue
        p = Path(item.strip('\'"'))  # handle "...\something.robot"
        if (p.suffix.lower() == ".robot" or p.is_dir()) and p.exists():
            test_path = p.resolve()
            break
    else:
        raise ValueError("No .robot file or directory argument found.")

    if args.outputdir:
        reports_path = Path(args.outputdir).resolve()
    else:
        reports_path = get_report_output_path_from_test_path(test_path, pipeline=args.pipeline)

    reports_path.mkdir(parents=True, exist_ok=True)

    xml_file = reports_path / 'output.xml'
    unparsed[:0] = ['--outputdir', reports_path.as_posix()]
    if args.custom_report or args.pipeline:
        listener_path = (Path(__file__).resolve().parent / 'LogManager' / 'ReportListener.py').as_posix()
        unparsed[:0] = ['--listener', listener_path]
    tester, build_id, test_config = get_test_metadata(vars(args))
    unparsed[:0] = [
        '-v', f"TESTER_NAME:{tester}",
        '-v', f"BUILD_ID:{build_id}",
        '-v', f"test_config:{test_config}"
    ]

    include_tags = _split_tags(args.tags)
    exclude_tags = _split_tags(args.xtags)

    # Build a copy with tag filters
    args_with_tags = list(unparsed)
    for t in include_tags:
        args_with_tags[:0] = ['-i', t]
    for t in exclude_tags:
        args_with_tags[:0] = ['-e', t]
    print(f"Running tests in: {test_path}\n")
    print(args)
    rc = run_tests(args_with_tags if (include_tags or exclude_tags) else unparsed, args)

    if rc == RFReturnCode.RC_INTERNAL_ERROR:
        raise RFInternalError(f"""
            Directory: {test_path}\n
            Runtime error: Robot framework internal error.
        """)

    if rc == RFReturnCode.RC_EXECUTION_STOPPED_BY_USER:
        raise RFExecutionStoppedByUser(f"""
            Directory: {test_path}\n
            Tests were stopped by user during execution.
        """)

    if (include_tags or exclude_tags) and rc == RFReturnCode.RC_INVALID_DATA_OR_CLI_OPTIONS:
        raise RFInvalidUserData(f"""
            Directory: {test_path}\n
            Tags: {include_tags=} {exclude_tags=}\n
            The specified directory does not contain test cases marked with the specified tags. Unable to run tests, as 
            no tests are available.
        """)

    if rc <= RFReturnCode.RC_TC_FAILED_250_OR_MORE and args.custom_report:
        custom_reports_dir = reports_path.parent / 'CustomReports' if reports_path.name == 'RF' else reports_path / 'CustomReports'
        if custom_reports_dir.exists():
            custom_report_files = sorted(
                [p for p in custom_reports_dir.glob("*.html") if p.name.lower() not in {"log.html", "report.html"}],
                key=lambda p: p.name.lower()
            )
            print("Custom Listener reports:")
            for html_path in custom_report_files:
                uri = html_path.resolve().as_uri()
                print(f"  {uri}")


    if rc != 0:
        if args.pipeline:
            raise PipelineTestFailure
        else:
            print("Tests failed (non-pipeline/local run) — not raising PipelineTestFailure because this is a local run.")
            sys.exit(rc)

