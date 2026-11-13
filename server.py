import websockets, asyncio, json, sys, os
from pydantic import BaseModel, Field
import time as t

from py_modules.audio import AudioModule
from py_modules.tray import TrayModule
from py_modules.visualizer_v1 import VisualizerModule

is_exe = getattr(sys, 'frozen', False)

# --- MODUĻI ---
base_dir = os.path.abspath(os.path.dirname(__file__))
if is_exe:
    base_dir = os.path.dirname(base_dir)
audio_module = AudioModule(os.path.join(base_dir, "py_assets"))
tray_module = TrayModule("VerseForge", [os.path.join(base_dir, "VerseForgeHub.exe")], os.path.join(base_dir, "py_assets/tray_picture.png"))
visualizer_module = VisualizerModule()

last_song_name_and_artist = ("","")

# --- DATU KLASES ---

class SongData(BaseModel):
    song_name: str = ""
    artist: str = ""
    progress: float = 0
    length: float = 0
    lyrics: list[list] = Field(default_factory=list)
    paused: bool = False
    path: str = ""

class SongFrequencies(BaseModel):
    frequencies: list[float] = Field(default_factory=list)
    volume: float = 0.0
    beat: list[float] = Field(default_factory=list)
    bpm: float = 0.0

# --- SERVERA STĀVOKĻI ---
current_song_data = SongData()
song_frequencies = SongFrequencies()

ws_server: websockets.Server

connected_client = None
visualizer_task = None
audio_task = None

start_time = t.time()
def time():
    return t.time() - start_time

is_exit_requested = False

# --- VISUALIZER TASK ---
async def push_visualizer_data(websocket):
    while visualizer_module.running:
        data = visualizer_module.poll()
        await websocket.send(json.dumps({"action":"song_frequencies","payload":data}))
        await asyncio.sleep(0.05)  # ~20Hz

# --- HANDLERI PIEPRASĪJUMIEM ---
async def handle_message(message, websocket):
    global current_song_data, song_frequencies, last_song_name_and_artist
    global visualizer_task, audio_task

    try:
        data = json.loads(message)
        action = data.get("action")
        payload = data.get("payload", {})

        if action == "start_visualizer":
            if visualizer_module.running:
                response = {"action": "error", "payload": {"message": "Visualizer already running"}}
                await websocket.send(json.dumps(response))
                return
            visualizer_module.start()
            visualizer_task = asyncio.create_task(push_visualizer_data(websocket))

            print("Visualizer Module started")
            response = {"action": "visualizer_started"}

        elif action == "stop_visualizer":
            visualizer_module.stop()
            if visualizer_task:
                visualizer_task.cancel()

            print("Visualizer Module stopped")
            response = {"action": "visualizer_stopped"}

        elif action == "start_audio":
            if not audio_module.running:
                async def send_callback(msg):
                    global last_song_name_and_artist
                    name_artist = (msg["payload"]["song_name"], msg["payload"]["artist"])
                    if name_artist != last_song_name_and_artist:
                        last_song_name_and_artist = name_artist
                        visualizer_module.detector.reset()
                    try:
                        await websocket.send(json.dumps(msg))
                    except Exception as e:
                        print("Error sending audio data:", e)

                audio_module.start_stream(send_callback, interval=1.0)
                print("Audio Module started streaming")
            response = {"action": "audio_started"}


        elif action == "stop_audio":
            if audio_module.running:
                audio_module.stop_stream()
                print("Audio Module stopped streaming")
            response = {"action": "audio_stopped"}
        else:
            response = {"action": "error", "payload": {"message": "Unknown action"}}
        await websocket.send(json.dumps(response))

    except Exception as e:
        await websocket.send(json.dumps({"action": "error", "payload": {"message": str(e)}}))


# tray callback
def on_tray_exit():
    global is_exit_requested
    is_exit_requested = True

# monitor loop
async def monitor_exit():
    global is_exit_requested, connected_client, ws_server
    while True:
        await asyncio.sleep(0.5)
        if is_exit_requested:
            print("Exit requested...")
            if connected_client:
                try:
                    await connected_client.send(json.dumps({
                        "action": "server_exit",
                        "payload": {"message": "Server shutting down"}
                    }))
                    await asyncio.sleep(0.1)
                    await connected_client.close()
                except:
                    pass

            # aptur moduļus
            if visualizer_module.running:
                visualizer_module.stop()
            if audio_module.running:
                audio_module.stop_stream()

            # aizver ws serveri
            if ws_server is not None:
                ws_server.close()
                await ws_server.wait_closed()

            break

tray_module.set_exit_callback(on_tray_exit)
tray_module.run_tray()




# --- WS SERVERIS ---
async def ws_handler(websocket):
    global connected_client, ws_server
    if connected_client is not None:
        await websocket.send(json.dumps({"action": "quit", "payload": {"message": "Another client is already connected"}}))
        await websocket.close()
        return

    connected_client = websocket
    print("Client connected")
    try:
        await websocket.send(json.dumps({"action": "connected", "payload": {"message": "Connected to server"}}))
    except Exception as e:
        print("Error sending status data:", e)
    try:
        async for message in websocket:
            await handle_message(message, websocket)
    except websockets.ConnectionClosed:
        print("Client disconnected")

        if visualizer_module.running: visualizer_module.stop()
        if visualizer_task: visualizer_task.cancel()
        if audio_module.running: audio_module.stop_stream()
        print("Shutting down server...")
        if ws_server is not None:
            ws_server.close()
    finally:
        connected_client = None

# --- SERVERA STARTS ---
async def main():
    global ws_server
    ws_server = await websockets.serve(ws_handler, "127.0.0.1", 1234)
    print("WebSocket server listening on ws://127.0.0.1:1234")

    asyncio.create_task(monitor_exit())

    await ws_server.wait_closed()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Server stopped")
        sys.exit(0)
