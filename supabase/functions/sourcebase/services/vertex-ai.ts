/**
 * SourceBase Vertex AI Integration Service
 * 
 * Google Vertex AI ile içerik üretimi.
 * AGENTS.md Kural 11: API key sadece server-side kullanılır.
 * AGENTS.md Kural 12.4: Prompt injection'a karşı kaynak metni data olarak işlenir.
 */

import {
  Algorithm,
  ComparisonTable,
  Flashcard,
  PodcastScript,
  QuizQuestion,
  SafeError,
  Summary,
} from "../types.ts";

export interface VertexAIConfig {
  projectId: string;
  location: string;
  model: string;
  serviceAccountJson: string;
}

export interface GenerationOptions {
  temperature?: number;
  maxTokens?: number;
  topP?: number;
  topK?: number;
}

export interface GenerationResult<T> {
  content: T;
  inputTokens: number;
  outputTokens: number;
  costEstimate: number;
}

/**
 * Vertex AI client
 */
export class VertexAIClient {
  private config: VertexAIConfig;
  private accessToken?: string;
  private tokenExpiry?: number;

  constructor(config: VertexAIConfig) {
    this.config = config;
  }

  /**
   * Access token al (service account ile)
   */
  private async getAccessToken(): Promise<string> {
    // Token cache kontrolü
    if (this.accessToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
      return this.accessToken;
    }

    try {
      const serviceAccount = JSON.parse(this.config.serviceAccountJson);
      const now = Math.floor(Date.now() / 1000);
      const expiry = now + 3600;

      // JWT oluştur
      const header = {
        alg: "RS256",
        typ: "JWT",
      };

      const claim = {
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/cloud-platform",
        aud: "https://oauth2.googleapis.com/token",
        exp: expiry,
        iat: now,
      };

      const encodedHeader = base64UrlEncode(JSON.stringify(header));
      const encodedClaim = base64UrlEncode(JSON.stringify(claim));
      const signatureInput = `${encodedHeader}.${encodedClaim}`;

      // RS256 signature
      const signature = await this.signJWT(
        signatureInput,
        serviceAccount.private_key,
      );
      const jwt = `${signatureInput}.${signature}`;

      // Token exchange
      const response = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: jwt,
        }),
      });

      if (!response.ok) {
        throw new Error(`Token exchange failed: ${response.status}`);
      }

      const data = await response.json();
      this.accessToken = data.access_token;
      this.tokenExpiry = Date.now() + (data.expires_in * 1000) - 60000; // 1 dakika buffer

      return this.accessToken!;
    } catch (error) {
      throw new SafeError(
        "VERTEX_AUTH_FAILED",
        "Vertex AI kimlik doğrulama başarısız.",
        500,
      );
    }
  }

  /**
   * JWT imzalama
   */
  private async signJWT(data: string, privateKey: string): Promise<string> {
    const key = await crypto.subtle.importKey(
      "pkcs8",
      this.pemToArrayBuffer(privateKey),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(data),
    );

    return base64UrlEncode(new Uint8Array(signature));
  }

  /**
   * PEM to ArrayBuffer
   */
  private pemToArrayBuffer(pem: string): ArrayBuffer {
    const base64 = pem
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\s+/g, "");
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }

  /**
   * Vertex AI API çağrısı
   */
  private async callVertexAI(
    prompt: string,
    systemInstruction: string,
    options: GenerationOptions = {},
  ): Promise<{ text: string; inputTokens: number; outputTokens: number }> {
    const token = await this.getAccessToken();
    const endpoint = `https://${this.config.location}-aiplatform.googleapis.com/v1/projects/${this.config.projectId}/locations/${this.config.location}/publishers/google/models/${this.config.model}:generateContent`;

    const requestBody = {
      contents: [{
        role: "user",
        parts: [{ text: prompt }],
      }],
      systemInstruction: {
        parts: [{ text: systemInstruction }],
      },
      generationConfig: {
        temperature: options.temperature ?? 0.7,
        maxOutputTokens: options.maxTokens ?? 2048,
        topP: options.topP ?? 0.95,
        topK: options.topK ?? 40,
      },
    };

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error("Vertex AI error:", error);
      throw new SafeError(
        "VERTEX_API_ERROR",
        "AI içerik üretimi başarısız.",
        500,
      );
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const inputTokens = data.usageMetadata?.promptTokenCount ?? 0;
    const outputTokens = data.usageMetadata?.candidatesTokenCount ?? 0;

    return { text, inputTokens, outputTokens };
  }

  /**
   * Flashcard üretimi
   * AGENTS.md Kural 12.3: Kart ön yüzü tek, net soru; arka yüz doğrudan cevap
   */
  async generateFlashcards(
    sourceText: string,
    count: number,
    options: GenerationOptions = {},
  ): Promise<GenerationResult<Flashcard[]>> {
    const systemInstruction = `Sen tıp eğitimi için flashcard üreten bir uzmansın.
Kurallar:
- Her kartın ön yüzü tek, net bir soru veya ipucu içermeli
- Arka yüz doğrudan, kısa ve öz cevap vermeli
- Bir kart birden fazla kavramı test etmemeli
- Gereksiz uzun cevaplardan kaçın
- Kaynakta olmayan bilgi uydurmayın
- Türkçe tıbbi terimler kullanın`;

    const prompt = `Aşağıdaki kaynak metinden ${count} adet flashcard üret.
Her kart JSON formatında olmalı: {"front": "soru", "back": "cevap", "explanation": "açıklama", "difficulty": "easy|medium|hard"}

Kaynak metin:
${sourceText}

Lütfen sadece JSON array döndür, başka açıklama ekleme.`;

    const result = await this.callVertexAI(prompt, systemInstruction, options);
    const flashcards = this.parseJSON<Flashcard[]>(result.text);

    return {
      content: flashcards,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      costEstimate: this.calculateCost(result.inputTokens, result.outputTokens),
    };
  }

  /**
   * Quiz üretimi
   */
  async generateQuiz(
    sourceText: string,
    count: number,
    options: GenerationOptions = {},
  ): Promise<GenerationResult<QuizQuestion[]>> {
    const systemInstruction = `Sen tıp eğitimi için çoktan seçmeli sınav soruları üreten bir uzmansın.
Kurallar:
- Her soru net ve anlaşılır olmalı
- 4 seçenek olmalı
- Sadece bir doğru cevap olmalı
- Çeldiriciler mantıklı olmalı
- Her soru için açıklama ekle
- Kaynakta olmayan bilgi uydurmayın`;

    const prompt = `Aşağıdaki kaynak metinden ${count} adet çoktan seçmeli soru üret.
Her soru JSON formatında: {"question": "soru", "options": ["A", "B", "C", "D"], "correctIndex": 0, "explanation": "açıklama", "difficulty": "easy|medium|hard"}

Kaynak metin:
${sourceText}

Lütfen sadece JSON array döndür.`;

    const result = await this.callVertexAI(prompt, systemInstruction, options);
    const questions = this.parseJSON<QuizQuestion[]>(result.text);

    return {
      content: questions,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      costEstimate: this.calculateCost(result.inputTokens, result.outputTokens),
    };
  }

  /**
   * Özet üretimi
   */
  async generateSummary(
    sourceText: string,
    options: GenerationOptions = {},
  ): Promise<GenerationResult<Summary>> {
    const systemInstruction = `Sen tıbbi metinleri özetleyen bir uzmansın.
Kurallar:
- Madde işaretli özet oluştur
- Ana konuları belirt
- Anahtar terimleri listele
- Tam metin özeti de ekle
- Kaynakta olmayan bilgi ekleme`;

    const prompt = `Aşağıdaki metni özetle.
JSON formatı: {"bulletPoints": ["madde1", "madde2"], "fullText": "tam özet", "keyTerms": ["terim1"], "mainTopics": ["konu1"]}

Kaynak metin:
${sourceText}

Lütfen sadece JSON döndür.`;

    const result = await this.callVertexAI(prompt, systemInstruction, options);
    const summary = this.parseJSON<Summary>(result.text);

    return {
      content: summary,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      costEstimate: this.calculateCost(result.inputTokens, result.outputTokens),
    };
  }

  /**
   * Algoritma üretimi
   */
  async generateAlgorithm(
    sourceText: string,
    options: GenerationOptions = {},
  ): Promise<GenerationResult<Algorithm>> {
    const systemInstruction = `Sen tıbbi algoritma ve protokol oluşturan bir uzmansın.
Kurallar:
- Adım adım net talimatlar ver
- Her adımı numaralandır
- Alt adımlar ekleyebilirsin
- Klinik karar noktalarını belirt`;

    const prompt = `Aşağıdaki metinden klinik algoritma oluştur.
JSON formatı: {"title": "başlık", "steps": [{"stepNumber": 1, "title": "adım", "description": "açıklama", "substeps": ["alt1"]}], "notes": ["not1"]}

Kaynak metin:
${sourceText}

Lütfen sadece JSON döndür.`;

    const result = await this.callVertexAI(prompt, systemInstruction, options);
    const algorithm = this.parseJSON<Algorithm>(result.text);

    return {
      content: algorithm,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      costEstimate: this.calculateCost(result.inputTokens, result.outputTokens),
    };
  }

  /**
   * Karşılaştırma tablosu üretimi
   */
  async generateComparison(
    sourceText: string,
    options: GenerationOptions = {},
  ): Promise<GenerationResult<ComparisonTable>> {
    const systemInstruction = `Sen tıbbi kavramları karşılaştıran tablo oluşturan bir uzmansın.
Kurallar:
- Net başlıklar kullan
- Karşılaştırılabilir özellikler seç
- Kısa ve öz bilgi ver`;

    const prompt = `Aşağıdaki metinden karşılaştırma tablosu oluştur.
JSON formatı: {"title": "başlık", "headers": ["özellik", "A", "B"], "rows": [{"label": "özellik1", "values": ["değer1", "değer2"]}]}

Kaynak metin:
${sourceText}

Lütfen sadece JSON döndür.`;

    const result = await this.callVertexAI(prompt, systemInstruction, options);
    const comparison = this.parseJSON<ComparisonTable>(result.text);

    return {
      content: comparison,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      costEstimate: this.calculateCost(result.inputTokens, result.outputTokens),
    };
  }

  /**
   * Podcast script üretimi
   */
  async generatePodcast(
    sourceText: string,
    options: GenerationOptions = {},
  ): Promise<GenerationResult<PodcastScript>> {
    const systemInstruction = `Sen tıbbi konuları podcast formatına dönüştüren bir uzmansın.
Kurallar:
- Konuşma dilinde yaz
- Host ve expert arasında diyalog oluştur
- Anlaşılır ve ilgi çekici ol
- Teknik terimleri açıkla`;

    const prompt = `Aşağıdaki metinden podcast scripti oluştur.
JSON formatı: {"title": "başlık", "duration": "15 dakika", "segments": [{"speaker": "host|expert", "text": "konuşma"}]}

Kaynak metin:
${sourceText}

Lütfen sadece JSON döndür.`;

    const result = await this.callVertexAI(prompt, systemInstruction, options);
    const podcast = this.parseJSON<PodcastScript>(result.text);

    return {
      content: podcast,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      costEstimate: this.calculateCost(result.inputTokens, result.outputTokens),
    };
  }

  /**
   * JSON parse with validation
   * AGENTS.md Kural 12.4: JSON parse hataları güvenli ele alınır
   */
  private parseJSON<T>(text: string): T {
    try {
      // JSON bloğunu bul (markdown code block içinde olabilir)
      const jsonMatch = text.match(/```json\s*([\s\S]*?)\s*```/) ||
        text.match(/```\s*([\s\S]*?)\s*```/) ||
        [null, text];

      const jsonText = jsonMatch[1] || text;
      return JSON.parse(jsonText.trim());
    } catch (error) {
      throw new SafeError(
        "INVALID_AI_OUTPUT",
        "AI çıktısı işlenemedi.",
        500,
      );
    }
  }

  /**
   * Maliyet hesaplama (Vertex AI pricing)
   * Gemini Pro: $0.00025 / 1K input tokens, $0.0005 / 1K output tokens
   */
  private calculateCost(inputTokens: number, outputTokens: number): number {
    const inputCost = (inputTokens / 1000) * 0.00025;
    const outputCost = (outputTokens / 1000) * 0.0005;
    return inputCost + outputCost;
  }
}

/**
 * Base64 URL encode helper
 */
function base64UrlEncode(data: string | Uint8Array): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : data;

  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}
