from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import requests
import time
import firebase_admin
from firebase_admin import credentials, firestore

# TMAP API 키
TMAP_API_KEY = "gvtcaFKZy01ZmlWn54hMQazLlazJ0a051IsKZCYc"

# Firebase Admin SDK 초기화
cred = credentials.Certificate("t111-5d2a9-firebase-adminsdk-fbsvc-1f254349b3.json")  # 서비스 계정 JSON 경로
firebase_admin.initialize_app(cred)
db = firestore.client()

app = FastAPI()

# 메모리 저장용 위치 데이터
user_locations = {}

# 1. 서버 상태 확인
@app.get("/ping")
def ping():
    return {"status": "ok", "message": "TMAP 백엔드가 살아 있습니다."}

# 2. 위치 데이터 모델
class Location(BaseModel):
    user_id: str
    latitude: float
    longitude: float

# 위치 수신 및 저장
@app.post("/update_location")
async def update_location(location: Location):
    if not (-90 <= location.latitude <= 90 and -180 <= location.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates")

    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] 위치 수신 - ID: {location.user_id}, 위도: {location.latitude}, 경도: {location.longitude}")

    # 메모리 저장
    user_locations[location.user_id] = {
        "latitude": location.latitude,
        "longitude": location.longitude,
        "timestamp": timestamp
    }

    # Firestore 저장
    try:
        doc_ref = db.collection('locations').document(location.user_id)
        doc_ref.set({
            'latitude': location.latitude,
            'longitude': location.longitude,
            'timestamp': timestamp
        }, merge=True)
    except Exception as e:
        print(f"Firestore 저장 오류: {e}")
        raise HTTPException(status_code=500, detail="Firestore 저장 실패")

    return {"message": "위치 수신 및 저장 완료", "timestamp": timestamp}

# 보호자용: 위치 조회
@app.get("/get_location")
def get_location(user_id: str = Query(..., description="시각장애인 고유번호")):
    if user_id not in user_locations:
        raise HTTPException(status_code=404, detail="해당 고유번호의 위치 정보가 없습니다.")

    return {
        "user_id": user_id,
        "location": user_locations[user_id]
    }

# 3. 도보 경로 탐색
@app.get("/route/walking")
def walking_route(
    startX: float = Query(...),
    startY: float = Query(...),
    endX: float = Query(...),
    endY: float = Query(...)
):
    url = 'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json'
    headers = {
        "appKey": TMAP_API_KEY,
        "Content-Type": "application/json"
    }
    body = {
        "startX": str(startX),
        "startY": str(startY),
        "endX": str(endX),
        "endY": str(endY),
        "reqCoordType": "WGS84GEO",
        "resCoordType": "WGS84GEO",
        "startName": "출발지",
        "endName": "도착지"
    }
    res = requests.post(url, headers=headers, json=body)
    if res.status_code != 200:
        raise HTTPException(status_code=res.status_code, detail=res.text)
    return res.json()

# 4. 대중교통 경로 탐색
@app.get("/route/transit")
def transit_route(
    startX: float = Query(...),
    startY: float = Query(...),
    endX: float = Query(...),
    endY: float = Query(...)
):
    url = (
        f"https://apis.openapi.sk.com/transit/routes?version=1&format=json"
        f"&startX={startX}&startY={startY}&endX={endX}&endY={endY}"
    )
    headers = {
        "accept": "application/json",
        "appKey": TMAP_API_KEY
    }
    res = requests.get(url, headers=headers)
    if res.status_code != 200:
        raise HTTPException(status_code=res.status_code, detail=res.text)
    return res.json()
