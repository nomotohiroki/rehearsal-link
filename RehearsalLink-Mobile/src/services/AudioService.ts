import { Audio } from 'expo-av';
import { Recording, Sound } from 'expo-av/build/Audio';

export interface AudioStatus {
  isPlaying: boolean;
  isRecording: boolean;
  positionMillis: number;
  durationMillis: number;
}

class AudioService {
  private recording: Recording | null = null;
  private sound: Sound | null = null;
  private onStatusUpdate: ((status: AudioStatus) => void) | null = null;

  async requestPermissions() {
    await Audio.requestPermissionsAsync();
  }

  async startRecording() {
    try {
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );
      this.recording = recording;

      this.recording.setOnRecordingStatusUpdate((status) => {
        if (this.onStatusUpdate) {
          this.onStatusUpdate({
            isPlaying: false,
            isRecording: status.isRecording,
            positionMillis: status.durationMillis,
            durationMillis: 0,
          });
        }
      });
    } catch (err) {
      console.error('Failed to start recording', err);
    }
  }

  async stopRecording(): Promise<string | null> {
    if (!this.recording) return null;

    await this.recording.stopAndUnloadAsync();
    const uri = this.recording.getURI();
    this.recording = null;
    return uri;
  }

  async loadSound(uri: string) {
    if (this.sound) {
      await this.sound.unloadAsync();
    }

    const { sound } = await Audio.Sound.createAsync(
      { uri },
      { shouldPlay: false },
      (status) => {
        if (status.isLoaded && this.onStatusUpdate) {
          this.onStatusUpdate({
            isPlaying: status.isPlaying,
            isRecording: false,
            positionMillis: status.positionMillis,
            durationMillis: status.durationMillis || 0,
          });
        }
      }
    );
    this.sound = sound;
  }

  async play() {
    if (this.sound) {
      await this.sound.playAsync();
    }
  }

  async pause() {
    if (this.sound) {
      await this.sound.pauseAsync();
    }
  }

  async stop() {
    if (this.sound) {
      await this.sound.stopAsync();
    }
  }

  async seek(positionMillis: number) {
    if (this.sound) {
      await this.sound.setPositionAsync(positionMillis);
    }
  }

  setStatusCallback(callback: (status: AudioStatus) => void) {
    this.onStatusUpdate = callback;
  }
}

export const audioService = new AudioService();
