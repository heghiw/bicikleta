"""WebSocket endpoint for real-time location tracking during active trips.

Connect to: ws://<host>/location/ws/{trip_id}?token=<jwt>

The client sends JSON messages: {"lat": 48.123, "lon": 16.456}
The server acknowledges each update and broadcasts to any additional listeners
on the same trip (e.g. admin monitoring).
"""
import json
import logging
from typing import Dict, List

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, status
from sqlalchemy.orm import Session

from database import SessionLocal
from auth import SECRET_KEY, ALGORITHM
from jose import JWTError, jwt
import models

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/location", tags=["location"])

# In-memory connection registry: trip_id → list of active WebSocket connections
_connections: Dict[int, List[WebSocket]] = {}


def _authenticate_ws(token: str) -> int:
    """Validate JWT and return user_id, or raise ValueError."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise ValueError("Missing sub claim")
        return int(user_id)
    except JWTError as exc:
        raise ValueError("Invalid token") from exc


@router.websocket("/ws/{trip_id}")
async def location_ws(
    websocket: WebSocket,
    trip_id: int,
    token: str = Query(..., description="JWT access token"),
):
    """Real-time location updates for an active trip.

    - Authenticates via `?token=<jwt>` query parameter.
    - Validates that the authenticated user owns the trip and it is active.
    - Stores each update in `location_updates` table.
    - Broadcasts the position to all listeners on this trip.
    """
    # Authenticate
    try:
        user_id = _authenticate_ws(token)
    except ValueError:
        await websocket.close(code=4001)
        return

    db: Session = SessionLocal()
    try:
        trip = (
            db.query(models.Trip)
            .filter(models.Trip.id == trip_id, models.Trip.user_id == user_id)
            .first()
        )
        if not trip or trip.status != models.TripStatus.active:
            await websocket.close(code=4004)
            return

        await websocket.accept()
        _connections.setdefault(trip_id, []).append(websocket)
        logger.info("WS connected: user=%s trip=%s", user_id, trip_id)

        try:
            while True:
                raw = await websocket.receive_text()
                try:
                    data = json.loads(raw)
                    lat = float(data["lat"])
                    lon = float(data["lon"])
                except (KeyError, ValueError, TypeError):
                    await websocket.send_json({"error": "Expected {\"lat\": float, \"lon\": float}"})
                    continue

                # Persist location update
                update = models.LocationUpdate(trip_id=trip_id, lat=lat, lon=lon)
                db.add(update)
                db.commit()

                ack = {"trip_id": trip_id, "lat": lat, "lon": lon, "status": "recorded"}
                # Broadcast to all connections on this trip
                dead = []
                for ws in _connections.get(trip_id, []):
                    try:
                        await ws.send_json(ack)
                    except Exception:
                        dead.append(ws)
                for ws in dead:
                    _connections[trip_id].remove(ws)

        except WebSocketDisconnect:
            logger.info("WS disconnected: user=%s trip=%s", user_id, trip_id)
        finally:
            conns = _connections.get(trip_id, [])
            if websocket in conns:
                conns.remove(websocket)
    finally:
        db.close()
