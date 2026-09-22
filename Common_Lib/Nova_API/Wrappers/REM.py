import grpc
from Common_Lib.G4_API.Wrappers.grpc_channel_manager import GrpcChannelManager
from Common_Lib.G4_API.Core import rem_api_pb2
from Common_Lib.G4_API.Core import rem_api_pb2_grpc
from Common_Lib.G4_API.Core import grpc_simulation_pb2
from Common_Lib.G4_API.Core import grpc_simulation_pb2_grpc as grpc_simulation_pb2_grpc
from Common_Lib.G4_API.Core.messages import common_pb2
from Common_Lib.G4_API.Core.messages import units_pb2


class REM:
    @staticmethod
    def rem_reset(ip_address):
        """
        Rem Reset call to the Generator API
        """
        # Establish a connection to the gRPC server
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = rem_api_pb2_grpc.RemAPIStub(channel)
        request = rem_api_pb2.RemResetRequest(init=True)
        response = stub.RemReset(request)

        return response

    @staticmethod
    def rem_calibrate(ip_address, amp, freq):
        """
        Rem Calibrate call to the Generator API
        """
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = rem_api_pb2_grpc.RemAPIStub(channel)
        calibrate_request = rem_api_pb2.RemCalibrateRequest(amplitude=int(amp), freq=int(freq))
        calibrate_response = stub.RemCalibrate(calibrate_request)

        return calibrate_response

    @staticmethod
    def rem_measure(ip_address, amp, freq):
        """
        Rem Measure call to the Generator API
        """
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = rem_api_pb2_grpc.RemAPIStub(channel)
        measure_request = rem_api_pb2.RemMeasureRequest(amplitude=int(amp), freq=int(freq))
        measure_response = stub.RemMeasure(measure_request)

        return measure_response

    @staticmethod
    def set_rem(ip_address, magnitude, phase, load):
        load_map = {
            'kTestLoad0': common_pb2.kTestLoad0,
            'kTestLoad20': common_pb2.kTestLoad20,
            'kTestLoad100': common_pb2.kTestLoad100,
            'kExternalLoad': common_pb2.kExternalLoad
        }

        impedance = units_pb2.Impedance(
            magnitude=float(magnitude),
            phase=float(phase)
        )

        # Create the RemChangeRequest message
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = grpc_simulation_pb2_grpc.GrpcSimulationStub(channel)

        try:
            request = grpc_simulation_pb2.RemChangeRequest(
                device=grpc_simulation_pb2.SimulatedDevice.kRem,
                newLoad=load_map[load],
                newImpedance=impedance
            )
            # Send grpc request and receive response
            try:
                response = stub.setRem(request)
                return response
            except grpc._channel._InactiveRpcError:
                raise ConnectionError("Could not connect to gRPC server")
        except KeyError as e:
            response = {"status": 'KeyError', "code": str(e)}
            return response
