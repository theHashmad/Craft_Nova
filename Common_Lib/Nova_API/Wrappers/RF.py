import grpc
from google.protobuf import duration_pb2
from Common_Lib.G4_API.Wrappers.grpc_channel_manager import GrpcChannelManager

from Common_Lib.G4_API.Core import grpc_simulation_pb2
from Common_Lib.G4_API.Core import grpc_simulation_pb2_grpc


class ComplexRFChangeEntry:
    def __init__(self, shape, oscillation_value, transition_time_sec,
                 transition_time_nano_seconds):
        self.dict = {
            "change": {
                "shape": shape,
                "oscillationValue": oscillation_value
            },
            "transitionTime": {
                "seconds": transition_time_sec,
                "nanos": transition_time_nano_seconds
            }
        }


class RF:
    @staticmethod
    def rf_instant_set(ip_address, electrodes: list, new_impedance: float,
                       new_power_accuracy: float, new_power_delay: int):
        """
        Simple RF change
        """
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = grpc_simulation_pb2_grpc.GrpcSimulationStub(channel)
        rf_change = grpc_simulation_pb2.RfChange(newImpedance=new_impedance,
                                                 newPowerAccuracy=new_power_accuracy,
                                                 newPowerDelay=new_power_delay)
        change_variant = grpc_simulation_pb2.RfChangeVariant(simple=rf_change)
        changes = {}

        for electrode in electrodes:
            changes[int(electrode)] = change_variant

        request = grpc_simulation_pb2.RfChangeRequest(
            device=grpc_simulation_pb2.SimulatedDevice.kRf, changes=changes)
        response = stub.setRfData(request)

        return response
    
    @staticmethod
    def send_rf_button_request(ip_address, depressed_duration_ms= 100):
        """
        Simulate RF button press 
        """
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = grpc_simulation_pb2_grpc.GrpcSimulationStub(channel)

        duration = duration_pb2.Duration()
        duration.seconds = depressed_duration_ms // 1000
        duration.nanos = (depressed_duration_ms % 1000) * 1000000

        request = grpc_simulation_pb2.RfButtonChangeRequest(
            device=grpc_simulation_pb2.SimulatedDevice.kRf,
            depressedDuration=duration
        )
        response = stub.setRfButton(request)

        return response
    
    @staticmethod
    def rf_gradual_set(ip_address, electrodes: list, new_impedance: float,
                       new_power_accuracy: float,
                       new_power_delay: int,
                       imp_change=None,
                       pow_acc_change=None,
                       pow_delay_change=None):
        """
        Complex RF change
        """
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = grpc_simulation_pb2_grpc.GrpcSimulationStub(channel)

        rf_change = grpc_simulation_pb2.RfChange(newImpedance=new_impedance,
                                                 newPowerAccuracy=new_power_accuracy,
                                                 newPowerDelay=new_power_delay)
        imp_change_entry = None
        if imp_change != '':
            imp_change = eval(imp_change)
            imp_change_entry = ComplexRFChangeEntry(shape=imp_change[0],
                                                    oscillation_value=
                                                    imp_change[1],
                                                    transition_time_sec=
                                                    imp_change[
                                                        2],
                                                    transition_time_nano_seconds=
                                                    imp_change[3]).dict

        power_acc_change_entry = None
        if pow_acc_change != '':
            pow_acc_change = eval(pow_acc_change)
            power_acc_change_entry = ComplexRFChangeEntry(
                shape=pow_acc_change[0],
                oscillation_value=
                pow_acc_change[1],
                transition_time_sec=
                pow_acc_change[2],
                transition_time_nano_seconds=
                pow_acc_change[3]).dict

        power_delay_change_entry = None
        if pow_delay_change != '':
            pow_delay_change = eval(pow_delay_change)
            power_delay_change_entry = ComplexRFChangeEntry(
                shape=pow_delay_change[0],
                oscillation_value=pow_delay_change[1],
                transition_time_sec=pow_delay_change[2],
                transition_time_nano_seconds=pow_delay_change[3]).dict

        rf_complex_change = grpc_simulation_pb2.RfComplexChange(
            newRfValues=rf_change, changeImpedance=imp_change_entry,
            changePowerAccuracy=power_acc_change_entry,
            changePowerDelay=power_delay_change_entry)

        change_variant = grpc_simulation_pb2.RfChangeVariant(
            complex=rf_complex_change)
        changes = {}

        for electrode in electrodes:
            changes[int(electrode)] = change_variant
        request = grpc_simulation_pb2.RfChangeRequest(
            device=grpc_simulation_pb2.SimulatedDevice.kRf, changes=changes)
        response = stub.setRfData(request)

        return response

    @staticmethod
    def press_rf_button(ip_address, depressed_duration_ms=100):
        """
        Simulate RF button press
        """
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = grpc_simulation_pb2_grpc.GrpcSimulationStub(channel)

        duration = duration_pb2.Duration()
        duration.seconds = depressed_duration_ms // 1000
        duration.nanos = (depressed_duration_ms % 1000) * 1000000

        request = grpc_simulation_pb2.RfButtonChangeRequest(
            device=grpc_simulation_pb2.SimulatedDevice.kRf,
            depressedDuration=duration
        )
        response = stub.setRfButton(request)

        return response
