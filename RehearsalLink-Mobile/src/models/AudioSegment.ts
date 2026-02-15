export type SegmentType = 'performance' | 'conversation' | 'silence';

export interface AudioSegment {
  id: string; // UUID
  startTime: number; // TimeInterval
  endTime: number; // TimeInterval
  type: SegmentType;
  label?: string;
  transcription?: string;
  isExcludedFromExport: boolean;
}

export const getDuration = (segment: AudioSegment): number => {
  return segment.endTime - segment.startTime;
};
