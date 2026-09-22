import sys
import pathlib
import platform


class SquishUtilLibrary:
    ROBOT_LIBRARY_SCOPE = 'TEST'

    def __init__(self):
        pass

    def form_paths(self, base_path, paths_to_append) -> list[str]:
        return [str(pathlib.PurePath(base_path, path)) for path in paths_to_append if path not in sys.path]

    @staticmethod
    def is_number(value):
        """Tries to convert value to float. Based on success of that conversion, boolean is returned."""
        try:
            float(value)
            return True
        except ValueError:
            return False

    @staticmethod
    def format_number(value, decimals = 2):
        """Removes not significant decimal place. E.g. 12.0 is converted to 12. But 12.1 stays as 12.1."""
        rounded_value = round(value, decimals)
        return int(rounded_value) if rounded_value == int(rounded_value) else rounded_value

    def check_running_python_interpreter(self) -> str:
        print(f'*INFO* Gathering information about used python interpreter.')
        # Python Version
        python_version = sys.version

        # Python Executable Path
        python_executable = sys.executable

        # Python Architecture
        python_architecture = platform.architecture()[0]

        info = (
            f"Python Version: {python_version}\n"
            f"Python Executable: {python_executable}\n"
            f"Python Architecture: {python_architecture}\n"
        )
        return info
