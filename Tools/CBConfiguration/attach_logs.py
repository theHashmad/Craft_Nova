import requests
from requests.auth import HTTPBasicAuth
import subprocess
import shutil
import os
import sys
import concurrent.futures
from threading import Lock
import urllib3
import glob
import re
from cb_configurations import load_codebeamer_config


# Codebeamer instance details
CODEBEAMER_URL = "https://crdn.codebeamer.com"
USERNAME, PASSWORD = load_codebeamer_config()
REPORT_FOLDER = os.path.join("Reports", "RF")
RESULT_FILE = os.path.join("Reports", "RF", "results.txt")
search_suite_name = ""

# Basic authentication
auth = (USERNAME, PASSWORD)
current_dir = os.getcwd()
FULL_PATH = os.path.join(current_dir, RESULT_FILE)
REPORT_PATH = os.path.join(current_dir, REPORT_FOLDER)
XML_PATH = os.path.join(REPORT_PATH, "output.xml")

# Global session for connection reuse
session_lock = Lock()
global_session = None


def get_session():
    """Get or create a reusable HTTP session."""
    global global_session
    with session_lock:
        if global_session is None:
            global_session = requests.Session()
            global_session.verify = False
            global_session.auth = HTTPBasicAuth(USERNAME, PASSWORD)
            # Connection pooling settings for better performance
            adapter = requests.adapters.HTTPAdapter(
                pool_connections=10,
                pool_maxsize=20,
                max_retries=3
            )
            global_session.mount('http://', adapter)
            global_session.mount('https://', adapter)
    return global_session


def cleanup_files_and_folders(suite_name, report_path=REPORT_PATH):
    """Cleanup with error handling for better reliability."""
    try:
        # Delete the created zip file
        zip_path = os.path.join(report_path, suite_name + ".zip")
        if os.path.exists(zip_path):
            os.remove(zip_path)
    except Exception as e:
        pass


def process_suite(suite_name, tracker_item_id):
    """Process a single suite: find matching files -> archive -> upload -> cleanup."""
    # Create archive from matching files
    file_path = create_archive(suite_name, tracker_item_id)
    if file_path is None:
        cleanup_files_and_folders(suite_name)
        return False
    
    # Upload attachment
    success = upload_attachment(file_path, tracker_item_id)
    
    # Cleanup
    cleanup_files_and_folders(suite_name)
    
    return success


def process_defect(tc_id, tracker_item_id, suite_name, test_run_id):
    """Process a single defect: find matching files -> archive -> upload -> cleanup."""
    # Create archive from matching files
    file_path = create_archive(tc_id, tracker_item_id)
    if file_path is None:
        cleanup_files_and_folders(tc_id)
        return False
    
    # Upload attachment
    success = upload_attachment(file_path, tracker_item_id)
    
    # Cleanup
    cleanup_files_and_folders(tc_id)
    
    return success


def create_archive(suite_name, tracker_item_id):
    """Create archive from log, report, and output files matching suite name pattern."""
    final_name = suite_name + "_TR_" + str(tracker_item_id)
    archive_path = os.path.join(REPORT_PATH, final_name)
    zip_file_path = archive_path + ".zip"
    
    try:
        # Normalize suite name for flexible matching (remove spaces, underscores, hyphens)
        def normalize_for_matching(text):
            """Remove whitespace, underscores, and hyphens for flexible matching."""
            return re.sub(r'[\s_-]', '', text.lower())
        
        normalized_suite = normalize_for_matching(suite_name)
        
        # Find all matching files in REPORT_PATH by comparing normalized names
        matching_files = []
        
        # Get all potential log and report files
        all_logs = glob.glob(os.path.join(REPORT_PATH, "log_*.html"))
        all_reports = glob.glob(os.path.join(REPORT_PATH, "report_*.html"))
        
        # Check each file to see if it matches the normalized suite name
        for file_path in all_logs + all_reports:
            filename = os.path.basename(file_path)
            # Normalize the filename for comparison
            normalized_filename = normalize_for_matching(filename)
            
            # Check if the normalized suite name appears in the normalized filename
            if normalized_suite in normalized_filename:
                matching_files.append(file_path)
        
        # Extract timestamps from found files to match corresponding XML files
        timestamps = set()
        timestamp_pattern = r'-(\d{8}-\d{6})'
        for file_path in matching_files:
            match = re.search(timestamp_pattern, os.path.basename(file_path))
            if match:
                timestamps.add(match.group(1))
        
        # Add matching XML files by timestamp
        for timestamp in timestamps:
            xml_pattern = f"output-{timestamp}.xml"
            matching_files.extend(glob.glob(os.path.join(REPORT_PATH, xml_pattern)))
        
        if not matching_files:
            print(f"No matching files found for suite: {suite_name} (normalized: {normalized_suite})")
            return None
        
        # Remove duplicates
        matching_files = list(set(matching_files))
        
        print(f"Found {len(matching_files)} file(s) for {suite_name}")
        for f in matching_files:
            print(f"  - {os.path.basename(f)}")
        
        # Create a temporary directory to stage files for archiving
        temp_dir = os.path.join(REPORT_PATH, f"temp_{suite_name}_{tracker_item_id}")
        os.makedirs(temp_dir, exist_ok=True)
        
        # Copy matching files to temp directory
        for file_path in matching_files:
            shutil.copy2(file_path, temp_dir)
        
        # Create archive from temp directory
        shutil.make_archive(archive_path, 'zip', temp_dir)
        
        # Clean up temp directory
        shutil.rmtree(temp_dir)
        
        # Verify the created zip file exists and has content
        if os.path.exists(zip_file_path):
            zip_size = os.path.getsize(zip_file_path)
            if zip_size > 0:
                print(f"Created archive: {final_name}.zip ({zip_size} bytes)")
                return zip_file_path
            else:
                print(f"Archive created but is empty: {zip_file_path}")
                return None
        else:
            print(f"Archive file not found after creation: {zip_file_path}")
            return None
            
    except Exception as e:
        print(f"Error creating archive for {suite_name}: {str(e)}")
        # Clean up temp directory on error
        temp_dir = os.path.join(REPORT_PATH, f"temp_{suite_name}_{tracker_item_id}")
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
        return None


def upload_attachment(file_path, tracker_item_id):
    """Upload attachment using reusable session for better performance."""
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
 
    ATTACHMENT_ENDPOINT = f"{CODEBEAMER_URL}/api/v3/items/{tracker_item_id}/attachments"
    
    try:
        session = get_session()
        with open(file_path, "rb") as f:
            files = {
                "attachments": (os.path.basename(file_path), f, "application/zip")
            }
            # Use existing session with connection pooling
            response = session.post(ATTACHMENT_ENDPOINT, files=files, timeout=30)
            
            if response.status_code == 200:
                print(f"Attachment uploaded successfully to tracker item {tracker_item_id}.")
                return True
            else:
                print(f"Failed to upload attachment to tracker item {tracker_item_id}. Status code: {response.status_code}")
                return False
                
    except Exception as e:
        return False


def main():
    """Main execution with parallel processing for improved performance."""
    print("Starting attach_logs.py...")
    
    if not os.path.exists(FULL_PATH):
        print(f"ERROR: Results file not found: {FULL_PATH}")
        return
    
    # Check for XML or HTML files in REPORT_PATH
    xml_files = glob.glob(os.path.join(REPORT_PATH, "output-*.xml"))
    html_files = glob.glob(os.path.join(REPORT_PATH, "log_*.html"))
    
    if not xml_files and not html_files:
        print(f"ERROR: No output files found in {REPORT_PATH}")
        return
    
    print(f"Found results file: {FULL_PATH}")
    print(f"Found {len(xml_files)} XML file(s) and {len(html_files)} HTML file(s)")
    
    # Read and parse results
    with open(FULL_PATH, "r") as fresult_file:
        result_content = fresult_file.read()
        result_set = result_content.splitlines()
    
    print(f"Results file has {len(result_set)} lines")
    
    # Collect all tasks for parallel execution
    suite_tasks = []
    defect_tasks = []
    
    for line in result_set:
        if not line.strip():
            continue
            
        result_values = line.split(",")
        if len(result_values) < 3:
            continue
            
        suite_name = result_values[0]
        if not result_values[1].strip().lstrip('-').isdigit():
            print(f"[WARNING] Skipping line with invalid test run ID '{result_values[1].strip()}': {line.strip()}")
            continue
        test_run_id = int(result_values[1])
        
        # Add suite processing task
        suite_tasks.append((suite_name, test_run_id))
        
        # Check for defects if test failed
        if len(result_values) > 2 and result_values[2].strip() == "FAIL":
            if len(result_values) > 3:
                defect_list = result_values[3].split("|")
                defect_list = [item.strip() for item in defect_list if item.strip()]
                
                for defect in defect_list:
                    if ":" in defect:
                        tc_defect = defect.split(":")
                        tc_id = tc_defect[0]
                        defect_tracker_id = tc_defect[1]
                        defect_tasks.append((tc_id, int(defect_tracker_id), suite_name, test_run_id))
    
    print(f"Found {len(suite_tasks)} suites and {len(defect_tasks)} defects to process")
    
    if not suite_tasks and not defect_tasks:
        print("No tasks found to process. Exiting.")
        return
    
    # Process suites in parallel (limited concurrency to avoid overwhelming server)
    max_workers = min(4, len(suite_tasks))  # Limit to 4 concurrent operations
    
    if suite_tasks:
        print(f"Processing {len(suite_tasks)} suites...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            suite_futures = {
                executor.submit(process_suite, suite_name, tracker_id): (suite_name, tracker_id)
                for suite_name, tracker_id in suite_tasks
            }
            
            completed = 0
            for future in concurrent.futures.as_completed(suite_futures):
                suite_name, tracker_id = suite_futures[future]
                try:
                    result = future.result(timeout=120)  # 2 minute timeout per suite
                    completed += 1
                    if result:
                        print(f"Suite {suite_name} completed successfully ({completed}/{len(suite_tasks)})")
                    else:
                        print(f"Suite {suite_name} failed ({completed}/{len(suite_tasks)})")
                except Exception as exc:
                    completed += 1
                    print(f"Suite {suite_name} error: {exc} ({completed}/{len(suite_tasks)})")
    
    # Process defects in parallel
    if defect_tasks:
        print(f"Processing {len(defect_tasks)} defects...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            defect_futures = {
                executor.submit(process_defect, tc_id, tracker_id, suite_name, test_run_id): (tc_id, tracker_id)
                for tc_id, tracker_id, suite_name, test_run_id in defect_tasks
            }
            
            completed = 0
            for future in concurrent.futures.as_completed(defect_futures):
                tc_id, tracker_id = defect_futures[future]
                try:
                    result = future.result(timeout=60)  # 1 minute timeout per defect
                    completed += 1
                    if result:
                        print(f"Defect {tc_id} completed successfully ({completed}/{len(defect_tasks)})")
                    else:
                        print(f"Defect {tc_id} failed ({completed}/{len(defect_tasks)})")
                except Exception as exc:
                    completed += 1
                    print(f"Defect {tc_id} error: {exc} ({completed}/{len(defect_tasks)})")
    
    # Close session
    if global_session:
        global_session.close()
    
    print("attach_logs.py completed.")


if __name__ == "__main__":
    cb_enable = sys.argv[1]

    if cb_enable.lower() == 'true':
        main()
    else:
        print("Codebeamer integration disabled. Exiting attach_logs.py.")