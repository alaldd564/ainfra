# 📁 main.py
from fastapi import FastAPI, HTTPException, Query
import requests
import os
from dotenv import load_dotenv

# .env 로드
load_dotenv()
TMAP_API_KEY = os.getenv("TMAP_API_KEY")

app = FastAPI()

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
