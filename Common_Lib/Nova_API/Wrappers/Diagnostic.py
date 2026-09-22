import grpc
from typing import Optional
from Common_Lib.G4_API.Wrappers.grpc_channel_manager import GrpcChannelManager
from dataclasses import dataclass

from Common_Lib.G4_API.Core import diagnostic_pb2
from Common_Lib.G4_API.Core import diagnostic_pb2_grpc


@dataclass
class DiagnosticResponse:
    grpc_status: str
    code: Optional[int]
    message: Optional[str]
    data: Optional[list]


class Diagnostic:
    @staticmethod
    def execute_diagnostic_command(ip_address, name: Optional[str] = None, arguments: Optional[str] = None) \
            -> DiagnosticResponse:
        # Establish a connection to the gRPC server
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = diagnostic_pb2_grpc.DiagnosticStub(channel)
        command = diagnostic_pb2.Command(name=name, arguments=arguments)
        request = diagnostic_pb2.CommandRequest(command=command)
        response_stream = stub.executeCommand(request)

        try:
            responses = [response for response in response_stream]
        except grpc.RpcError as e:
            return DiagnosticResponse(
                grpc_status="Error",
                code=e.code().value[0],
                message=e.details(),
                data=None
            )
        except Exception as e:
            return DiagnosticResponse(
                grpc_status="Error",
                code=None,
                message=str(e),
                data=None
            )
        else:
            return DiagnosticResponse(
                grpc_status="Ok",
                code=responses[-1].status,
                message=None,
                data=responses
            )
