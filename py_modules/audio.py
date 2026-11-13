import asyncio, re, sqlite3, os, json, io, time, sys
from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as MediaManager
from winsdk.windows.storage.streams import DataReader
from PIL import Image

def get_database_path(app_name="VerseForge"):
	base_dir = None
	if getattr(sys, "frozen", False):
		if hasattr(sys, "_MEIPASS"):
			if os.name == "nt":
				base_dir = os.path.join(os.getenv("LOCALAPPDATA") or os.path.expanduser("~"), app_name)
		else:
			base_dir = os.path.dirname(sys.executable)
	else:
		base_dir = os.path.dirname(os.path.abspath(__file__))
	os.makedirs(base_dir, exist_ok=True)
	return os.path.join(base_dir, "songs.db")

database_path = get_database_path()

conn = sqlite3.connect(database_path)
cursor = conn.cursor()
cursor.execute("""
	CREATE TABLE IF NOT EXISTS songs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		song TEXT,
		lyrics TEXT,
		artist TEXT
	)
""")
conn.commit()
conn.close()



lyrics = [0.0, ""]

win_api_cache = {}
win_api_cache_time = 0
win_api_cache_duration = 5.0  # sekundes

# --- Funkcijas lyrics iegūšanai ---
def clean_title(title):
    title = re.sub(r'[\(\[\{].*?[\)\]\}]', '', title)
    title = re.sub(r'[^a-zA-Z0-9\s]', '', title)
    title = re.sub(r'\s+', ' ', title)
    return title.strip()

def get_lyrics(song, artist):
    conn = sqlite3.connect(database_path)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT lyrics, artist FROM songs WHERE song = ? AND artist = ?",
        (song, artist)
    )
    result = cursor.fetchone()
    conn.close()
    if result:
        lyrics_json, db_artist = result
        if not db_artist or db_artist != artist:
            return [["", 0]]
        try:
            lyrics_array = json.loads(lyrics_json)
            return lyrics_array
        except:
            return [["", 0]]
    return [["", 0]]


# --- AudioModule ---
class AudioModule:
	def __init__(self, cover_folder):
		self.folder_path = cover_folder
		self.last_song_name = ""
		self.running = False
		self.task = None

	def clean_title(self, title):
		title = re.sub(r'[\(\[\{].*?[\)\]\}]', '', title)
		title = re.sub(r'[^a-zA-Z0-9\s]', '', title)
		title = re.sub(r'\s+', ' ', title)
		return title.strip()

	async def get_now_playing(self):
		global lyrics, win_api_cache, win_api_cache_time, win_api_cache_duration

		if win_api_cache_time < win_api_cache_duration:
			win_api_cache_time += 1
			return win_api_cache
		win_api_cache_time = 0

		manager = await MediaManager.request_async()
		session = manager.get_current_session()
		if not session:
			print("No active media session")
			win_api_cache = {
				"artist": "",
				"song_name": "",
				"lyrics": [["", 0]],
				"progress": 0,
				"length": 0,
				"paused": True,
				"cover_path": None
			}
			return win_api_cache

		media_props = await session.try_get_media_properties_async()
		song_name = media_props.title
		artist_name = media_props.artist
		paused = session.get_playback_info().playback_status != 4 # type: ignore
		timeline = session.get_timeline_properties()
		progress_seconds = timeline.position.total_seconds() # type: ignore
		try:
			duration_seconds = timeline.end_time.total_seconds() # type: ignore
		except AttributeError:
			duration_seconds = 0

		# Lyrics
		if self.last_song_name != song_name:
			self.last_song_name = song_name
			lyrics = get_lyrics(self.clean_title(song_name), artist_name)

		# Cover attēls
		cover_path = ""
		try:
			if media_props.thumbnail:
				# timeout, lai nepiesprāgtu
				stream = await asyncio.wait_for(media_props.thumbnail.open_read_async(), timeout=0.5)
				reader = DataReader(stream) # type: ignore
				await asyncio.wait_for(reader.load_async(stream.size), timeout=0.5)
				bytes_data = reader.read_buffer(int(stream.size))
				image = Image.open(io.BytesIO(bytes_data)) # type: ignore
				if image.mode == 'RGBA':
					image = image.convert('RGB')
				cover_path = os.path.join(self.folder_path, "cover.jpg")
				image.save(cover_path, "JPEG")
		except asyncio.TimeoutError:
			print("Thumbnail read timeout, skipping cover")
		except Exception as e:
			print("Thumbnail read error:", e)
		win_api_cache = {
			"artist": artist_name,
			"song_name": song_name,
			"lyrics": lyrics,
			"progress": progress_seconds,
			"progress_timestamp": time.monotonic(),
			"length": duration_seconds,
			"paused": paused,
			"cover_path": cover_path
		}
		return win_api_cache

	async def _stream_loop(self, callback, interval=1.0):
		while self.running:
			data = await self.get_now_playing()
			if data:
				try:
					await callback({
						"action": "song_update",
						"payload": data
					})
				except Exception as e:
					print("AudioModule stream error:", e)
					break
			await asyncio.sleep(interval)

	def start_stream(self, callback, interval=1.0):
		if not self.running:
			self.running = True
			self.task = asyncio.create_task(self._stream_loop(callback, interval))

	def stop_stream(self):
		self.running = False
		if self.task:
			self.task.cancel()
			self.task = None
