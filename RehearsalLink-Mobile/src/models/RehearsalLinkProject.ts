import { AudioSegment } from './AudioSegment';

export interface RehearsalLinkProject {
  id: string; // Unique ID for the project folder
  name: string; // Display name
  audioFileName: string; // Name of the audio file in the project directory
  segments: AudioSegment[];
  summary?: string;
  fullTranscription?: string; // Added for full text
  createdAt: string; // ISO Date string
  modifiedAt: string; // ISO Date string
}
