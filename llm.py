# 퍼플렉시티 api의 경우 한국어 음성 -> 텍스트 지원 X 이번 3분기 업데이트 예정
import sounddevice as sd
from scipy.io.wavfile import write
import requests
import tempfile
import os

def record_audio(duration=5, fs=16000):
    print("녹음을 시작합니다. 말하세요...")
    recording = sd.rec(int(duration * fs), samplerate=fs, channels=1, dtype='int16')
    sd.wait()
    print("녹음이 완료되었습니다.")
    return recording, fs

def save_to_wav(recording, fs):
    temp_wav = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
    write(temp_wav.name, fs, recording)
    return temp_wav.name

def speech_to_text_perplexity(wav_path):
    api_url = "https://api.perplexity.ai/speech-to-text"
    headers = {'Authorization': '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'}  # API 키 입력
    with open(wav_path, 'rb') as f:
        files = {'file': f}
        params = {'language': 'ko'}
        response = requests.post(api_url, headers=headers, files=files, params=params)
    if response.status_code == 200:
        return response.json().get('text', '')
    else:
        return f"Error: {response.status_code} - {response.text}"

def main():
    duration = 5  # 녹음 시간(초)
    recording, fs = record_audio(duration)
    wav_path = save_to_wav(recording, fs)
    text = speech_to_text_perplexity(wav_path)
    print("인식된 텍스트:", text)
    os.remove(wav_path)

if __name__ == '__main__':
    main()
