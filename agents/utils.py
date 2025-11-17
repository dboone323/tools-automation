import os
import subprocess
import logging
import sys
from typing import Any

logger = logging.getLogger(__name__)


def safe_run(cmd: Any, cwd: str | None = None, **kwargs):
    """Run subprocess in a safer, audited way.

    - Accepts list or string `cmd`.
    - If `cmd` is a string that contains shell metacharacters, `shell=True` is used
      only if `ALLOW_SHELL` environment variable is set, or if the caller has a
      matching `ALLOWED_SHELL_COMMANDS` env allowlist entry. Otherwise a
      RuntimeError is raised to avoid accidental shell injection.

    This wrapper centralizes the decision and helps reviewers spot shell usage
    in one place. The underlying subprocess.run is invoked here; annotate the
    call with `# nosec B603` in this module if you want to suppress Bandit
    warnings for controlled invocations.
    """
    allow_shell_env = os.environ.get("ALLOW_SHELL", "").lower() in (
        "1",
        "true",
        "yes",
    )
    allowed_shell_command_names = set(
        [c.strip() for c in os.environ.get("ALLOWED_SHELL_COMMANDS", "").split(",") if c.strip()]
    )

    # Heuristic for shell meta-characters when command is a string
    shell_flag = False
    if isinstance(cmd, str):
        for c in ["|", "&&", ";", ">", "<", "*", "$", "`"]:
            if c in cmd:
                shell_flag = True
                break

    # If shell is required and not allowed, raise and avoid executing it
    if shell_flag and not allow_shell_env:
        # If the caller sets the command name in an env allowlist, permit
        cmd_name = None
        try:
            if isinstance(cmd, str):
                cmd_name = cmd.split()[0]
            elif isinstance(cmd, (list, tuple)) and cmd:
                cmd_name = str(cmd[0])
        except Exception:
            cmd_name = None

        if cmd_name not in allowed_shell_command_names:
            raise RuntimeError("shell_execution_not_allowed")

    # Under normal conditions, prefer `shell=False` when caller provided a list
    if isinstance(cmd, (list, tuple)):
        shell_flag = False

    logger.debug("safe_run: cmd=%s shell=%s cwd=%s", cmd, shell_flag, cwd)
    # Call subprocess.run - this is a controlled wrapper for subprocess usage
    # We intentionally annotate this with `# nosec B603` to indicate we've
    # audited the call site. Tools scanning for bandit warnings should see the
    # justification in the surrounding code.
    return subprocess.run(cmd, cwd=cwd, shell=shell_flag, **kwargs)  # nosec B603


def user_log(msg: str, level: str = "info", stderr: bool = False):
    """Log a user-facing message in a structured way.

    By default, structured logging is used (logger.<level>), but if
    environment variable `LOG_TO_STDOUT` is set to true, messages are
    printed to stdout/stderr instead. This lets tools that read stdout
    continue to work while keeping structured logs available by default.
    """
    stdout_enabled = os.environ.get("LOG_TO_STDOUT", "").lower() in (
        "1",
        "true",
        "yes",
    )
    level = (level or "info").lower()

    # Choose the logger method
    logger_method = {
        "debug": logger.debug,
        "info": logger.info,
        "warning": logger.warning,
        "error": logger.error,
        "critical": logger.critical,
    }.get(level, logger.info)

    if stdout_enabled:
        print(msg, file=sys.stderr if stderr else sys.stdout)
    else:
        logger_method(msg)
