# test_axon.py
import asyncio
import websockets
import pyaudio
import cv2
import logging

AXON_URI = "ws://localhost:8000/axon-link"
AUDIO_RATE = 16000
CHUNK_SIZE = 512
FORMAT = pyaudio.paInt16
CHANNELS = 1

# --- RATE LIMITER CONFIG ---
VIDEO_FRAME_SKIP = 30  # Only send 1 frame every 30 loops (approx 1 FPS)
# ---------------------------

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AxonTest")

async def axon_test_client():
    audio = pyaudio.PyAudio()
    mic_stream = audio.open(format=FORMAT, channels=CHANNELS, rate=AUDIO_RATE, input=True, frames_per_buffer=CHUNK_SIZE)
    speaker_stream = audio.open(format=FORMAT, channels=CHANNELS, rate=24000, output=True, frames_per_buffer=CHUNK_SIZE)
    cap = cv2.VideoCapture(0)

    try:
        async with websockets.connect(AXON_URI) as websocket:
            logger.info("✅ CONNECTED TO AXON CORE! (Throttled Mode)")
            print("\n" + "="*40 + "\n   SAY 'HELLO AXON' NOW!\n" + "="*40 + "\n")

            async def send_loop():
                loop_count = 0
                while True:
                    try:
                        # 1. ALWAYS send Audio (Low bandwidth)
                        audio_data = mic_stream.read(CHUNK_SIZE, exception_on_overflow=False)
                        await websocket.send(audio_data)

                        # 2. OCCASIONALLY send Video (High bandwidth)
                        ret, frame = cap.read()
                        if ret:
                            # Display locally so you know it's working
                            cv2.imshow('Axon Sight (Local)', frame)
                            if cv2.waitKey(1) & 0xFF == ord('q'):
                                break

                            # ONLY send to AI if we hit the interval
                           # if loop_count % VIDEO_FRAME_SKIP == 0:
                                # Encode frame to JPEG to reduce size
                            #    _, buffer = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 50])
                            #    await websocket.send(buffer.tobytes())
                            
                            loop_count += 1
                        
                        await asyncio.sleep(0.001) 
                    except Exception as e:
                        logger.error(f"Send Error: {e}")
                        break

            async def receive_loop():
                try:
                    async for message in websocket:
                        speaker_stream.write(message)
                except Exception as e:
                    logger.error(f"Receive Error: {e}")

            await asyncio.gather(send_loop(), receive_loop())

    except Exception as e:
        logger.error(f"Connection Failed: {e}")
    finally:
        mic_stream.stop_stream()
        mic_stream.close()
        speaker_stream.stop_stream()
        speaker_stream.close()
        audio.terminate()
        cap.release()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    asyncio.run(axon_test_client())