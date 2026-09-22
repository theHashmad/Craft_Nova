"""
This module collects implementation of the simulated subscription command.
This fulfills [USSW-60692] Integrate datarecorder protobuf into SW Test Framework

    Author:
        Author: Kala Subbaraman
        Created date: 07-03-2025

"""

import signal
import time

import grpc
from google.protobuf import empty_pb2 as empty_pb2
from google.protobuf.json_format import MessageToDict

from Common_Lib.G4_API.Core import data_recorder_pb2_grpc as data_recorderAPI


class DataRecorder:

    @staticmethod
    def listen_to_hdd(server_address):
        """Listens to High Density data notices and returns the 5th notice."""
        if not server_address:
            raise ValueError(
                "Server address and topics must be set before requesting subscription.")

        empty_req = empty_pb2.Empty()
        count = 0
        max_retries = 30
        retry_count = 0

        print(f"Max retries: {max_retries}")

        # Configure channel options for connection resilience
        channel_options = [
            ('grpc.keepalive_time_ms', 3000),
            ('grpc.keepalive_timeout_ms', 500),
            ('grpc.keepalive_permit_without_calls', False),
            ('grpc.http2.max_pings_without_data', 0),
            ('grpc.http2.min_time_between_pings_ms', 1000),
        ]

        # Track active stream so SIGINT can cancel blocking call safely
        active_stream = {'resp_stream': None}

        def cancel_request(sig, frame):
            if active_stream['resp_stream']:
                active_stream['resp_stream'].cancel()

        signal.signal(signal.SIGINT, cancel_request)

        while retry_count <= max_retries:
            try:
                if retry_count > 0:
                    print(f"Retry {retry_count}/{max_retries} - Connecting to {server_address}...")
                else:
                    print(f"Connecting to {server_address}...")

                with grpc.insecure_channel(server_address, options=channel_options) as channel:
                    stub = data_recorderAPI.DataRecorderServiceStub(channel)

                    resp_stream = stub.ListenToHighDensityDataNotices(empty_req)
                    active_stream['resp_stream'] = resp_stream

                    print("Connected! Listening for notices...")

                    for notice in resp_stream:
                        count += 1
                        if count == 5:
                            return MessageToDict(notice,
                                                 preserving_proto_field_name=True,
                                                 always_print_fields_with_no_presence=True)

                    print("Stream ended before receiving the fifth notice.")
                    return None

            except (grpc.RpcError, ConnectionError, OSError) as error:
                error_msg = str(error)

                if isinstance(error, grpc.RpcError) and error.code() == grpc.StatusCode.DEADLINE_EXCEEDED:
                    print("Timed out waiting for High Density notices.")
                    return None

                if "10054" in error_msg or "connection reset" in error_msg.lower():
                    if retry_count < max_retries:
                        backoff_time = 0.2
                        print(f"Connection reset detected. Retrying in {backoff_time} seconds... ({retry_count + 1}/{max_retries})")
                        time.sleep(backoff_time)
                        retry_count += 1
                        continue

                    print(f"Connection failed after {max_retries} retries: {error_msg}")
                    return None

                if retry_count < max_retries:
                    backoff_time = 0.2
                    print(f"Connection error: {error_msg}. Retrying in {backoff_time} seconds... ({retry_count + 1}/{max_retries})")
                    time.sleep(backoff_time)
                    retry_count += 1
                    continue

                print(f"Connection failed after {max_retries} retries: {error_msg}")
                return None

            except Exception as error:
                print(f"Unexpected error: {str(error)}")
                return None

            finally:
                active_stream['resp_stream'] = None

        print(f"Unable to connect after {max_retries} retries.")
        return None
