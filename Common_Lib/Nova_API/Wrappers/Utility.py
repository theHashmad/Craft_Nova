import grpc

from Common_Lib.G4_API.Core.generator_subscription_pb2 import \
    Topic
from Common_Lib.G4_API.Core import grpc_simulation_pb2
from Common_Lib.G4_API.Core.messages import units_pb2, common_pb2


class Utility:

    @staticmethod
    def get_grpc_error_code_value(error_name: str) -> int:
        """Returns the integer value of a given enum for grpc error name from StatusCode."""
        return grpc.StatusCode[error_name].value[0]

    @staticmethod
    def get_response_status_value(status_name: str) -> int:
        """Returns the integer value of a given grpc response enum name from Status."""
        return common_pb2.Status.Value(status_name)

    @staticmethod
    def get_rf_status_value(status_name: str) -> int:
        """Returns the integer value of a given enum name from RfStatus."""
        return grpc_simulation_pb2.RfValueStatus.Value(status_name)

    @staticmethod
    def get_cath_state_value(state_name: str) -> int:
        """Returns the integer value of a given enum name from Catheter State."""
        return units_pb2.CatheterState.Value(state_name)

    @staticmethod
    def get_pc_state_value(state_name: str) -> int:
        """Returns the integer value of a given enum name from PatientCircuitState."""
        return units_pb2.PatientCircuitState.Value(state_name)

    @staticmethod
    def get_displ_state_value(state_name: str) -> int:
        """Returns the integer value of a given enum name from DisplayState."""
        displ_states= {'kStartup': 0,
                        'kGpEntry': 1,
                        'kGpStartup': 2,
                        'kGpPost': 3,
                        'kGpFault': 4,
                        'kGpStandby': 5,
                        'kGpTherapyReady': 6,
                        'kGpTherapyAblate': 7,
                        'kGpTherapyStopped': 8,
                        'kGpTherapyInSheath': 9,
                        'kSetup': 10,
                        'kSetupFirstTime': 11,
                        'kReport': 12,
                        'kSettings': 13,
        }
        return displ_states[state_name]

    @staticmethod
    def create_expected_temp_status(temp_channels, status_channels):
        temps = [float(temp) for temp in temp_channels]
        statuses = [int(grpc_simulation_pb2.TemperatureStatus.Value(status)) for
                    status in status_channels]
        expected_temps = [
            {"value": temps[i], "status": statuses[i]}
            for i in range(4)
        ]
        return expected_temps

    @staticmethod
    def get_topic_string(notice):
        return Topic.Name(notice.topic)

    @staticmethod
    def get_temperature_status_string(status_value: int) -> str:
        """
        Convert integer temperature status to string temperature status.

        Args:
            status_value (int): Integer value of the temperature status

        Returns:
            str: String name of the temperature status

        Example:
            >>> Utility.get_temperature_status_string(0)
            'TEMPERATURE_STATUS_UNSPECIFIED'
            >>> Utility.get_temperature_status_string(1)
            'NORMAL'
        """
        try:
            return grpc_simulation_pb2.TemperatureStatus.Name(status_value)
        except ValueError as e:
            raise ValueError(f"Invalid temperature status value: {status_value}. Error: {e}")
