import { SafeError } from "../types.ts";
import type { GenerationOptions } from "./vertex-ai.ts";

export interface TextGenerationResult {
  text: string;
  inputTokens: number;
  outputTokens: number;
}

export class OpenAIProvider {
  constructor(private apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "") {}

  async generateText(
    prompt: string,
    systemInstruction: string,
    options: GenerationOptions,
  ): Promise<TextGenerationResult> {
    if (!this.apiKey) {
      throw new SafeError(
        "OPENAI_NOT_CONFIGURED",
        "AI üretim sağlayıcısı yapılandırılmamış.",
        500,
      );
    }
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: options.model,
        input: [
          { role: "system", content: systemInstruction },
          { role: "user", content: prompt },
        ],
        max_output_tokens: options.maxTokens ?? 2048,
      }),
    });
    if (response.status === 401 || response.status === 403) {
      console.error("OpenAI request rejected:", response.status);
      throw new SafeError(
        "OPENAI_AUTH_FAILED",
        "AI üretim sağlayıcısı kimlik doğrulaması başarısız.",
        500,
      );
    }
    if (!response.ok) {
      console.error("OpenAI upstream error:", response.status);
      throw new SafeError(
        "OPENAI_UPSTREAM_ERROR",
        "AI servisine ulaşılamadı.",
        502,
      );
    }
    const data = await response.json().catch(() => ({}));
    const text = data.output_text?.toString() ||
      extractResponsesText(data.output);
    if (!text.trim()) {
      throw new SafeError("EMPTY_AI_OUTPUT", "AI çıktısı boş döndü.", 500);
    }
    return {
      text,
      inputTokens: Number(data.usage?.input_tokens ?? 0),
      outputTokens: Number(data.usage?.output_tokens ?? 0),
    };
  }
}

function extractResponsesText(output: unknown) {
  if (!Array.isArray(output)) return "";
  const chunks: string[] = [];
  for (const item of output) {
    const content = item?.content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      const text = part?.text?.toString() ?? "";
      if (text) chunks.push(text);
    }
  }
  return chunks.join("\n").trim();
}
