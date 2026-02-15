import React, { useState, useEffect, useRef } from 'react';
import { View, StyleSheet, ScrollView, Alert, Dimensions } from 'react-native';
import { Appbar, Button, Card, Text, ProgressBar, IconButton, List, Chip } from 'react-native-paper';
import { useNavigation, useRoute } from '@react-navigation/native';
import { NativeStackNavigationProp, NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { RehearsalLinkProject } from '../models/RehearsalLinkProject';
import { AudioSegment, SegmentType } from '../models/AudioSegment';
import { audioService, AudioStatus } from '../services/AudioService';
import { createProject, saveProject, getAudioUri } from '../services/StorageService';
import * as FileSystem from 'expo-file-system/legacy';

type StudioScreenProps = NativeStackScreenProps<RootStackParamList, 'Studio'>;

const StudioScreen: React.FC<StudioScreenProps> = ({ route, navigation }) => {
  const { project: initialProject } = route.params;
  const [project, setProject] = useState<RehearsalLinkProject | undefined>(initialProject);
  const [recording, setRecording] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [segments, setSegments] = useState<AudioSegment[]>(initialProject?.segments || []);

  // Timer for recording
  const [recordingTime, setRecordingTime] = useState(0);
  const recordingInterval = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    // If we have a project, load the audio
    if (project) {
      const uri = getAudioUri(project);
      audioService.loadSound(uri);
    }

    return () => {
      audioService.stop();
    };
  }, [project?.id]);

  useEffect(() => {
    audioService.setStatusCallback((status: AudioStatus) => {
      setPlaying(status.isPlaying);
      setPosition(status.positionMillis);
      if (status.durationMillis > 0) {
        setDuration(status.durationMillis);
      }
    });
  }, []);

  const handleRecordPress = async () => {
    if (recording) {
      // Stop recording
      const uri = await audioService.stopRecording();
      setRecording(false);
      if (recordingInterval.current) clearInterval(recordingInterval.current);

      if (uri) {
        // Create a new project with this recording
        const newProject = await createProject(uri, recordingTime);
        setProject(newProject);
        // Load the audio for playback
        audioService.loadSound(uri);
      }
    } else {
      // Start recording
      await audioService.requestPermissions();
      await audioService.startRecording();
      setRecording(true);
      setRecordingTime(0);
      recordingInterval.current = setInterval(() => {
        setRecordingTime(prev => prev + 100);
      }, 100);
    }
  };

  const handlePlayPause = async () => {
    if (playing) {
      await audioService.pause();
    } else {
      await audioService.play();
    }
  };

  const formatTime = (millis: number) => {
    const minutes = Math.floor(millis / 60000);
    const seconds = ((millis % 60000) / 1000).toFixed(0);
    return `${minutes}:${Number(seconds) < 10 ? '0' : ''}${seconds}`;
  };

  const addSegment = () => {
    if (!project) return;
    const newSegment: AudioSegment = {
      id: Math.random().toString(36).substr(2, 9),
      startTime: position,
      endTime: position + 5000, // Default 5s
      type: 'performance',
      label: 'New Segment',
      isExcludedFromExport: false,
    };
    const updatedSegments = [...segments, newSegment];
    setSegments(updatedSegments);

    // Save project
    const updatedProject = { ...project, segments: updatedSegments };
    setProject(updatedProject);
    saveProject(updatedProject);
  };

  return (
    <View style={styles.container}>
      <Appbar.Header>
        <Appbar.BackAction onPress={() => navigation.goBack()} />
        <Appbar.Content title={project?.name || 'New Recording'} />
        {project && (
          <Appbar.Action icon="creation" onPress={() => navigation.navigate('AIAnalysis', { project })} />
        )}
      </Appbar.Header>

      <View style={styles.content}>
        {/* Waveform Placeholder */}
        <Card style={styles.waveformCard}>
          <Card.Content>
            <View style={styles.waveformPlaceholder}>
              <Text style={{ color: '#fff' }}>
                {recording ? formatTime(recordingTime) : formatTime(position)} / {formatTime(duration)}
              </Text>
              <ProgressBar progress={duration > 0 ? position / duration : 0} color="#6200ee" style={styles.progressBar} />
            </View>
          </Card.Content>
        </Card>

        {/* Controls */}
        <View style={styles.controls}>
          <IconButton
            icon={recording ? "stop" : "record"}
            iconColor={recording ? "black" : "red"}
            size={40}
            onPress={handleRecordPress}
            style={{ backgroundColor: recording ? '#eee' : '#fff' }}
            disabled={!!project && !recording} // Disable recording if project exists (simple version)
          />
          {project && (
            <IconButton
              icon={playing ? "pause" : "play"}
              size={40}
              onPress={handlePlayPause}
            />
          )}
          {project && (
            <Button mode="outlined" onPress={addSegment} style={styles.segmentButton}>
              Mark Segment
            </Button>
          )}
        </View>

        {/* Segments List */}
        <ScrollView style={styles.segmentsContainer}>
          <Text variant="titleMedium" style={styles.sectionTitle}>Segments</Text>
          {segments.map((segment, index) => (
            <List.Item
              key={segment.id}
              title={segment.label || `Segment ${index + 1}`}
              description={`${formatTime(segment.startTime)} - ${formatTime(segment.endTime)}`}
              left={props => <List.Icon {...props} icon="bookmark" />}
              onPress={() => audioService.seek(segment.startTime)}
              right={props => (
                <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                  <Chip>{segment.type}</Chip>
                </View>
              )}
            />
          ))}
          {segments.length === 0 && (
            <Text style={{ textAlign: 'center', marginTop: 20, color: '#888' }}>
              No segments marked yet.
            </Text>
          )}
        </ScrollView>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    flex: 1,
    padding: 16,
  },
  waveformCard: {
    marginBottom: 20,
    backgroundColor: '#333',
    height: 150,
    justifyContent: 'center',
  },
  waveformPlaceholder: {
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
  },
  progressBar: {
    width: '100%',
    height: 10,
    borderRadius: 5,
    marginTop: 10,
    backgroundColor: '#555',
  },
  controls: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
    gap: 20,
  },
  segmentButton: {
    marginLeft: 10,
  },
  segmentsContainer: {
    flex: 1,
  },
  sectionTitle: {
    marginBottom: 10,
    fontWeight: 'bold',
  },
});

export default StudioScreen;
