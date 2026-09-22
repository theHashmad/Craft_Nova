import grpc
import queue
import threading
import time
from google.protobuf.json_format import MessageToDict

from Common_Lib.G4_API.Core import \
    generator_subscription_pb2 as subscriptionAPI_msg
from Common_Lib.G4_API.Core import \
    generator_subscription_pb2_grpc as subscriptionAPI
from Common_Lib.G4_API.Wrappers.grpc_channel_manager import GrpcChannelManager

# Mapping of every known topic name to its proto enum value.
# Kept in sync with generator_subscription_pb2.pyi.
data = {
    "kNone":               subscriptionAPI_msg.kNone,
    "kRouter":             subscriptionAPI_msg.kRouter,
    "kRfChannelData":      subscriptionAPI_msg.kRfChannelData,
    "kTemperature":        subscriptionAPI_msg.kTemperature,
    "kRfControl":          subscriptionAPI_msg.kRfControl,
    "kRem":                subscriptionAPI_msg.kRem,
    "kAblationData":       subscriptionAPI_msg.kAblationData,
    "kDiagnosticData":     subscriptionAPI_msg.kDiagnosticData,
    "kLog":                subscriptionAPI_msg.kLog,
    "kRfCli":              subscriptionAPI_msg.kRfCli,
    "kSimulation":         subscriptionAPI_msg.kSimulation,
    "kHighDensityData":    subscriptionAPI_msg.kHighDensityData,
    "kCatheter":           subscriptionAPI_msg.kCatheter,
    "kPatientCircuit":     subscriptionAPI_msg.kPatientCircuit,
    "kGenerator":          subscriptionAPI_msg.kGenerator,
    "kPost":               subscriptionAPI_msg.kPost,
    "kAudio":              subscriptionAPI_msg.kAudio,
    "kDisplay":            subscriptionAPI_msg.kDisplay,
    "kEepromData":         subscriptionAPI_msg.kEepromData,
    "kError":              subscriptionAPI_msg.kError,
    "kUserSettings":       subscriptionAPI_msg.kUserSettings,
    "kOrcaData":           subscriptionAPI_msg.kOrcaData,
    "kOrcaDiagnosticData": subscriptionAPI_msg.kOrcaDiagnosticData,
    "kManufacturing":      subscriptionAPI_msg.kManufacturing,
    "kMax":                subscriptionAPI_msg.kMax,
}

# How long to wait between reconnect attempts (doubles up to _MAX_BACKOFF).
_INITIAL_BACKOFF = 1
_MAX_BACKOFF     = 30


class Topic_Listener:
    """Lightweight Robot Framework library keyword class for gRPC topic notices.

    Design principles
    -----------------
    * **Per-topic FIFO queue** — every incoming notice is enqueued; nothing is
      ever overwritten.  Fast-firing topics no longer silently discard the
      notice a test is waiting for.
    * **Per-topic Event** — waiters for topic X are not spuriously woken by a
      notice for topic Y.
    * **Race-free stream_notices_for** — the queue is drained and the per-topic
      event is cleared *before* the subscription stream is allowed to deliver
      new items, so the "notice arrives between drain and wait" gap is closed.
    * **Exponential back-off** on reconnect — transient gRPC errors do not
      flood logs; CANCELLED (intentional resubscription) skips the delay.
    * **No mid-wait stream cancellation** — `get_notice_for` never cancels the
      stream while a test is waiting, avoiding re-subscription gaps that would
      permanently lose one-shot state-change notices.
    """

    def __init__(self, server_address: str):
        self.server_address = server_address
        self.topics: list = []
        self._stop_event = threading.Event()

        # Per-topic LIFO queues — the listener thread is the sole *producer*;
        # get_notice_for / stream_notices_for are the sole *consumers*.
        # LifoQueue (stack) means get() always returns the *most recent* notice,
        # which is the correct semantic for one-shot state-change events.
        self._queues: dict[str, queue.LifoQueue] = {}
        self._queues_lock = threading.Lock()

        # Per-topic Events — set whenever a new item is put on that topic's
        # queue so waiters can block without busy-polling.
        self._topic_events: dict[str, threading.Event] = {}

        self._notice_counts: dict[str, int] = {}  # diagnostic counters
        self._notices_stream = None               # active gRPC stream handle

        self._listener_thread = threading.Thread(
            target=self._listen_to_topics, daemon=True)

    # ------------------------------------------------------------------
    # Public Robot Framework keywords
    # ------------------------------------------------------------------

    def start_topic_listener(self, *topic):
        """Subscribe to one or more topics and start (or restart) the stream.

        Accepts a single string, a single list, or multiple positional strings.
        Robot Framework passes each ``*topic`` argument as a separate value.
        """
        if len(topic) == 1 and isinstance(topic[0], list):
            new_topics = topic[0]
        else:
            new_topics = list(topic)

        self.topics.extend(new_topics)
        self.topics = list(set(self.topics))
        print(f"Starting topic listener for topic(s): {self.topics}...")

        # Provision fresh queues *before* the stream is (re)started so the
        # listener thread never writes to a queue that does not yet exist.
        with self._queues_lock:
            for t in new_topics:
                self._queues[t] = queue.LifoQueue()
                self._topic_events[t] = threading.Event()

        if self._listener_thread.is_alive():
            # Cancel the running stream so _listen_to_topics exits its inner
            # for-loop and immediately resubscribes with the updated topic list.
            self.cancel_notice_stream()
        else:
            self._ensure_listener_running()

    def get_notice_for(self, topic, timeout=15):
        """Block up to *timeout* seconds and return the most recent queued notice.

        An initial 1.5 s buffer is honoured before the first dequeue attempt
        so that the server has time to emit a notice after the action that
        triggered it.  The stream is never cancelled here — cancellation during
        a wait creates a re-subscription gap in which one-shot notices are lost.
        """
        _INITIAL_BUFFER = 1.5

        self._ensure_queue(topic)
        self._ensure_listener_running()

        time.sleep(_INITIAL_BUFFER)
        remaining = max(timeout - _INITIAL_BUFFER, 0)

        try:
            notice = self._queues[topic].get(timeout=remaining)
            print(f"Notice for topic '{topic}' received.")
            return notice
        except queue.Empty:
            print(f"No notice for topic '{topic}' found after {timeout}s.")
            return None

    def stream_notices_for(self, topic, timeout=5):
        """Return the **next** notice for *topic* that arrives after this call.

        Any notices already sitting in the queue (stale data from a previous
        action) are discarded before waiting, so the caller always receives a
        fresh notice.  Blocks efficiently using a per-topic Event.
        """
        self._ensure_queue(topic)
        self._ensure_listener_running()

        q   = self._queues[topic]
        evt = self._topic_events[topic]

        # --- race-free drain -------------------------------------------------
        # 1. Clear the event first (inside the lock that the listener also
        #    acquires when it signals) so no new arrival can be missed.
        # 2. Then drain the queue of any stale items.
        with self._queues_lock:
            evt.clear()
            while not q.empty():
                try:
                    q.get_nowait()
                except queue.Empty:
                    break
        # ---------------------------------------------------------------------

        deadline = time.time() + timeout

        while True:
            remaining = deadline - time.time()
            if remaining <= 0:
                break

            # Block until the listener signals this topic's event or we time out.
            evt.wait(timeout=remaining)
            evt.clear()

            try:
                notice = q.get_nowait()
                return notice
            except queue.Empty:
                pass  # spurious wakeup or another consumer raced us

            if not self._listener_thread.is_alive():
                print(f"[stream] Listener thread dead — restarting for '{topic}'...")
                self._ensure_listener_running()

        print(f"No notice for topic '{topic}' found after {timeout}s.")
        return None

    def cancel_notice_stream(self):
        """Cancel the active streaming RPC (triggers an immediate resubscription)."""
        if self._notices_stream is not None:
            print("Cancelling notice stream...")
            self._notices_stream.cancel()

    def stop_topic_listeners(self):
        """Gracefully stop the listener thread and cancel any open stream."""
        self._stop_event.set()
        self.cancel_notice_stream()
        if self._listener_thread and self._listener_thread.is_alive():
            self._listener_thread.join(timeout=3)
        print("Topic listener stopped.")

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _ensure_queue(self, topic: str):
        """Create the queue and event for *topic* if they do not exist yet."""
        with self._queues_lock:
            if topic not in self._queues:
                self._queues[topic] = queue.LifoQueue()
                self._topic_events[topic] = threading.Event()

    def _ensure_listener_running(self):
        """Start the listener thread, recreating it first if it has already died."""
        if not self._listener_thread.is_alive():
            if self._listener_thread.ident is not None:
                print("Listener thread has died — recreating...")
                self._listener_thread = threading.Thread(
                    target=self._listen_to_topics, daemon=True)
            self._listener_thread.start()
            print("Topic listener thread started.")

    def _listen_to_topics(self):
        """Background thread: maintain a streaming subscription and enqueue notices.

        Reconnects automatically on any gRPC error using exponential back-off.
        A CANCELLED status (caused by an intentional ``cancel_notice_stream``
        call) skips the back-off delay so resubscription is immediate.
        """
        backoff = _INITIAL_BACKOFF

        while not self._stop_event.is_set():
            if not self.topics:
                time.sleep(0.2)
                continue

            topic_enums = [data[t] for t in self.topics if t in data]
            req = subscriptionAPI_msg.SubscriptionRequest(topics=topic_enums)

            try:
                channel = GrpcChannelManager.get_channel(self.server_address)
                stub    = subscriptionAPI.SubscriptionStub(channel)
                self._notices_stream = stub.Subscribe(req)
                backoff = _INITIAL_BACKOFF  # reset on successful (re)connection
                print(f"[listener] Subscribed to topics: {self.topics}")

                for notice in self._notices_stream:
                    if self._stop_event.is_set():
                        return
                    try:
                        n_dict = MessageToDict(
                            notice,
                            preserving_proto_field_name=True,
                            always_print_fields_with_no_presence=True,
                        )
                    except Exception as decode_err:
                        # A single malformed message body — skip it and keep the
                        # stream alive rather than killing the whole subscription.
                        print(f"[listener] Skipping undecodable notice: {decode_err}")
                        continue

                    topic = n_dict.get("topic")
                    if topic is None:
                        continue

                    with self._queues_lock:
                        if topic not in self._queues:
                            self._queues[topic] = queue.LifoQueue()
                            self._topic_events[topic] = threading.Event()
                        self._queues[topic].put(n_dict)
                        self._notice_counts[topic] = (
                            self._notice_counts.get(topic, 0) + 1
                        )
                        # Signal *only* the waiter for this specific topic.
                        self._topic_events[topic].set()

            except grpc.RpcError as exc:
                if self._stop_event.is_set():
                    return
                code = exc.code() if callable(getattr(exc, "code", None)) else None

                # Intentional cancellation (e.g. resubscription after new topic added).
                if code == grpc.StatusCode.CANCELLED:
                    print("[listener] Stream cancelled — resubscribing immediately.")
                    continue

                # Transient wire-level deserialization failure: a single corrupt
                # packet caused the gRPC layer to raise INTERNAL before we even
                # received the bytes.  Reopen the stream immediately — no backoff.
                if code == grpc.StatusCode.INTERNAL and \
                        "deserializ" in (exc.details() or "").lower():
                    print("[listener] Deserialization error — resubscribing immediately.")
                    continue

                if code == grpc.StatusCode.UNAVAILABLE:
                    # Server temporarily unreachable (common in pipeline when device
                    # is restarting).  Keep the thread alive and retry with backoff
                    # instead of raising, which would kill the listener permanently.
                    print(f"[listener] gRPC server unavailable at {self.server_address} — "
                          f"retrying in {backoff}s...")
                    time.sleep(backoff)
                    backoff = min(backoff * 2, _MAX_BACKOFF)
                    continue
                print(f"[listener] gRPC error ({code}): {exc.details()} — "
                      f"retrying in {backoff}s...")
                time.sleep(backoff)
                backoff = min(backoff * 2, _MAX_BACKOFF)
