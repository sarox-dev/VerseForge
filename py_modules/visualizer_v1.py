# visualizer_module_v1.py
import soundcard as sc
import numpy as np
from scipy.fft import rfft
import threading, time, math, collections, traceback

samplerate = 44100
blocksize = 1024
n_bins = 100
k_sigma = 1.6
min_beat_interval = 0.15
flux_win = 1.2

current_volume = 1.0
vol_lock = threading.Lock()
_global_beat_timestamps = [0.0] * 5

# soundcard objects (do not open recorder in __init__)
speaker = sc.default_speaker()
_microphone = sc.get_microphone(speaker.name, include_loopback=True)

def volume_worker():
    """Daemon thread, kas atjauno sistēmas skaļumu"""
    global current_volume
    try:
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
        from ctypes import cast, POINTER
        from comtypes import CLSCTX_ALL, CoInitialize
        CoInitialize()
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        vol = cast(interface, POINTER(IAudioEndpointVolume))
        while True:
            try:
                level = vol.GetMasterVolumeLevelScalar() # type: ignore
                with vol_lock:
                    current_volume = float(level)
                time.sleep(0.2)
            except Exception:
                with vol_lock:
                    current_volume = 1.0
                time.sleep(0.5)
    except Exception:
        # pycaw nav pieejams — fallback
        while True:
            with vol_lock:
                current_volume = 1.0
            time.sleep(0.5)

import numpy as np
import collections
from scipy.fftpack import rfft

class MultiBandBeatDetector:
    def __init__(self, samplerate, blocksize, k_sigma=2.0, min_interval=0.2, flux_win=1.5):
        self.fs = samplerate
        self.hop = blocksize
        self.k = k_sigma
        self.min_interval = min_interval
        self._ema_bpm = None
        self.last_beat_t = {band: -1e9 for band in range(5)}
        self.flux_hist = {
            band: collections.deque(
                maxlen=max(8, int(flux_win * samplerate / blocksize))
            )
            for band in range(5)
        }
        self.interval_hist = collections.deque(maxlen=128)  # inter-onset intervals
        self.bpm_hist = collections.deque(maxlen=64)
        self.win = np.hanning(blocksize)
        self.prev_mag = None
        self.band_limits = [
            (20, 120),    # bass
            (40, 150),     # kick
            (150, 800),   # snare
            (800, 4000),  # hi-hats
            (4000, 18000)  # brightness
        ]

        self.beats_per_bar = 4
        self.downbeat_phase = 0.0
        self.last_downbeat_t = -1e9
    
    def detect_downbeat(self, t_now):
        bpm = self.smoothed_bpm()
        if bpm <= 0:
            return False
        
        seconds_per_beat = 60.0 / bpm
        seconds_per_bar = seconds_per_beat * self.beats_per_bar

        # Ja pirmoreiz vai ilgi nav bijis downbeat, inicializē
        if t_now - self.last_downbeat_t > seconds_per_bar * 2:
            self.last_downbeat_t = t_now
            self.downbeat_phase = 0.0
            return True  # pirmais downbeat uzreiz

        # Izrēķina cik beati kopš pēdējā downbeat
        beats_since = (t_now - self.last_downbeat_t) / seconds_per_beat
        if beats_since >= self.beats_per_bar:
            self.last_downbeat_t = t_now
            self.downbeat_phase = 0.0
            return True
        else:
            self.downbeat_phase = beats_since % self.beats_per_bar
            return False
    
    def reset(self):
        """Reset all cached BPM/interval info for a new song"""
        self.bpm_hist.clear()
        self.interval_hist.clear()
        self._ema_bpm = None
        self.prev_mag = None
        for band in self.last_beat_t:
            self.last_beat_t[band] = -1e9
        for band in self.flux_hist:
            self.flux_hist[band].clear()

    def smoothed_bpm(self):
        if not self.bpm_hist:
            return 0.0
        median_val = np.median(self.bpm_hist)
        if self._ema_bpm is None:
            self._ema_bpm = median_val
        alpha = 0.2  # smoothing factor
        self._ema_bpm = (1 - alpha) * self._ema_bpm + alpha * median_val
        return self._ema_bpm

    def process(self, x, t_now, freqs):
        xw = x * self.win
        spec = np.abs(rfft(xw, n=self.hop))
        if self.prev_mag is None:
            self.prev_mag = spec
            for band in range(5):
                self.flux_hist[band].append(0.0)
            return [False]*5, 0.0, False

        diff = spec - self.prev_mag
        self.prev_mag = spec
        beats = []
        detected_bpms = []

        for i, (f0, f1) in enumerate(self.band_limits):
            idx = np.where((freqs >= f0) & (freqs < f1))[0]
            flux = float(np.sum(np.maximum(diff[idx], 0.0))) if idx.size else 0.0
            self.flux_hist[i].append(flux)

            arr = np.fromiter(self.flux_hist[i], dtype=float)
            mu, sigma = (arr.mean(), arr.std()) if arr.size else (0.0, 1e-6)
            thr = mu + self.k * max(sigma, 1e-6)

            is_peak = arr.size >= 3 and arr[-2] > arr[-3] and arr[-2] > arr[-1] and arr[-2] > thr
            beat = False
            if is_peak:
                interval = t_now - self.last_beat_t[i]
                if interval >= self.min_interval:
                    self.last_beat_t[i] = t_now
                    beat = True
                    # only consider reasonable tempo intervals
                    if 0.25 <= interval <= 1.5:
                        bpm_val = 60.0 / interval
                        detected_bpms.append(bpm_val)
                        self.interval_hist.append(interval)
            beats.append(beat)

        # --- BPM estimation ---
        bpm = 0.0
        if detected_bpms:
            median_bpm = np.median(detected_bpms)
            self.bpm_hist.append(median_bpm)

        if self.interval_hist:
            intervals = np.array(self.interval_hist)
            bpms = 60.0 / intervals
            hist, edges = np.histogram(bpms, bins=np.arange(40, 241, 2))
            peak_bin = np.argmax(hist)
            bpm = 0.5 * (edges[peak_bin] + edges[peak_bin + 1])

        # sanity check with smoothed bpm
        if bpm > 0:
            candidates = [bpm, bpm * 2, bpm / 2]
            ema = self.smoothed_bpm() or bpm
            bpm = min(candidates, key=lambda x: abs(x - ema))
        
        downbeat = False
        if any(beats):
            downbeat = self.detect_downbeat(t_now)

        # filter extreme ranges
        if bpm < 60 and bpm > 0:
            bpm *= 2
        elif bpm > 200:
            bpm /= 2

        if bpm > 0:
            self.bpm_hist.append(bpm)

        return beats, self.smoothed_bpm(), downbeat

def scaled_bins(blocksize=2048, samplerate=44100, n_bins=100):
    f_min, f_max, log_mix = 20, 18000, 0.77
    freqs = np.fft.rfftfreq(blocksize, 1 / samplerate)
    linear = np.linspace(f_min, f_max, n_bins + 1)
    log = np.logspace(np.log10(f_min), np.log10(f_max), n_bins + 1)
    edges = linear * (1 - log_mix) + log * log_mix
    return freqs, edges

# start background volume thread once
threading.Thread(target=volume_worker, daemon=True).start()

class VisualizerModule:
    """Visualizer Module to import into server"""
    def __init__(self):
        self.detector = MultiBandBeatDetector(samplerate, blocksize, k_sigma, min_beat_interval, flux_win)
        self.freqs, self.edges = scaled_bins(blocksize, samplerate, n_bins)
        self._recorder_ctx = None   # context manager for recorder
        self._recorder_obj = None   # the recorder object (context manager)
        self._lock = threading.RLock()
        self.running = False
        self._local_beat = [0.0] * 5

    def start(self):
        """Open recorder and set running True. Safe to call multiple times."""
        with self._lock:
            if self.running:
                return
            try:
                self._recorder_obj = _microphone.recorder(samplerate=samplerate, channels=1)
                # enter context to open device
                self._recorder_ctx = self._recorder_obj.__enter__()
                self.running = True
            except Exception:
                # cleanup on failure
                self._recorder_ctx = None
                self._recorder_obj = None
                self.running = False
                traceback.print_exc()

    def stop(self):
        """Stop recording and close device."""
        with self._lock:
            if not self.running:
                return
            try:
                if self._recorder_obj is not None:
                    # exit context to close device
                    self._recorder_obj.__exit__(None, None, None)
            except Exception:
                traceback.print_exc()
            finally:
                self._recorder_ctx = None
                self._recorder_obj = None
                self.running = False

    def poll(self):
        """Return latest frequencies dict. Non-blocking and safe if not running."""
        with self._lock:
            if not self.running or self._recorder_ctx is None:
                # return zeros if not running
                return {"bins": [0.0]*n_bins, "volume": 0.0, "beat": [0.0]*5, "bpm": 0.0, "downbeat": False}

            try:
                # read one block
                t_now = time.time()
                buf = self._recorder_ctx.record(numframes=blocksize)[:, 0]
                beats, bpm, downbeat = self.detector.process(buf, t_now, self.freqs)

                for i, b in enumerate(beats):
                    if b:
                        _global_beat_timestamps[i] = t_now
                        self._local_beat[i] = t_now

                spec = np.abs(rfft(buf))[:blocksize // 2 + 1] # type: ignore
                binned = []
                for i in range(n_bins):
                    f0, f1 = self.edges[i], self.edges[i + 1]
                    idx = np.where((self.freqs >= f0) & (self.freqs < f1))[0]
                    binned.append(float(spec[idx].max()) if idx.size else 0.0)

                x = np.linspace(0, math.pi / 2, n_bins)
                weights = 0.4 + 0.6 * np.sin(x)
                binned = np.log1p(np.array(binned) * weights).tolist()

                with vol_lock:
                    vol = current_volume * 100.0

                return {
                    "bins": binned,
                    "volume": vol,
                    "beat": _global_beat_timestamps.copy(),
                    "bpm": float(bpm),
                    "downbeat": bool(downbeat)
                }
            except Exception:
                traceback.print_exc()
                # on any error return safe zeros (and optionally stop)
                return {"bins": [0.0]*n_bins, "volume": 0.0, "beat": [0.0]*5, "bpm": 0.0, "downbeat": False}
