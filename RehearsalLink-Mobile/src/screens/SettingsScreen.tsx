import React, { useState, useEffect } from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { Appbar, TextInput, Button, List, Divider, Text } from 'react-native-paper';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { getApiKey, setApiKey } from '../services/LLMService';

type Props = NativeStackScreenProps<RootStackParamList, 'Settings'>;

const SettingsScreen: React.FC<Props> = ({ navigation }) => {
  const [openaiKey, setOpenaiKey] = useState('');
  const [anthropicKey, setAnthropicKey] = useState('');
  const [geminiKey, setGeminiKey] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadKeys();
  }, []);

  const loadKeys = async () => {
    try {
      const k1 = await getApiKey('OpenAI');
      const k2 = await getApiKey('Anthropic');
      const k3 = await getApiKey('Google Gemini');
      if (k1) setOpenaiKey(k1);
      if (k2) setAnthropicKey(k2);
      if (k3) setGeminiKey(k3);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    try {
      await setApiKey('OpenAI', openaiKey);
      await setApiKey('Anthropic', anthropicKey);
      await setApiKey('Google Gemini', geminiKey);
      Alert.alert('Success', 'API Keys saved successfully.');
      navigation.goBack();
    } catch (e) {
      Alert.alert('Error', 'Failed to save keys.');
    }
  };

  return (
    <View style={styles.container}>
      <Appbar.Header>
        <Appbar.BackAction onPress={() => navigation.goBack()} />
        <Appbar.Content title="Settings" />
      </Appbar.Header>

      <ScrollView contentContainerStyle={styles.content}>
        <List.Section title="AI Providers">
          <List.Subheader>OpenAI (Required for Transcription)</List.Subheader>
          <TextInput
            label="OpenAI API Key"
            value={openaiKey}
            onChangeText={setOpenaiKey}
            secureTextEntry
            style={styles.input}
            autoCapitalize="none"
          />
          <Divider style={styles.divider} />

          <List.Subheader>Anthropic</List.Subheader>
          <TextInput
            label="Anthropic API Key"
            value={anthropicKey}
            onChangeText={setAnthropicKey}
            secureTextEntry
            style={styles.input}
            autoCapitalize="none"
          />
          <Divider style={styles.divider} />

          <List.Subheader>Google Gemini</List.Subheader>
          <TextInput
            label="Gemini API Key"
            value={geminiKey}
            onChangeText={setGeminiKey}
            secureTextEntry
            style={styles.input}
            autoCapitalize="none"
          />
        </List.Section>

        <Button mode="contained" onPress={handleSave} style={styles.button} loading={loading}>
          Save Settings
        </Button>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  content: {
    padding: 16,
  },
  input: {
    marginBottom: 10,
    backgroundColor: '#fff',
  },
  divider: {
    marginVertical: 10,
  },
  button: {
    marginTop: 20,
  },
});

export default SettingsScreen;
