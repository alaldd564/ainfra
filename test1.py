
# pip install gTTS pygame

from gtts import gTTS
import pygame

def text_to_speech(text, filename='output.mp3', lang='ko'):
    """
    한국어 텍스트를 음성 파일로 변환하고 재생하는 함수
    :param text: 변환할 텍스트
    :param filename: 저장할 MP3 파일명
    :param lang: 언어 코드 ('ko' for Korean)
    """
    # 텍스트를 음성으로 변환하여 파일 저장
    tts = gTTS(text=text, lang=lang)
    tts.save(filename)
    print(f"음성 파일 저장 완료: {filename}")

    # 음성 재생
    pygame.mixer.init()
    pygame.mixer.music.load(filename)
    pygame.mixer.music.play()
    # 재생이 끝날 때까지 대기
    while pygame.mixer.music.get_busy():
        continue

# 사용 예시
if __name__ == "__main__":
    sample_text = "안녕하세요. 오늘 날씨가 참 좋네요."
    text_to_speech(sample_text, "sample_output.mp3")
