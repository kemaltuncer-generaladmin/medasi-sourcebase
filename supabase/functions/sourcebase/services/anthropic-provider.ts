import { SafeError } from "../types.ts";
import type { GenerationOptions } from "./vertex-ai.ts";
import type { TextGenerationResult } from "./openai-provider.ts";

export class AnthropicProvider {
  constructor(
    private apiKey = Deno.env.get("ANTHROPIC_API_KEY")?.trim() ?? "",
  ) {}

  async generateText(
    prompt: string,
    systemInstruction: string,
    options: GenerationOptions,
  ): Promise<TextGenerationResult> {
    if (!this.apiKey) {
      throw new SafeError(
        "ANTHROPIC_NOT_CONFIGURED",
        "AI üretim sağlayıcısı yapılandırılmamış.",
        500,
      );
    }
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": this.apiKey,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: options.model,
        system: systemInstruction,
        max_tokens: options.maxTokens ?? 2048,
        temperature: options.temperature,
        messages: [{ role: "user", content: prompt }],
      }),
    });
    if (response.status === 401 || response.status === 403) {
      console.error("Anthropic request rejected:", response.status);
      throw new SafeError(
        "ANTHROPIC_AUTH_FAILED",
        "AI üretim sağlayıcısı kimlik doğrulaması başarısız.",
        500,
      );
    }
    if (!response.ok) {
      console.error("Anthropic upstream error:", response.status);
      throw new SafeError(
        "ANTHROPIC_UPSTREAM_ERROR",
        "AI servisine ulaşılamadı.",
        502,
      );
    }
    const data = await response.json().catch(() => ({}));
    const text = Array.isArray(data.content)
      ? data.content
        .map((part: { text?: unknown }) => part.text?.toString() ?? "")
        .join("\n")
        .trim()
      : "";
    if (!text) {
      throw new SafeError("EMPTY_AI_OUTPUT", "AI çıktısı boş döndü.", 500);
    }
    return {
      text,
      inputTokens: Number(data.usage?.input_tokens ?? 0),
      outputTokens: Number(data.usage?.output_tokens ?? 0),
    };
  }
}
