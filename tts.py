from gtts import gTTS
import pygame
import os

def gtts_text_to_speech(text, filename='output.mp3'):
    tts = gTTS(text=text, lang='ko')
    tts.save(filename)
    print(f"파일 저장 완료: {filename}")

    # 재생
    pygame.mixer.init()
    pygame.mixer.music.load(filename)
    pygame.mixer.music.play()
    while pygame.mixer.music.get_busy():
        continue
    # 사용 후 삭제 가능
    # os.remove(filename)

# 사용 예시
if __name__ == "__main__":
    sample_text = "안녕하세요. 이것은 구글 텍스트 투 스피치 예제입니다."
    gtts_text_to_speech(sample_text)
