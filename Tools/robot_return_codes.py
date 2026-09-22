import enum


class RFReturnCode(enum.IntEnum):
    """
    0                         All tests passed.
    1-249                     Returned number of tests failed.
    250                       250 or more failures.
    251                       Help or version information printed.
    252                       Invalid data or command line options.
    253                       Execution stopped by user.
    255                       Unexpected internal error.

    Info from RF Guide: https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#toc-entry-456
    """
    RC_TC_PASSED = 0
    RC_TC_FAILED_NUMBER_MIN = 1
    RC_TC_FAILED_NUMBER_MAX = 249
    RC_TC_FAILED_250_OR_MORE = 250
    RC_HELP_OR_VERSION_INFO_PRINTED = 251
    RC_INVALID_DATA_OR_CLI_OPTIONS = 252
    RC_EXECUTION_STOPPED_BY_USER = 253
    RC_INTERNAL_ERROR = 255


