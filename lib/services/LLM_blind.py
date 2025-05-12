# import os
# import requests
# import time
# import geopy.distance
# import pyttsx3

# # 환경 변수에서 Perplexity API 키 읽기
# PERPLEXITY_API_KEY = os.environ.get("PERPLEXITY_API_KEY")

# # 예시 출발지/목적지 좌표 (서울시청 → 경복궁)
# start = (37.5665, 126.9780)
# end = (37.5700, 126.9920)

# def get_route_steps(start, end):
#     """
#     실제 서비스에서는 지도 API(Naver, Kakao, Tmap 등)로 대체하세요.
#     아래는 예시 경로 스텝입니다.
#     """
#     return [
#         {"coord": (37.5670, 126.9790), "desc": "100미터 직진"},
#         {"coord": (37.5680, 126.9800), "desc": "좌회전 후 200미터 이동, 오른쪽에 편의점이 있습니다."},
#         {"coord": (37.5700, 126.9920), "desc": "목적지 경복궁에 도착"}
#     ]

# def get_voice_guidance(step_desc, current_pos=None):
#     url = "https://api.perplexity.ai/chat/completions"
#     headers = {
#         "Authorization": f"Bearer {PERPLEXITY_API_KEY}",
#         "Content-Type": "application/json"
#     }
#     system_prompt = (
#         "당신은 시각장애인을 위한 친절하고 안전한 내비게이션 음성 안내 전문가입니다. "
#         "1. 모든 거리는 '미터' 단위로 명확히 알려주세요. "
#         "2. 방향 전환 시 주변 랜드마크(예: 편의점, 신호등, 횡단보도, 버스 정류장 등)를 언급하세요. "
#         "3. 계단, 턱, 공사 구간, 신호등 등 장애물을 사전에 경고하세요. "
#         "4. '천천히 걸으세요', '조심하세요'와 같은 배려 문구를 포함하세요. "
#         "5. 안내는 2~3문장 이내로 간결하게 해주세요. "
#         "6. 안내가 끝나면 '필요하면 다시 말씀해드릴 수 있습니다.'로 마무리하세요."
#     )
#     user_prompt = f"현재 위치: {current_pos if current_pos else '알 수 없음'}, 다음 경로: {step_desc}"
#     payload = {
#         "model": "sonar-medium-online",
#         "messages": [
#             {"role": "system", "content": system_prompt},
#             {"role": "user", "content": user_prompt}
#         ],
#         "temperature": 0.7
#     }
#     response = requests.post(url, headers=headers, json=payload)
#     response.raise_for_status()
#     return response.json()['choices'][0]['message']['content']

# def play_tts(text):
#     engine = pyttsx3.init()
#     engine.setProperty('rate', 150)   # 느린 속도
#     voices = engine.getProperty('voices')
#     # 여성 목소리 선호 시 아래 인덱스 조정 (환경별로 다를 수 있음)
#     engine.setProperty('voice', voices[1].id if len(voices) > 1 else voices[0].id)
#     engine.say(text)
#     engine.runAndWait()

# def get_current_location(route):
#     """
#     실제 환경에서는 GPS/센서 등으로 현재 위치를 받아와야 합니다.
#     예시로 경로를 따라 움직인다고 가정합니다.
#     """
#     for step in route:
#         yield step['coord']
#         time.sleep(2)  # 2초마다 위치 이동(테스트용)

# def check_proximity(current_pos, target_pos, threshold=15):
#     return geopy.distance.distance(current_pos, target_pos).m < threshold

# def main():
#     route = get_route_steps(start, end)
#     location_gen = get_current_location(route)
#     last_guidance = ""
#     for idx, step in enumerate(route):
#         print(f"다음 안내: {step['desc']}")
#         # 현재 위치가 해당 스텝에 근접할 때까지 대기
#         while True:
#             try:
#                 current_pos = next(location_gen)
#             except StopIteration:
#                 break
#             if check_proximity(current_pos, step['coord']):
#                 guidance = get_voice_guidance(step['desc'], current_pos)
#                 print(f"음성 안내: {guidance}")
#                 play_tts(guidance)
#                 last_guidance = guidance
#                 break

#         # 사용자가 안내 반복 요청 시(예시: 실제 앱에서는 음성 인식 등으로 구현)
#         # 아래 코드는 예시로 2초 대기 후 안내 반복
#         print("안내가 잘 들리지 않으면 '다시'라고 말씀하세요.")
#         time.sleep(2)
#         # 실제 환경에서는 아래를 음성 인식 결과로 대체
#         user_input = ""  # 예: "다시"
#         if user_input.strip() == "다시":
#             play_tts(last_guidance)

# if __name__ == "__main__":
#     main()
