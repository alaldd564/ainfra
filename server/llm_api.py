from fastapi import FastAPI
from pydantic import BaseModel
import requests
import os

app = FastAPI()

PERPLEXITY_API_KEY = os.environ.get("PERPLEXITY_API_KEY")

if not PERPLEXITY_API_KEY:
    raise ValueError("PERPLEXITY_API_KEY 환경변수가 설정되지 않았습니다.")

class GuidanceRequest(BaseModel):
    step_desc: str
    current_pos: str = "알 수 없음"

@app.post("/generate-guidance")
def generate_guidance(req: GuidanceRequest):
    url = "https://api.perplexity.ai/chat/completions"
    headers = {
        "Authorization": f"Bearer {PERPLEXITY_API_KEY}",
        "Content-Type": "application/json"
    }

    system_prompt = """
당신은 시각장애인을 위한 친절하고 안전한 내비게이션 음성 안내 전문가입니다.
1. 모든 거리는 '미터' 단위로 명확히 알려주세요.
2. 방향 전환 시 주변 랜드마크를 언급하세요.
3. 장애물 정보를 포함하세요.
4. 배려 문구 포함, 간결한 안내.
5. 마지막에 '필요하면 다시 말씀해드릴 수 있습니다.'
"""

    user_prompt = f"현재 위치: {req.current_pos}, 다음 경로: {req.step_desc}"

    body = {
        "model": "sonar",
        "temperature": 0.7,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]
    }

    try:
        response = requests.post(url, headers=headers, json=body)
        response.raise_for_status()
        result = response.json()
        return {"guidance": result["choices"][0]["message"]["content"]}
    except requests.exceptions.RequestException as e:
        return {"error": f"Perplexity 호출 실패: {str(e)}"}
