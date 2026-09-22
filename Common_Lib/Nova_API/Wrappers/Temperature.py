"""
This module collects implementation of the simulated set temperature
command.
This fulfills [USSW-43627] Integrate protobuff grpc into SW Test Framework

    Author:
        Author: Kala Subbaraman
        Created date: 04-21-2025
        Modified date: 07-11-2025

"""
import grpc
from Common_Lib.G4_API.Wrappers.grpc_channel_manager import GrpcChannelManager
from Common_Lib.G4_API.Core import grpc_simulation_pb2
from Common_Lib.G4_API.Core import grpc_simulation_pb2_grpc


class Temperature:
    @staticmethod
    def set_temperature(ip_address,
                       Status_0, Temp_0,
                       Status_1, Temp_1,
                       Status_2, Temp_2,
                       Status_3, Temp_3):
        changes_dict = {
            "0": {"Status": Status_0, "Temperature": float(Temp_0)},
            "1": {"Status": Status_1, "Temperature": float(Temp_1)},
            "2": {"Status": Status_2, "Temperature": float(Temp_2)},
            "3": {"Status": Status_3, "Temperature": float(Temp_3)},
        }

        changes = {
            int(k): grpc_simulation_pb2.TemperatureChange(
                newTemperature=v["Temperature"],
                newStatus=v["Status"],
            )
            for k,v in changes_dict.items()
        }

        channel = GrpcChannelManager.get_channel(ip_address)
        stub = grpc_simulation_pb2_grpc.GrpcSimulationStub(channel)
        request = grpc_simulation_pb2.TemperatureChangeRequest(device=grpc_simulation_pb2.SimulatedDevice.kTemperature,
                                                               changes=changes)

        response = stub.setTemperature(request)
        return response



