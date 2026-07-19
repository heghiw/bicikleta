"""WebSocket GPS tracking for active rentals and delivery segments.

Connect: ws://<host>/api/location/ws/{reference_type}/{reference_id}?token=<jwt>
reference_type: "rental" or "delivery"

Client sends:  {"lat": 48.123, "lon": 16.456}
Server replies: {"status": "ok", "lat": ..., "lon": ...}
"""
import json
import logging
from typing import Dict, List

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.orm import Session

from database import SessionLocal
from auth import SECRET_KEY, ALGORITHM
from jose import JWTError, jwt
import models

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/location", tags=["location"])

_connections: Dict[str, List[WebSocket]] = {}


def _authenticate(token: str) -> int:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            raise ValueError("Missing sub")
        return int(user_id)
    except JWTError as exc:
        raise ValueError("Invalid token") from exc


@router.websocket("/ws/{reference_type}/{reference_id}")
async def gps_ws(
    websocket: WebSocket,
    reference_type: str,
    reference_id: int,
    token: str = Query(...),
):
    if reference_type not in ("rental", "delivery"):
        await websocket.close(code=4003)
        return

    try:
        user_id = _authenticate(token)
    except ValueError:
        await websocket.close(code=4001)
        return

    db: Session = SessionLocal()
    try:
        # Validate that the reference exists and belongs to this user
        if reference_type == "rental":
            ref = db.query(models.Rental).filter(
                models.Rental.id == reference_id,
                models.Rental.renter_id == user_id,
                models.Rental.status == models.RentalStatus.active,
            ).first()
        else:
            ref = db.query(models.DeliverySegment).filter(
                models.DeliverySegment.id == reference_id,
                models.DeliverySegment.user_id == user_id,
                models.DeliverySegment.status == models.SegmentStatus.active,
            ).first()

        if not ref:
            await websocket.close(code=4004)
            return

        await websocket.accept()
        key = f"{reference_type}:{reference_id}"
        _connections.setdefault(key, []).append(websocket)
        logger.info("GPS WS connected user=%s %s", user_id, key)

        try:
            while True:
                raw = await websocket.receive_text()
                try:
                    data = json.loads(raw)
                    lat, lon = float(data["lat"]), float(data["lon"])
                except (KeyError, ValueError, TypeError):
                    await websocket.send_json({"error": "Expected {lat, lon}"})
                    continue

                log = models.GPSLog(
                    user_id=user_id,
                    reference_id=reference_id,
                    reference_type=reference_type,
                    lat=lat,
                    lon=lon,
                )
                db.add(log)
                db.commit()

                ack = {"status": "ok", "lat": lat, "lon": lon}
                dead = []
                for ws in _connections.get(key, []):
                    try:
                        await ws.send_json(ack)
                    except Exception:
                        dead.append(ws)
                for ws in dead:
                    _connections[key].remove(ws)

        except WebSocketDisconnect:
            logger.info("GPS WS disconnected user=%s %s", user_id, key)
        finally:
            conns = _connections.get(key, [])
            if websocket in conns:
                conns.remove(websocket)
    finally:
        db.close()
