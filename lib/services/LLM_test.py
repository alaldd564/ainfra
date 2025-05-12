import requests

url = "https://api.perplexity.ai/chat/completions"
headers = {
    "Authorization": "Bearer YOUR_PERPLEXITY_API_KEY",  # 실제 키로 교체
    "Content-Type": "application/json"
}
data = {
    "model": "sonar", 
    "messages": [
        {"role": "system", "content": "당신은 똑똑한 요리 레시피 추천 AI입니다."},
        {"role": "user", "content": "아래 재료를 모두 포함하는 레시피를 추천해줘. 재료: 양파, 마늘, 토마토"}
    ]
}
response = requests.post(url, headers=headers, json=data)
print(response.json())

