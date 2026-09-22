import subprocess
import time
import os
from pathlib import Path
from typing import Optional

from Tools.exceptions import SquishError, SquishDirNotSet, SquishServerAlreadyRunning

from Configuration.Squish.Squish_Configuration import get_variables


SQUISH_VARS = get_variables()
SQUISH_SERVER_PROCESS: Optional[subprocess.Popen] = None


def find_project_root(start: Path, marker: str) -> Path:
        """Helper method to find root path of ARTF project from within project structure."""
        current = start.resolve()
        while current != current.parent:
            if (current / marker).exists():
                return current
            current = current.parent
        raise FileNotFoundError(f"Project root with marker '{marker}' not found.")


def find_process_by_name(name) -> bool:
        try:
            import psutil
        except ImportError:
            raise ImportError("You need to install psutil package first to use this method.")
        for proc in psutil.process_iter(['name']):
            if proc.info['name'] == name:
                # print(f"Found: PID={proc.pid}, Name={proc.info['name']}")
                return True
        return False


def get_squish_dir() -> Path:
    squish_dir = SQUISH_VARS.get('SQUISH_DIR', None)
    if squish_dir is None:
        raise SquishDirNotSet
    return Path(squish_dir)


def execute_squish_server_command(
    squishserver_path: Path, *params: str
) -> subprocess.CompletedProcess:
    """
    Execute squishserver command and verify it succeeded.
    :param squishserver_path: Path to the squishserver executable.
    :param params: Any additional args for squishserver.
    """
    result = subprocess.run(
        [squishserver_path, *params],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SquishError(
            f"Unable to configure squish using squishserver; "
            f"exit code {result.returncode}"
        )
    if result.stderr:
        raise SquishError(
            f"squishserver command with {params} returned error: {result.stderr}"
        )
    return result


def execute_squish_config_command(
    squishconfig_path: Path, *params: str
) -> subprocess.CompletedProcess:
    """
    Execute squishconfig command and verify it succeeded.
    :param squishconfig_path: Path to the squishconfig executable.
    :param params: Any additional args for squishconfig.
    """
    result = subprocess.run(
        [squishconfig_path, *params],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SquishError(
            f"Unable to configure squish using squishconfig; "
            f"exit code {result.returncode}"
        )
    if result.stderr:
        raise SquishError(
            f"squishconfig command with {params} returned error: {result.stderr}"
        )
    return result


def add_attachable_aut(
    aut_name: str,
    aut_hostname: str,
    port: str,
):
    """
    Add an attachable AUT to squishserver configuration.
    """
    execute_squish_server_command(
        Path(get_squish_dir()) / "bin" / "squishserver",
        "--config",
        "addAttachableAUT",
        aut_name,
        f"{aut_hostname}:{port}",
    )


def configure_squish_license_server(
    hostname: str = os.environ.get("SQUISH_LICENSE_SERVER_HOST", "license.host"),
    port: str = os.environ.get("SQUISH_LICENSE_SERVER_PORT", "4081"),
) -> None:
    """
    Configure squish installation to use a floating license server.
    """
    squish_dir = get_squish_dir()
    execute_squish_config_command(
        Path(squish_dir) / "bin" / "squishconfig", f"--licensekey={hostname}:{port}"
    )


def check_squishserver_log_file(logfile_path: Path) -> None:
    """
    Verify the squishserver log is non-empty. Raise if still empty.
    You can extend this to look for specific 'ready' markers.
    """
    with open(logfile_path, encoding="utf-8", errors="ignore") as log_file:
        lines = log_file.readlines()
        if not lines:
            raise AssertionError(f"Squishserver log {logfile_path} is still empty.")
        last_line = lines[-1]
        marker = 'Announcing server presence'
        if marker not in last_line:
            raise AssertionError(f"Squishserver log {logfile_path} does not contain expected string: {marker}")


def start_squish_server(
    hostname: str,
    port: str,
    logfile_path: str,
):
    """
    Start squishserver in the background, ensure it’s running,
    wait for its logfile to appear, and confirm it’s writing.

    Note: process id is not stored as it is temp process created (stopping is done by squishserver cmdlet itself)
    """
    global SQUISH_SERVER_PROCESS

    if find_process_by_name("_squishserver.exe") or SQUISH_SERVER_PROCESS is not None:
        raise SquishServerAlreadyRunning("squishserver instance is already running. Please stop it first.")

    log_path = Path(logfile_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    args = [
                Path(get_squish_dir()) / "bin" / "squishserver",
                "--host",
                hostname,
                "--port",
                str(port),
                "--logfile",
                logfile_path,
                "--verbose",
            ]
    try:
        proc = subprocess.Popen(
            args,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as e:
        raise SquishError(
            f"Unable to start squishserver. Reason: {e}"
        )

    # 1) Verify it didn't immediately exit
    time.sleep(0.5)
    res = proc.poll()
    if res is not None:
        raise SquishError("squishserver is not running!")

    SQUISH_SERVER_PROCESS = proc

    # 2) Wait up to 5s for logfile to appear
    deadline = time.time() + 5
    while time.time() < deadline:
        if log_path.exists():
            break
        time.sleep(0.2)
    else:
        raise SquishError(f"Log file {logfile_path} not created in time.")

    # 3) Retry up to 3 times to see content in the log
    for attempt in range(3):
        try:
            check_squishserver_log_file(log_path)
            break
        except AssertionError as e:
            if attempt == 2:
                raise SquishError(e)
            time.sleep(3)


def stop_squish_server(
    hostname: str,
    port: str,
) -> Optional[subprocess.CompletedProcess]:
    """
    Stop any squishserver process running in the background by invoking
    the squishserver executable with the --stop flag.

    :param hostname:        Hostname where squishserver is listening.
    :param port:            Port where squishserver is listening.
    :returns:               CompletedProcess for further inspection if needed.
    :raises RFInternalError: If the stop command fails or emits stderr.
    """
    global SQUISH_SERVER_PROCESS

    if SQUISH_SERVER_PROCESS:
        SQUISH_SERVER_PROCESS.terminate()
        SQUISH_SERVER_PROCESS.communicate(timeout=5)
        SQUISH_SERVER_PROCESS = None

    if find_process_by_name("_squishserver.exe"):
        result = subprocess.run(
            [
                Path(get_squish_dir()) / "bin" / "squishserver",
                "--stop",
                "--host", hostname,
                "--port", str(port)
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )

        if result.returncode != 0:
            raise SquishError(
                f"Unable to stop squishserver; exit code {result.returncode}"
            )

        if result.stderr:
            raise SquishError(
                f"squishserver --stop command returned error: {result.stderr}"
            )
        return result
    return None
