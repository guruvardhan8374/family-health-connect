import os
import django
import sys
from pathlib import Path

# Add the parent directory to sys.path to find 'familyconnect'
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.append(str(BASE_DIR))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import socketio

# Setup Django to allow ORM access in FastAPI
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'familyconnect.settings')
django.setup()

from api import health, ai

# Create FastAPI app
app = FastAPI(title="FamilyConnect API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="/api/v1")
app.include_router(ai.router, prefix="/api/v1")

# Create Socket.IO server for Real-time Tracking and Chat
sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')
socket_app = socketio.ASGIApp(sio, other_asgi_app=app)

# In-memory store for online users
online_users = {}

@sio.on('connect')
async def connect(sid, environ):
    print(f"Client connected: {sid}")

@sio.on('user_online')
async def handle_user_online(sid, data):
    user_id = data.get('user_id')
    if user_id:
        online_users[sid] = user_id
        await sio.emit('user_status_change', {'user_id': user_id, 'status': 'online'})
        print(f"User {user_id} is online")

@sio.on('disconnect')
async def disconnect(sid):
    user_id = online_users.pop(sid, None)
    if user_id:
        await sio.emit('user_status_change', {'user_id': user_id, 'status': 'offline'})
        print(f"User {user_id} is offline")
    print(f"Client disconnected: {sid}")

@sio.on('location_update')
async def handle_location_update(sid, data):
    # Broadcast location to family members (simplified)
    await sio.emit('family_location', data, skip_sid=sid)

@sio.on('chat_message')
async def handle_chat_message(sid, data):
    await sio.emit('new_message', data, skip_sid=sid)

@sio.on('typing_status')
async def handle_typing_status(sid, data):
    # data: { conversation_id, user_id, is_typing }
    await sio.emit('user_typing', data, skip_sid=sid)

@sio.on('message_status_update')
async def handle_status_update(sid, data):
    # data: { message_id, status, conversation_id }
    await sio.emit('status_updated', data, skip_sid=sid)

# --- WebRTC Signaling for Calls ---

@sio.on('call-user')
async def handle_call_user(sid, data):
    # data: { to_user_id, from_user_name, call_type, offer, conversation_id }
    # Find sid of the recipient
    to_sid = next((s for s, u in online_users.items() if str(u) == str(data.get('to_user_id'))), None)
    if to_sid:
        await sio.emit('incoming-call', {
            'from_sid': sid,
            'from_user_name': data.get('from_user_name'),
            'call_type': data.get('call_type'),
            'offer': data.get('offer'),
            'conversation_id': data.get('conversation_id')
        }, to=to_sid)
        print(f"Call request from {sid} to {to_sid}")

@sio.on('answer-call')
async def handle_answer_call(sid, data):
    # data: { to_sid, answer }
    await sio.emit('call-accepted', {
        'from_sid': sid,
        'answer': data.get('answer')
    }, to=data.get('to_sid'))
    print(f"Call accepted by {sid} for {data.get('to_sid')}")

@sio.on('reject-call')
async def handle_reject_call(sid, data):
    # data: { to_sid }
    await sio.emit('call-rejected', {'from_sid': sid}, to=data.get('to_sid'))
    print(f"Call rejected by {sid}")

@sio.on('webrtc-signal')
async def handle_webrtc_signal(sid, data):
    # data: { to_sid, signal }
    await sio.emit('webrtc-signal', {
        'from_sid': sid,
        'signal': data.get('signal')
    }, to=data.get('to_sid'))

@sio.on('sos_trigger')
async def handle_sos_trigger(sid, data):
    # Broadcast SOS to all family members
    print(f"SOS Triggered by {data.get('user')}")
    await sio.emit('sos_alert', data)

@app.get("/")
def read_root():
    return {"message": "Welcome to the FamilyConnect FastAPI & Socket.IO Server!"}

# Uvicorn should run `fastapi_app.main:socket_app` instead of `app`
