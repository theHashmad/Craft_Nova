class RFError(Exception):
    """General Robot Framework related error."""


class RFInvalidUserData(RFError):
    """Thrown when Robot Framework return code is indicating invalid user data or invalid cli options."""


class RFInternalError(RFError):
    """Thrown when Robot Framework return code is indicating internal error code."""


class RFExecutionStoppedByUser(RFError):
    """Thrown when Robot Framework return code is indicating execution stopped by user."""

class SquishError(Exception):
    """General Squish related error."""


class SquishDirNotSet(SquishError):
    """Thrown when necessary SQUISH_DIR variable is not set."""


class SquishServerAlreadyRunning(SquishError):
    """Thrown when squishserver.exe is already running in background."""

class PipelineTestFailure(Exception):
    """Thrwon when test on pipeline is failing"""
    