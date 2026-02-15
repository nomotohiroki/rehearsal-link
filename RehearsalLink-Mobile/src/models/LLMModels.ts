export type LLMProvider = 'OpenAI' | 'Anthropic' | 'Google Gemini';

export interface LLMModel {
  id: string;
  name: string;
  provider: LLMProvider;
  contextWindow: number;
}

export const GPT_4O: LLMModel = { id: 'gpt-4o', name: 'GPT-4o', provider: 'OpenAI', contextWindow: 128000 };
export const GPT_4O_MINI: LLMModel = { id: 'gpt-4o-mini', name: 'GPT-4o Mini', provider: 'OpenAI', contextWindow: 128000 };

export const CLAUDE_46_OPUS: LLMModel = { id: 'claude-opus-4-6', name: 'Claude 4.6 Opus', provider: 'Anthropic', contextWindow: 400000 };
export const CLAUDE_45_SONNET: LLMModel = { id: 'claude-sonnet-4-5-20250929', name: 'Claude 4.5 Sonnet', provider: 'Anthropic', contextWindow: 400000 };
export const CLAUDE_45_HAIKU: LLMModel = { id: 'claude-haiku-4-5-20251001', name: 'Claude 4.5 Haiku', provider: 'Anthropic', contextWindow: 400000 };

export const GEMINI_15_PRO: LLMModel = { id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro', provider: 'Google Gemini', contextWindow: 1000000 };
export const GEMINI_15_FLASH: LLMModel = { id: 'gemini-1.5-flash', name: 'Gemini 1.5 Flash', provider: 'Google Gemini', contextWindow: 1000000 };

export const ALL_MODELS: LLMModel[] = [
  GPT_4O,
  GPT_4O_MINI,
  CLAUDE_46_OPUS,
  CLAUDE_45_SONNET,
  CLAUDE_45_HAIKU,
  GEMINI_15_PRO,
  GEMINI_15_FLASH,
];

export interface LLMRequest {
  prompt: string;
  systemPrompt?: string;
  model: LLMModel;
  temperature: number;
  maxTokens?: number;
}

export interface LLMResponse {
  text: string;
  usage?: LLMUsage;
}

export interface LLMUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}
