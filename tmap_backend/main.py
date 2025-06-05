# 📁 main.py
from fastapi import FastAPI, HTTPException, Query
import requests
import os
from dotenv import load_dotenv
from pydantic import BaseModel
import time

# .env 로드
load_dotenv()
TMAP_API_KEY = os.getenv("TMAP_API_KEY")

app = FastAPI()

# 🚶 도보 경로 요청
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

# 🚌 대중교통 경로 요청
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

# 📍 실시간 위치 좌표 수신
class Location(BaseModel):
    user_id: str
    latitude: float
    longitude: float

@app.post("/update_location")
async def update_location(location: Location):
    print(f"[{time.strftime('%H:%M:%S')}] 위치 수신 - ID: {location.user_id}, "
          f"위도: {location.latitude}, 경도: {location.longitude}")
    return {"message": "위치 수신 완료"}

# 🌐 로컬 테스트용
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=10000)
