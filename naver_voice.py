import requests
import os

# 네이버 클로바 TTS API 엔드포인트
CLOVA_TTS_URL = "https://naveropenapi.apigw.ntruss.com/voice-premium/v1/tts"

# 클라이언트 ID와 시크릿 키 (환경 변수 또는 직접 입력)
CLIENT_ID = "4aktoebb8w"
CLIENT_SECRET = "QKmQCMajimRDGxlq7D3gVI12Pf6R88qMTUchgrkH"

def naver_clova_tts(text, speaker='nara', speed=0, pitch=0, volume=1.0, output_path='output.mp3'):
    headers = {
        "X-NCP-APIGW-API-KEY-ID": CLIENT_ID,
        "X-NCP-APIGW-API-KEY": CLIENT_SECRET,
        "Content-Type": "application/x-www-form-urlencoded"
    }
    data = {
        "speaker": speaker,   # 'nara', 'jinho', 'haebyeon' 등 화자 선택 가능
        "text": text,
        "speed": speed,       # -3 ~ +3
        "pitch": pitch,       # -3 ~ +3
        "volume": volume      # 0.0 ~ 3.0
    }
    response = requests.post(CLOVA_TTS_URL, headers=headers, data=data)
    if response.status_code == 200:
        with open(output_path, 'wb') as f:
            f.write(response.content)
        print(f"클로바 TTS 음성 파일 저장 완료: {output_path}")
    else:
        print(f"클로바 TTS 요청 실패: {response.status_code} - {response.text}")

# 사용 예제
if __name__ == "__main__":
    sample_text = "안녕하세요. 음성테스트입니다."
    naver_clova_tts(sample_text, speaker='nara', speed=0, pitch=0, volume=1.0, output_path='order_complete.mp3')
 