import re
import os


def read_robot_framework_variable(file_path, variable_name):
    """Read a variable from Robot Framework resource file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Pattern to match Robot Framework variable definition: ${varName}    value
        pattern = rf'\${{{variable_name}}}\s+(.+?)(?:\s+#.*)?$'
        match = re.search(pattern, content, re.MULTILINE)
        
        if match:
            value = match.group(1).strip()
            # Remove quotes if present
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            return value
        return None
    except Exception as e:
        print(f"Error reading variable {variable_name} from {file_path}: {e}")
        return None


def load_codebeamer_config():
    """Load Codebeamer configuration from resource file."""
    config_file = os.path.join("Configuration", "Codebeamer", "Codebeamer_Configuration.resource")
    
    # Try to read from config file, fall back to defaults
    username = read_robot_framework_variable(config_file, "cbUserName") or "craft-runner"
    password = read_robot_framework_variable(config_file, "cbPwd") or "craft-runner"
    
    print(f"Loaded Codebeamer config - Username: {username}")
    return username, password