# axon_core/main.py
import asyncio
import logging
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from google import genai
from dotenv import load_dotenv
from persona import AXON_SYSTEM_INSTRUCTION

load_dotenv()
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("AxonCore")

app = FastAPI()
client = genai.Client(http_options={'api_version': 'v1alpha'})

GEMINI_CONFIG = {
    "response_modalities": ["AUDIO"],
    "system_instruction": AXON_SYSTEM_INSTRUCTION,
}

@app.websocket("/axon-link")
async def axon_link(websocket: WebSocket):
    await websocket.accept()
    logger.info("📡 Satellite Link Established.")

    try:
        # Connect to Gemini Live
        async with client.aio.live.connect(model="gemini-2.0-flash-exp", config=GEMINI_CONFIG) as session:
            logger.info("🧠 Brain Active. Connected to Gemini.")

            async def receive_from_satellite():
                try:
                    while True:
                        # Receive data (Audio/Video chunks) from Flutter/Python Client
                        data = await websocket.receive_bytes()
                        if data:
                            await session.send(input=data, end_of_turn=False)
                except WebSocketDisconnect:
                    logger.warning("Satellite disconnected normally.")
                except Exception as e:
                    logger.error(f"Upstream Error: {e}")

            async def send_to_satellite():
                try:
                    async for response in session.receive():
                        if response.server_content and response.server_content.model_turn:
                            for part in response.server_content.model_turn.parts:
                                if part.inline_data:
                                    # Send Gemini's audio back to client
                                    await websocket.send_bytes(part.inline_data.data)
                except Exception as e:
                    logger.error(f"Downstream/Quota Error: {e}")
                    # If we hit a quota limit, Gemini closes the connection here
                    await websocket.close(code=1008, reason="Quota Exceeded or API Error")

            await asyncio.gather(receive_from_satellite(), send_to_satellite())

    except Exception as e:
        logger.critical(f"❌ NEURAL LINK SEVERED: {e}")
        # This usually catches the '429 Resource Exhausted' error
    finally:
        try:
            await websocket.close()
        except:
            pass
        logger.info("🔌 Link Closed.")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)