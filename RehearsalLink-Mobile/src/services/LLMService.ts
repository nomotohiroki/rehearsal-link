import AsyncStorage from '@react-native-async-storage/async-storage';
import { LLMRequest, LLMResponse, LLMProvider, LLMModel } from '../models/LLMModels';

const API_KEY_KEYS = {
  OpenAI: 'LLM_API_KEY_OPENAI',
  Anthropic: 'LLM_API_KEY_ANTHROPIC',
  'Google Gemini': 'LLM_API_KEY_GEMINI',
};

export const getApiKey = async (provider: LLMProvider): Promise<string | null> => {
  return AsyncStorage.getItem(API_KEY_KEYS[provider]);
};

export const setApiKey = async (provider: LLMProvider, key: string): Promise<void> => {
  return AsyncStorage.setItem(API_KEY_KEYS[provider], key);
};

export const generateResponse = async (request: LLMRequest): Promise<LLMResponse> => {
  const apiKey = await getApiKey(request.model.provider);
  if (!apiKey) {
    throw new Error(`No API key found for provider ${request.model.provider}`);
  }

  switch (request.model.provider) {
    case 'OpenAI':
      return callOpenAI(apiKey, request);
    case 'Anthropic':
      return callAnthropic(apiKey, request);
    case 'Google Gemini':
      return callGemini(apiKey, request);
    default:
      throw new Error('Unsupported provider');
  }
};

const callOpenAI = async (apiKey: string, request: LLMRequest): Promise<LLMResponse> => {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: request.model.id,
      messages: [
        { role: 'system', content: request.systemPrompt || 'You are a helpful assistant.' },
        { role: 'user', content: request.prompt },
      ],
      temperature: request.temperature,
      max_tokens: request.maxTokens,
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error?.message || 'OpenAI API Error');
  }

  return {
    text: data.choices[0].message.content,
    usage: {
      promptTokens: data.usage.prompt_tokens,
      completionTokens: data.usage.completion_tokens,
      totalTokens: data.usage.total_tokens,
    },
  };
};

const callAnthropic = async (apiKey: string, request: LLMRequest): Promise<LLMResponse> => {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: request.model.id,
      max_tokens: request.maxTokens || 1024,
      system: request.systemPrompt,
      messages: [{ role: 'user', content: request.prompt }],
      temperature: request.temperature,
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error?.message || 'Anthropic API Error');
  }

  return {
    text: data.content[0].text,
    usage: {
      promptTokens: data.usage.input_tokens,
      completionTokens: data.usage.output_tokens,
      totalTokens: data.usage.input_tokens + data.usage.output_tokens,
    },
  };
};

const callGemini = async (apiKey: string, request: LLMRequest): Promise<LLMResponse> => {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${request.model.id}:generateContent?key=${apiKey}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: request.prompt }] }],
      systemInstruction: request.systemPrompt ? { parts: [{ text: request.systemPrompt }] } : undefined,
      generationConfig: {
        temperature: request.temperature,
        maxOutputTokens: request.maxTokens,
      },
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error?.message || 'Gemini API Error');
  }

  const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';

  return {
    text,
    usage: {
      promptTokens: data.usageMetadata?.promptTokenCount || 0,
      completionTokens: data.usageMetadata?.candidatesTokenCount || 0,
      totalTokens: data.usageMetadata?.totalTokenCount || 0,
    },
  };
};

export const transcribeAudio = async (audioUri: string): Promise<string> => {
  const apiKey = await getApiKey('OpenAI');
  if (!apiKey) {
    throw new Error('OpenAI API Key required for transcription');
  }

  const formData = new FormData();
  formData.append('file', {
    uri: audioUri,
    name: 'audio.m4a',
    type: 'audio/m4a',
  } as any);
  formData.append('model', 'whisper-1');

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'multipart/form-data',
    },
    body: formData,
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error?.message || 'Transcription Failed');
  }

  return data.text;
};
