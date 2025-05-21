import requests
import tempfile
import os
from playsound3 import playsound

# 1. 주소 → 좌표 변환 (네이버 지도 API)
def get_coords_by_address(address, client_id, client_secret):
    url = "https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode"
    headers = {
        "X-NCP-APIGW-API-KEY-ID": client_id,
        "X-NCP-APIGW-API-KEY": client_secret
    }
    params = {"query": address}
    resp = requests.get(url, headers=headers, params=params)
    data = resp.json()
    if data.get("addresses"):
        addr = data["addresses"][0]
        return float(addr["y"]), float(addr["x"])
    else:
        print(f"'{address}'의 좌표를 찾을 수 없습니다.")
        return None, None

# 2. 경로 안내 요청 (네이버 지도 API)
def get_naver_route(start_lat, start_lon, end_lat, end_lon, client_id, client_secret):
    url = "https://naveropenapi.apigw.ntruss.com/map-direction/v1/driving"
    headers = {
        "X-NCP-APIGW-API-KEY-ID": client_id,
        "X-NCP-APIGW-API-KEY": client_secret
    }
    params = {
        "start": f"{start_lon},{start_lat}",
        "goal": f"{end_lon},{end_lat}",
        "option": "trafast"
    }
    resp = requests.get(url, headers=headers, params=params)
    return resp.json()

# 3. 퍼플렉시티 API로 안내문 생성
def get_perplexity_response(prompt, api_key):
    url = "https://api.perplexity.ai/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "accept": "application/json",
        "content-type": "application/json"
    }
    data = {
        "model": "sonar",  # 또는 pplx 지원 모델
        "stream": False,
        "max_tokens": 512,
        "temperature": 0.5,
        "messages": [
            {"role": "system", "content": "운전자가 듣기 좋은 자연스러운 한국어 음성 안내문을 만들어 주세요."},
            {"role": "user", "content": prompt}
        ]
    }
    resp = requests.post(url, headers=headers, json=data)
    if resp.status_code == 200:
        return resp.json()["choices"][0]["message"]["content"]
    else:
        print("Perplexity API 오류:", resp.text)
        return None

# 4. TTS로 안내문 읽어주기 (네이버 CLOVA)
def tts_naver(text, tts_client_id, tts_client_secret):
    url = "https://naveropenapi.apigw.ntruss.com/tts-premium/v1/tts"
    headers = {
        "X-NCP-APIGW-API-KEY-ID": tts_client_id,
        "X-NCP-APIGW-API-KEY": tts_client_secret
    }
    data = {
        "speaker": "nara",
        "speed": "0",
        "text": text
    }
    response = requests.post(url, headers=headers, data=data)
    if response.status_code == 200:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
            f.write(response.content)
            temp_path = f.name
        playsound(temp_path)
        os.remove(temp_path)
    else:
        print("TTS 변환 실패:", response.text)

def main():
    # API 키 입력
    map_client_id = "YOUR_NAVER_MAP_CLIENT_ID"
    map_client_secret = "YOUR_NAVER_MAP_CLIENT_SECRET"
    tts_client_id = "YOUR_NAVER_TTS_CLIENT_ID"
    tts_client_secret = "YOUR_NAVER_TTS_CLIENT_SECRET"
    pplx_api_key = "YOUR_PERPLEXITY_API_KEY"

    origin = input("출발지를 입력하세요: ")
    destination = input("도착지를 입력하세요: ")

    start_lat, start_lon = get_coords_by_address(origin, map_client_id, map_client_secret)
    end_lat, end_lon = get_coords_by_address(destination, map_client_id, map_client_secret)
    if None in (start_lat, start_lon, end_lat, end_lon):
        print("좌표 변환에 실패했습니다.")
        return

    route = get_naver_route(start_lat, start_lon, end_lat, end_lon, map_client_id, map_client_secret)
    if "route" in route and "trafast" in route["route"]:
        summary = route["route"]["trafast"][0]["summary"]
        steps = route["route"]["trafast"][0]["guide"]
        # 안내문 생성을 위한 프롬프트 구성
        prompt = f"""출발지는 {origin}, 도착지는 {destination}입니다. 총 거리 {summary['distance']/1000:.1f}킬로미터, 예상 소요시간 {summary['duration']//60000}분입니다.
주요 안내 단계는 다음과 같습니다:
"""
        for step in steps[:3]:
            prompt += f"- {step['instructions']}\n"
        prompt += "위 정보를 바탕으로 운전자가 듣기 편한 자연스러운 음성 안내문을 만들어 주세요."

        # 퍼플렉시티 API로 안내문 생성
        guide_text = get_perplexity_response(prompt, pplx_api_key)
        if guide_text:
            print("\n--- 퍼플렉시티 기반 안내문 ---\n", guide_text)
            # TTS로 안내문 음성 출력
            tts_naver(guide_text, tts_client_id, tts_client_secret)
        else:
            print("퍼플렉시티 안내문 생성에 실패했습니다.")
    else:
        print("길안내 정보를 가져오지 못했습니다.")

if __name__ == "__main__":
    main()
