"""
This module provides a wrapper for the AblationInfo gRPC service.
It enables case management operations (open, close, get current case) via remote server.

    Author:
        Mina Bikhit
    Created date: 15-APR-2026
"""

import grpc
from Common_Lib.G4_API.Core import ablation_info_pb2
from Common_Lib.G4_API.Core import ablation_info_pb2_grpc


class AblationInfo:
    @staticmethod
    def open_case(ip_address, case_name):
        """
        Open a new case on the generator.

        Args:
            ip_address: gRPC server address (host:port)
            case_name: Name of the case to open

        Returns:
            OpenCaseResponse containing case_info (id, name, timestamp)
        """
        channel = grpc.insecure_channel(ip_address)
        stub = ablation_info_pb2_grpc.AblationInfoServiceStub(channel)
        request = ablation_info_pb2.OpenCaseRequest(case_name=str(case_name))
        response = stub.OpenCase(request)
        return response

    @staticmethod
    def close_case(ip_address, case_id=None):
        """
        Close an existing case on the generator.

        Args:
            ip_address: gRPC server address (host:port)
            case_id: ID of the case to close (optional)

        Returns:
            CloseCaseResponse
        """
        channel = grpc.insecure_channel(ip_address)
        stub = ablation_info_pb2_grpc.AblationInfoServiceStub(channel)
        if case_id is not None:
            if isinstance(case_id, (list, tuple)):
                case_id = case_id[0]
            request = ablation_info_pb2.CloseCaseRequest(case_id=int(case_id))
        else:
            request = ablation_info_pb2.CloseCaseRequest()
        response = stub.CloseCase(request)
        return response

    @staticmethod
    def get_current_case_info(ip_address):
        """
        Get information about the currently open case.

        Args:
            ip_address: gRPC server address (host:port)

        Returns:
            GetCurrentCaseInfoResponse containing case_info (id, name, timestamp)
        """
        channel = grpc.insecure_channel(ip_address)
        stub = ablation_info_pb2_grpc.AblationInfoServiceStub(channel)
        request = ablation_info_pb2.GetCurrentCaseInfoRequest()
        response = stub.GetCurrentCaseInfo(request)
        return response

