from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import requests
import os
import time
from dotenv import load_dotenv

# .env 로드
load_dotenv()
TMAP_API_KEY = os.getenv("TMAP_API_KEY")

app = FastAPI()

# 📌 1. 서버 상태 확인용
@app.get("/ping")
def ping():
    return {"status": "ok", "message": "TMAP 백엔드가 살아 있습니다."}

# 📍 2. 실시간 위치 수신
class Location(BaseModel):
    user_id: str
    latitude: float
    longitude: float

@app.post("/update_location")
async def update_location(location: Location):
    if not (-90 <= location.latitude <= 90 and -180 <= location.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates")

    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] 위치 수신 - ID: {location.user_id}, "
          f"위도: {location.latitude}, 경도: {location.longitude}")
    return {"message": "위치 수신 완료", "timestamp": timestamp}

# 🚶 3. 도보 경로 요청
@app.get("/route/walking")
def walking_route(startX: float = Query(...), startY: float = Query(...), endX: float = Query(...), endY: float = Query(...)):
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

# 🚌 4. 대중교통 경로 요청
@app.get("/route/transit")
def transit_route(startX: float = Query(...), startY: float = Query(...), endX: float = Query(...), endY: float = Query(...)):
    url = f"https://apis.openapi.sk.com/transit/routes?version=1&format=json&startX={startX}&startY={startY}&endX={endX}&endY={endY}"
    headers = {
        "accept": "application/json",
        "appKey": TMAP_API_KEY
    }

    res = requests.get(url, headers=headers)
    if res.status_code != 200:
        raise HTTPException(status_code=res.status_code, detail=res.text)
    return res.json()

# 🌐 로컬 실행용
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=10000)
