# 📁 main.py
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
import requests
from dotenv import load_dotenv
import os

load_dotenv()  # .env 파일에서 API 키 불러오기

app = FastAPI()

# CORS 설정 (Flutter 등 외부에서 호출 가능하도록)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 운영 시에는 "*" 대신 특정 도메인으로 제한하는 것이 안전해
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/transit")
def get_transit_route(
    startX: float = Query(...),
    startY: float = Query(...),
    endX: float = Query(...),
    endY: float = Query(...),
):
    url = (
        "https://apis.openapi.sk.com/transit/routes?version=1&format=json"
        f"&startX={startX}&startY={startY}&endX={endX}&endY={endY}"
    )

    headers = {
        "accept": "application/json",
        "appKey": os.getenv("TMAP_API_KEY"),  # .env에서 불러온 키 사용
    }

    response = requests.get(url, headers=headers)
    return {
        "status": response.status_code,
        "body": response.json()
    }
