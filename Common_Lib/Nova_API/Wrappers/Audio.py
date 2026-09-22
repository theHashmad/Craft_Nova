"""
This module provides a wrapper for the Audio gRPC service.
It enables audio playback and volume control operations via remote server.

    Author:
        Mina Bikhit
    Created date: 18-11-2025
"""

import grpc
from Common_Lib.G4_API.Wrappers.grpc_channel_manager import GrpcChannelManager
from Common_Lib.G4_API.Core import audio_pb2
from Common_Lib.G4_API.Core import audio_pb2_grpc

class Audio:
    @staticmethod
    def play_audio(ip_address, audio_file, volume):
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = audio_pb2_grpc.AudioServiceStub(channel)
        request = audio_pb2.AudioPlayRequest(audioFile=audio_file, volume=volume)
        response = stub.PlayAudio(request)
        return response

    @staticmethod
    def set_volume(ip_address, percent, group):
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = audio_pb2_grpc.AudioServiceStub(channel)
        request = audio_pb2.AudioSetVolumeRequest(percent=int(percent), group=str(group))
        response = stub.SetVolume(request)
        return response

    @staticmethod
    def increase_volume(ip_address, increase_value, group):
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = audio_pb2_grpc.AudioServiceStub(channel)
        request = audio_pb2.AudioIncreaseVolumeRequest(
            increase_value=int(increase_value),
            group=str(group)
        )
        response = stub.IncreaseVolume(request)
        return response

    @staticmethod
    def decrease_volume(ip_address, decrease_value, group):
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = audio_pb2_grpc.AudioServiceStub(channel)
        request = audio_pb2.AudioDecreaseVolumeRequest(
            decrease_value=int(decrease_value),
            group=str(group)
        )
        response = stub.DecreaseVolume(request)
        return response

    @staticmethod
    def stop_audio(ip_address):
        channel = GrpcChannelManager.get_channel(ip_address)
        stub = audio_pb2_grpc.AudioServiceStub(channel)
        request = audio_pb2.AudioStopPlayerRequest()
        response = stub.StopAudio(request)
        return response