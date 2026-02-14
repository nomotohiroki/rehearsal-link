import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, Alert, KeyboardAvoidingView, Platform } from 'react-native';
import { Appbar, Button, Card, Text, ActivityIndicator, TextInput } from 'react-native-paper';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { RehearsalLinkProject } from '../models/RehearsalLinkProject';
import { getAudioUri, saveProject } from '../services/StorageService';
import { generateResponse, transcribeAudio } from '../services/LLMService';
import { GPT_4O_MINI } from '../models/LLMModels';

type Props = NativeStackScreenProps<RootStackParamList, 'AIAnalysis'>;

const AIAnalysisScreen: React.FC<Props> = ({ route, navigation }) => {
  const { project: initialProject } = route.params;
  const [project, setProject] = useState<RehearsalLinkProject>(initialProject);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState('');

  const handleAnalyze = async () => {
    setLoading(true);
    setStatus('Initializing...');
    try {
      // 1. Transcription
      let transcript = project.fullTranscription;
      if (!transcript) {
        setStatus('Transcribing audio (this may take a while)...');
        const audioUri = getAudioUri(project);
        // Ensure OpenAI key is set
        // Note: In real app, check key existence first or handle error
        transcript = await transcribeAudio(audioUri); // This function needs to be exported from LLMService
        setStatus('Transcription complete.');
      }

      // 2. Summary
      setStatus('Generating summary...');
      const summaryResponse = await generateResponse({
        prompt: `Please summarize this rehearsal session and list key action items. Transcription:\n\n${transcript}`,
        model: GPT_4O_MINI, // Or user preference
        temperature: 0.7,
      });

      const updatedProject = {
        ...project,
        fullTranscription: transcript,
        summary: summaryResponse.text,
        modifiedAt: new Date().toISOString(),
      };

      setProject(updatedProject);
      await saveProject(updatedProject);
      setStatus('Done!');
    } catch (error: any) {
      console.error(error);
      Alert.alert('Analysis Failed', error.message || 'Unknown error');
    } finally {
      setLoading(false);
      setStatus('');
    }
  };

  return (
    <View style={styles.container}>
      <Appbar.Header>
        <Appbar.BackAction onPress={() => navigation.goBack()} />
        <Appbar.Content title="AI Analysis" />
      </Appbar.Header>

      <ScrollView contentContainerStyle={styles.content}>
        {!project.fullTranscription && !loading && (
          <View style={styles.emptyState}>
            <Text style={{ marginBottom: 20, textAlign: 'center' }}>
              No analysis data yet. Transcribe and analyze your rehearsal to get insights.
            </Text>
            <Button mode="contained" onPress={handleAnalyze}>
              Start AI Analysis
            </Button>
          </View>
        )}

        {loading && (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" />
            <Text style={{ marginTop: 10 }}>{status}</Text>
          </View>
        )}

        {project.summary && (
          <Card style={styles.card}>
            <Card.Title title="Summary & Action Items" />
            <Card.Content>
              <Text variant="bodyMedium">{project.summary}</Text>
            </Card.Content>
          </Card>
        )}

        {project.fullTranscription && (
          <Card style={styles.card}>
            <Card.Title title="Full Transcription" />
            <Card.Content>
              <Text variant="bodySmall" style={{ maxHeight: 300 }}>
                {project.fullTranscription}
              </Text>
            </Card.Content>
          </Card>
        )}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    padding: 16,
    paddingBottom: 40,
  },
  card: {
    marginBottom: 16,
  },
  emptyState: {
    alignItems: 'center',
    marginTop: 50,
  },
  loadingContainer: {
    alignItems: 'center',
    marginVertical: 20,
  },
});

export default AIAnalysisScreen;
