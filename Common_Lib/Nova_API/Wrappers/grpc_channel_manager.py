"""
Singleton gRPC channel manager.

Maintains one persistent ``grpc.insecure_channel`` per server address so that
all wrapper classes share the same already-READY HTTP/2 connection rather than
opening a new TCP handshake on every call.

Usage (inside any wrapper)::

    from Common_Lib.G4_API.Wrappers.grpc_channel_manager import GrpcChannelManager

    channel = GrpcChannelManager.get_channel(ip_address)
    stub    = some_pb2_grpc.SomeStub(channel)
    response = stub.SomeMethod(request, timeout=10)
"""

import threading
import grpc


class GrpcChannelManager:
    """Class-level singleton: one channel per server address."""

    _lock: threading.Lock = threading.Lock()
    _channels: dict = {}   # {ip_address: grpc.Channel}

    # Default channel options applied to every new channel.
    # keepalive_time_ms  – how often to send HTTP/2 pings to keep the connection
    #                      alive. Set to 60s to avoid ENHANCE_YOUR_CALM / too_many_pings
    #                      rejections from servers that enforce a minimum ping interval.
    # keepalive_timeout_ms – how long to wait for the ping ACK before closing.
    # keepalive_permit_without_calls – disabled (0) so pings are only sent while
    #                      there are active RPCs, further reducing ping frequency.
    _DEFAULT_OPTIONS = [
            ('grpc.keepalive_time_ms', 3000),
            ('grpc.keepalive_timeout_ms', 500),
            ('grpc.keepalive_permit_without_calls', False),
            ('grpc.http2.max_pings_without_data', 0),
            ('grpc.http2.min_time_between_pings_ms', 1000),
    ]

    @classmethod
    def get_channel(cls, ip_address: str) -> grpc.Channel:
        """Return the cached channel for *ip_address*, creating it if needed.

        Thread-safe: a lock ensures only one channel is ever created per address
        even when multiple Robot Framework keywords run concurrently.
        """
        with cls._lock:
            if ip_address not in cls._channels:
                cls._channels[ip_address] = grpc.insecure_channel(
                    ip_address, options=cls._DEFAULT_OPTIONS
                )
            return cls._channels[ip_address]

    @classmethod
    def close_channel(cls, ip_address: str) -> None:
        """Close and remove the cached channel for *ip_address*."""
        with cls._lock:
            channel = cls._channels.pop(ip_address, None)
        if channel is not None:
            channel.close()

    @classmethod
    def close_all(cls) -> None:
        """Close every managed channel (call from suite teardown if needed)."""
        with cls._lock:
            channels = list(cls._channels.values())
            cls._channels.clear()
        for channel in channels:
            channel.close()
