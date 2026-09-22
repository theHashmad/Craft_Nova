import signal
import csv
import json
import argparse
import time
import datetime
from datetime import datetime, timedelta
import threading
import os

import grpc
from google.protobuf import empty_pb2 as empty_pb2
from google.protobuf.json_format import MessageToDict

from Common_Lib.G4_API.Core import data_recorder_pb2_grpc as data_recorderAPI

def save_notices_to_csv(notices, filename=None):
    """Save notices to a CSV file with structured columns for HDD data."""
    if not notices:
        print("No notices to save.")
        return
    
    if filename is None:
        # Generate filename with timestamp and save to Test_Data/HDD_PlayBack/Recorded
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        # Get the project root directory (this file is in Common_Lib/G4_API/Wrappers)
        current_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(os.path.dirname(os.path.dirname(current_dir)))
        output_dir = os.path.join(project_root, "Test_Data", "HDD_PlayBack", "Recorded")
        
        # Create directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        filename = os.path.join(output_dir, f"hdd_notices_{timestamp}.csv")
    
    # Define CSV fieldnames based on HDD notice structure
    fieldnames = [
        'index', 'timestamp', 'healthIndication', 'ablationRecordId', 'faultSummary',
        'remImpedance_magnitude', 'remImpedance_phase', 'remStatus', 'generatorState', 'rfState'
    ]
    
    # Add electrode-specific fields (assuming 4 electrodes)
    for i in range(4):
        electrode_num = i + 1
        fieldnames.extend([
            f'electrode_{electrode_num}_temperature_value',
            f'electrode_{electrode_num}_temperature_status',
            f'electrode_{electrode_num}_power_value',
            f'electrode_{electrode_num}_power_status',
            f'electrode_{electrode_num}_impedance_value',
            f'electrode_{electrode_num}_impedance_status',
            f'electrode_{electrode_num}_seqImpedance_value',
            f'electrode_{electrode_num}_seqImpedance_status',
            f'electrode_{electrode_num}_avgTemperature_value',
            f'electrode_{electrode_num}_avgTemperature_status',
            f'electrode_{electrode_num}_avgImpedance_value',
            f'electrode_{electrode_num}_avgImpedance_status',
            f'electrode_{electrode_num}_seqAvgImpedance_value',
            f'electrode_{electrode_num}_seqAvgImpedance_status',
            f'electrode_{electrode_num}_electrodeStatus',
            f'electrode_{electrode_num}_toorStatus'
        ])
    
    csv_rows = []
    for i, notice in enumerate(notices):
        row = {
            'index': i + 1,
            'timestamp': notice.get('timestamp', ''),
            'healthIndication': notice.get('healthIndication', ''),
            'ablationRecordId': notice.get('ablationRecordId', ''),
            'faultSummary': notice.get('faultSummary', ''),
            'remImpedance_magnitude': notice.get('remImpedance', {}).get('magnitude', ''),
            'remImpedance_phase': notice.get('remImpedance', {}).get('phase', ''),
            'remStatus': notice.get('remStatus', ''),
            'generatorState': notice.get('generatorState', ''),
            'rfState': notice.get('rfState', '')
        }
        
        # Extract electrode data (handle up to 4 electrodes)
        electrode_arrays = ['temperatures', 'powers', 'impedances', 'seqImpedances', 
                           'avgTemperatures', 'avgImpedances', 'seqAvgImpedances']
        status_arrays = ['electrodeStatuses', 'toorStatuses']
        
        for electrode_idx in range(4):
            electrode_num = electrode_idx + 1
            
            # Handle measurement arrays with value and status
            for array_name in electrode_arrays:
                array_data = notice.get(array_name, [])
                if electrode_idx < len(array_data):
                    item = array_data[electrode_idx]
                    if isinstance(item, dict):
                        row[f'electrode_{electrode_num}_{array_name[:-1]}_value'] = item.get('value', '')
                        row[f'electrode_{electrode_num}_{array_name[:-1]}_status'] = item.get('status', '')
                    else:
                        row[f'electrode_{electrode_num}_{array_name[:-1]}_value'] = item
                        row[f'electrode_{electrode_num}_{array_name[:-1]}_status'] = ''
                else:
                    row[f'electrode_{electrode_num}_{array_name[:-1]}_value'] = ''
                    row[f'electrode_{electrode_num}_{array_name[:-1]}_status'] = ''
            
            # Handle status arrays
            electrode_statuses = notice.get('electrodeStatuses', [])
            toor_statuses = notice.get('toorStatuses', [])
            
            row[f'electrode_{electrode_num}_electrodeStatus'] = (
                electrode_statuses[electrode_idx] if electrode_idx < len(electrode_statuses) else ''
            )
            row[f'electrode_{electrode_num}_toorStatus'] = (
                toor_statuses[electrode_idx] if electrode_idx < len(toor_statuses) else ''
            )
        
        csv_rows.append(row)
    
    try:
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(csv_rows)
        print(f"Successfully saved {len(notices)} notices to {filename}")
        print(f"CSV contains {len(fieldnames)} columns with electrode-specific data")
    except Exception as e:
        print(f"Error saving to CSV: {e}")

def _flatten_dict(d, parent_key='', sep='_'):
    """Recursively flatten a nested dictionary."""
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(_flatten_dict(v, new_key, sep=sep).items())
        elif isinstance(v, list):
            # Handle lists by converting to JSON string or creating indexed entries
            if v and isinstance(v[0], dict):
                # If list contains dictionaries, flatten each with index
                for i, item in enumerate(v):
                    if isinstance(item, dict):
                        items.extend(_flatten_dict(item, f"{new_key}_{i}", sep=sep).items())
                    else:
                        items.append((f"{new_key}_{i}", item))
            else:
                # Simple list - convert to JSON string
                items.append((new_key, json.dumps(v)))
        else:
            items.append((new_key, v))
    return dict(items)

def listen_to_hdd(server_address, output_file, recording_count=None, duration=None):
    """Listens to High Density data notices for a specified count or duration with retry logic."""
    if not server_address:
        raise ValueError("Server address must be specified")
    
    if recording_count is None and duration is None:
        raise ValueError("Either recording_count or duration must be specified")

    # Fixed maximum retries for all recording types
    max_retries = 30
    
    print(f"Max retries: {max_retries}")

    empty_req = empty_pb2.Empty()
    count = 0
    start_time = time.time()
    first_notice_time = None
    retry_count = 0

    notices_collected = []

    # Setup signal handling for graceful shutdown
    def cancel_request(sig, frame):
        print(f"\nReceived interrupt signal. Saving {len(notices_collected)} notices to {output_file}")
        if notices_collected:
            save_notices_to_csv(notices_collected, output_file)
        return True

    signal.signal(signal.SIGINT, cancel_request)

    while retry_count <= max_retries:
        try:
            if retry_count > 0:
                print(f"Retry {retry_count}/{max_retries} - Connecting to {server_address}...")
            else:
                print(f"Connecting to {server_address}...")
            
            # Configure channel options for connection resilience
            channel_options = [
                ('grpc.keepalive_time_ms', 30000),
                ('grpc.keepalive_timeout_ms', 5000),
                ('grpc.keepalive_permit_without_calls', True),
                ('grpc.http2.max_pings_without_data', 0),
                ('grpc.http2.min_time_between_pings_ms', 10000),
            ]
            
            with grpc.insecure_channel(server_address, options=channel_options) as channel:
                stub = data_recorderAPI.DataRecorderServiceStub(channel)
                resp_stream = stub.ListenToHighDensityDataNotices(empty_req)
                
                print("Connected! Recording notices...")
                
                for notice in resp_stream:
                    count += 1
                    notice_dict = MessageToDict(notice,
                                              preserving_proto_field_name=True,
                                              always_print_fields_with_no_presence=True)
                    notices_collected.append(notice_dict)
                    
                   
                    # Parse timestamp for duration tracking
                    if first_notice_time is None and 'timestamp' in notice_dict:
                        try:
                            first_notice_time = datetime.fromisoformat(
                                notice_dict['timestamp'].replace('Z', '+00:00')
                            )
                        except ValueError:
                            first_notice_time = datetime.now()
                    
                    # Check stopping conditions
                    if recording_count is not None and count >= recording_count:
                        print(f"Reached target count of {recording_count} notices")
                        save_notices_to_csv(notices_collected, output_file)
                        return True
                    
                    if duration is not None and first_notice_time:
                        if 'timestamp' in notice_dict:
                            try:
                                current_time = datetime.fromisoformat(
                                    notice_dict['timestamp'].replace('Z', '+00:00')
                                )
                                elapsed = (current_time - first_notice_time).total_seconds()
                                if elapsed >= duration:
                                    print(f"Reached target duration of {duration} seconds")
                                    save_notices_to_csv(notices_collected, output_file)
                                    return True
                            except ValueError:
                                elapsed = time.time() - start_time
                                if elapsed >= duration:
                                    save_notices_to_csv(notices_collected, output_file)
                                    return True
                
                # Stream ended normally
                print(f"Stream ended. Collected {count} notices total.")
                if notices_collected:
                    save_notices_to_csv(notices_collected, output_file)
                return True
                    
        except (grpc.RpcError, ConnectionError, OSError) as error:
            error_msg = str(error)
            
            if "10054" in error_msg or "connection reset" in error_msg.lower():
                if retry_count < max_retries:
                    backoff_time = 0.2  # Fixed 0.2-second delay
                    print(f"Connection reset detected. Retrying in {backoff_time} seconds... ({retry_count + 1}/{max_retries})")
                    time.sleep(backoff_time)
                    retry_count += 1
                    continue
                else:
                    print(f"Connection failed after {max_retries} retries: {error_msg}")
                    if notices_collected:
                        save_notices_to_csv(notices_collected, output_file)
                    return len(notices_collected) > 0
            else:
                if retry_count < max_retries:
                    backoff_time = 0.2  # Fixed 0.2-second delay
                    print(f"Connection error: {error_msg}. Retrying in {backoff_time} seconds... ({retry_count + 1}/{max_retries})")
                    time.sleep(backoff_time)
                    retry_count += 1
                    continue
                else:
                    print(f"Connection failed after {max_retries} retries: {error_msg}")
                    if notices_collected:
                        save_notices_to_csv(notices_collected, output_file)
                    return len(notices_collected) > 0
                    
        except Exception as error:
            print(f"Unexpected error: {str(error)}")
            if notices_collected:
                save_notices_to_csv(notices_collected, output_file)
            return len(notices_collected) > 0
    
    # All retries failed
    if notices_collected:
        save_notices_to_csv(notices_collected, output_file)
    return len(notices_collected) > 0


class HDDRecorder:
    """
    High Density Data Recorder class for programmatic control of HDD recording.
    Allows starting and stopping recording with flexible configuration.
    """

    def __init__(self, server_address, output_dir=None):
        """
        Initialize HDD Recorder.
        
        Args:
            server_address (str): Server address (default: "10.108.129.105:50051")
            output_dir (str): Directory to save output files (default: Test_Data/HDD_PlayBack/Recorded)
        """
        self.server_address = server_address
        
        if output_dir is None:
            # Default to Test_Data/HDD_PlayBack/Recorded directory (this file is in Common_Lib/G4_API/Wrappers)
            current_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(os.path.dirname(current_dir)))
            output_dir = os.path.join(project_root, "Test_Data", "HDD_PlayBack", "Recorded")
            # Create directory if it doesn't exist
            os.makedirs(output_dir, exist_ok=True)
        
        self.output_dir = output_dir
        self.is_recording = False
        self.recording_thread = None
        self.notices_collected = []
        self.stop_event = threading.Event()
        self.current_output_file = None
        
    def start_recording(self,output_filename=None):
        """
        Start recording HDD data in a separate thread.
        
        Args:
            recording_count (int): Number of notices to record (optional)
            duration (float): Duration in seconds to record (optional)
            output_filename (str): Custom output filename (optional, auto-generated if None)
            
        Returns:
            bool: True if recording started successfully, False otherwise
        """
        if self.is_recording:
            print("Recording is already in progress. Stop current recording first.")
            return False
            
            
        # Generate output filename if not provided
        if output_filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_filename = f"hdd_notices_{timestamp}.csv"
            
        self.current_output_file = f"{self.output_dir}/{output_filename}".replace("//", "/")
        self.notices_collected = []
        self.stop_event.clear()
        
        # Start recording in a separate thread
        self.recording_thread = threading.Thread(
            target=self._recording_worker,
            daemon=True
        )
        
        self.is_recording = True
        self.recording_thread.start()
        
           
        print(f"Started recording to {self.current_output_file}")
        return True
        
    def stop_recording(self, save_data=True):
        """
        Stop the current recording.
        
        Args:
            save_data (bool): Whether to save collected data to CSV (default: True)
            
        Returns:
            dict: Recording summary with count and filename
        """

        # Check if we have a recording thread or collected notices, even if is_recording is False
        if not self.is_recording and (not self.recording_thread or not self.notices_collected):
            print("No recording is currently in progress.")
            return {"success": False, "message": "No recording in progress"}
        
        print("Stopping recording...")
        self.stop_event.set()
        
        # Wait for recording thread to finish
        if self.recording_thread and self.recording_thread.is_alive():
            self.recording_thread.join(timeout=5.0)  # Wait up to 5 seconds
            
        self.is_recording = False
        save_notices_to_csv(self.notices_collected, self.current_output_file)

        
        
    def get_recording_status(self):
        """
        Get current recording status.
        
        Returns:
            dict: Status information including recording state and progress
        """
        return {
            "is_recording": self.is_recording,
            "notices_collected": len(self.notices_collected),
            "current_output_file": self.current_output_file,
            "server_address": self.server_address,
            "thread_alive": self.recording_thread.is_alive() if self.recording_thread else False
        }
        
    def _recording_worker(self):
        """
        Internal worker method that runs the actual recording in a separate thread.
        
        Args:
            recording_count (int): Number of notices to record
            duration (float): Duration in seconds to record
        """
        try:
            empty_req = empty_pb2.Empty()
            count = 0
            start_time = time.time()
            first_notice_time = None
            
            # Configure aggressive channel options to overcome server-side 30s timeout
            channel_options = [
                ('grpc.keepalive_time_ms', 15000),  # Send keepalive every 15 seconds
                ('grpc.keepalive_timeout_ms', 3000),  # Short timeout for fast detection
                ('grpc.keepalive_permit_without_calls', True),
                ('grpc.http2.max_pings_without_data', 0),  # Allow unlimited pings
                ('grpc.http2.min_time_between_pings_ms', 5000),  # Allow pings every 5s
                ('grpc.http2.min_ping_interval_without_data_ms', 15000),  # Ping every 15s
                ('grpc.http2.max_connection_idle_ms', 0),  # Never idle timeout
                ('grpc.http2.max_connection_age_ms', 0),   # Never age timeout
                ('grpc.max_receive_message_length', 8 * 1024 * 10240),  # 8MB
                ('grpc.max_send_message_length', 8 * 1024 * 10240),    # 8MB
                ('grpc.so_reuseport', 1),  # Allow socket reuse
                ('grpc.tcp_user_timeout_ms', 600000),  # 60 second TCP timeout
            ]
            
            with grpc.insecure_channel(self.server_address, options=channel_options) as channel:
                stub = data_recorderAPI.DataRecorderServiceStub(channel)
                # Remove explicit timeout to use channel-level configuration
                resp_stream = stub.ListenToHighDensityDataNotices(empty_req)

                print(f"Connected to {self.server_address}! Recording notices...")

                for notice in resp_stream:
                    count += 1
                    
                    # Minimize thread overhead - check stop event less frequently
                    if count % 20 == 0 and self.stop_event.is_set():
                        print("Recording stopped by user request.")
                        break
                    notice_dict = MessageToDict(notice,
                                              preserving_proto_field_name=True,
                                              always_print_fields_with_no_presence=True)
                    self.notices_collected.append(notice_dict)
                    
                    # Progress reporting every 10 notices
                    if count % 10 == 0:
                        print(f"Collected {count} notices...")
                    
                    # Parse timestamp for duration tracking
                    if first_notice_time is None and 'timestamp' in notice_dict:
                        try:
                            first_notice_time = datetime.fromisoformat(
                                notice_dict['timestamp'].replace('Z', '+00:00')
                            )
                        except ValueError:
                            first_notice_time = datetime.now()
                    
                    # Recording continues until stop_event is set
                
                print(f"Recording completed. Collected {count} notices total.")
                
        except grpc.RpcError as error:
            print(f"gRPC error during recording: {error.code()} - {error.details()}")
            if error.code() == grpc.StatusCode.DEADLINE_EXCEEDED:
                print("Recording stopped due to server timeout (DEADLINE_EXCEEDED) - attempting reconnection...")
                # Try to reconnect and continue recording
                if not self.stop_event.is_set():
                    print("Attempting to reconnect after timeout...")
                    time.sleep(1)
                    return self._recording_worker()  # Recursive retry
            elif error.code() == grpc.StatusCode.UNAVAILABLE:
                print("Recording stopped due to server unavailable - attempting reconnection...")
                if not self.stop_event.is_set():
                    time.sleep(2)
                    return self._recording_worker()  # Recursive retry
        except (ConnectionError, OSError) as error:
            print(f"Connection error during recording: {str(error)} - attempting reconnection...")
            if not self.stop_event.is_set():
                time.sleep(1)
                return self._recording_worker()  # Recursive retry
        except Exception as error:
            print(f"Unexpected recording error: {str(error)}")
        finally:
            print(f"Recording completed. Collected {len(self.notices_collected)} notices")
            self.is_recording = False


if __name__ == "__main__":
    # Set up command-line argument parsing
    parser = argparse.ArgumentParser(description='4th Generation RDN Symplicity High Density Data Recorder - Listen to High Density Data notices and save to CSV')
    parser.add_argument('--server_address', '-s', 
                       default="10.108.129.105:50051",
                       help='Server address and port (default: 10.108.129.105:50051)')
    
    # Recording options - mutually exclusive group
    recording_group = parser.add_mutually_exclusive_group()
    recording_group.add_argument('--recording_count', '-c', 
                                type=int, 
                                help='Number of notices to record')
    recording_group.add_argument('--duration', '-d', 
                                type=float,
                                help='Duration in seconds to record (e.g., 10.5 for 10.5 seconds)')
    
    # Parse arguments
    args = parser.parse_args()
    
    # Set defaults if neither option is specified
    if args.recording_count is None and args.duration is None:
        args.recording_count = 5
        print("No recording option specified, defaulting to 5 notices")
    
    print(f"Connecting to server: {args.server_address}")
    
    # Generate output filename with timestamp and save to Test_Data/HDD_PlayBack/Recorded
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # Get the project root directory (this file is in Common_Lib/G4_API/Wrappers)
    current_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(current_dir)))
    output_dir = os.path.join(project_root, "Test_Data", "HDD_PlayBack", "Recorded")
    
    # Create directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    output_file = os.path.join(output_dir, f"hdd_notices_{timestamp}.csv")
    
    # Determine recording description
    if args.recording_count:
        recording_description = f"{args.recording_count} notices"
    else:
        recording_description = f"{args.duration} seconds"
    
    print(f"Recording {recording_description} to {output_file}")
    print("Press Ctrl+C to stop...")
    
    
    # Listen and record with improved connection handling
    success = listen_to_hdd(args.server_address, output_file,
                           recording_count=args.recording_count, 
                           duration=args.duration)
    
    if success:
        print(f"\nRecording completed successfully. Data saved to {output_file}")
    else:
        print("\nRecording failed after all retry attempts.")