import { GenerationType } from "../types.ts";

export type TextProvider = "google" | "openai" | "anthropic";
export type ImageProviderName = "openai" | "stability";

export interface TextRoute {
  provider: TextProvider;
  model: string;
  tier: "cheap" | "standard" | "reasoning" | "reviewer";
  reason: string;
  fallbackUsed: boolean;
}

export interface ImageRoute {
  provider: ImageProviderName;
  model: string;
  fallbackProvider: ImageProviderName;
  fallbackModel: string;
  quality: "draft" | "standard" | "premium";
}

export interface RouteOptions {
  premium?: boolean;
  clinical?: boolean;
  hard?: boolean;
  cheap?: boolean;
  short?: boolean;
  structured?: boolean;
  personalized?: boolean;
  naturalNarration?: boolean;
  complex?: boolean;
  imageQuality?: "draft" | "standard" | "premium" | "low";
}

const DEFAULT_TEXT_PROVIDER: TextProvider = "google";

export function resolveTextRoute(
  jobType: GenerationType | "central_ai_chat" | "infographic_spec",
  options: RouteOptions = {},
  sourceTextLength = 0,
): TextRoute {
  const configuredDefault = textProviderEnv("TEXT_PROVIDER_DEFAULT") ??
    DEFAULT_TEXT_PROVIDER;
  const cheap = textModel("TEXT_MODEL_CHEAP", "gemini-2.5-flash-lite");
  const standard = textModel("TEXT_MODEL_STANDARD", "gemini-2.5-flash");
  const reasoning = textModel("TEXT_MODEL_REASONING", "gpt-5.4-mini");
  const reviewer = textModel("TEXT_MODEL_REVIEWER", "gpt-5.4");

  let selected = standard;
  let tier: TextRoute["tier"] = "standard";
  let reason = `${jobType}:standard`;

  switch (jobType) {
    case "flashcard":
      if (options.cheap) {
        selected = cheap;
        tier = "cheap";
        reason = "flashcard:cheap";
      } else if (options.premium || options.clinical) {
        selected = reasoning;
        tier = "reasoning";
        reason = "flashcard:premium_or_clinical";
      }
      break;
    case "quiz":
      if (options.clinical || options.hard) {
        selected = reasoning;
        tier = "reasoning";
        reason = "question:clinical_or_hard";
      }
      break;
    case "summary":
      if (options.short) {
        selected = cheap;
        tier = "cheap";
        reason = "summary:short";
      } else if (options.premium) {
        selected = reasoning;
        tier = "reasoning";
        reason = "summary:premium";
      } else if (options.structured) {
        selected = standard;
        reason = "summary:structured";
      }
      break;
    case "algorithm":
      if (options.clinical) {
        selected = reasoning;
        tier = "reasoning";
        reason = "algorithm:clinical_decision";
      }
      break;
    case "comparison":
      if (options.complex || sourceTextLength > 80_000) {
        selected = reasoning;
        tier = "reasoning";
        reason = "comparison:large_or_complex";
      }
      break;
    case "clinical_scenario":
      selected = options.premium ? reviewer : reasoning;
      tier = options.premium ? "reviewer" : "reasoning";
      reason = options.premium
        ? "clinical_scenario:premium_review"
        : "clinical_scenario:reasoning";
      break;
    case "learning_plan":
      if (options.personalized || options.premium) {
        selected = reasoning;
        tier = "reasoning";
        reason = "learning_plan:personalized_or_premium";
      }
      break;
    case "podcast":
      if (options.naturalNarration || options.premium) {
        selected = reasoning;
        tier = "reasoning";
        reason = "podcast:natural_narration";
      }
      break;
    case "mind_map":
      if (options.complex || sourceTextLength > 80_000) {
        selected = reasoning;
        tier = "reasoning";
        reason = "mind_map:complex";
      }
      break;
    case "infographic":
    case "infographic_spec":
      selected = reasoning;
      tier = "reasoning";
      reason = "infographic:spec_reasoning";
      break;
    case "central_ai_chat":
      selected = options.premium || options.clinical ? reasoning : standard;
      tier = options.premium || options.clinical ? "reasoning" : "standard";
      reason = options.premium || options.clinical
        ? "central_ai:reasoning"
        : "central_ai:standard";
      break;
  }

  const desiredProvider = providerForModel(selected, configuredDefault);
  if (isTextProviderAvailable(desiredProvider)) {
    return {
      provider: desiredProvider,
      model: selected,
      tier,
      reason,
      fallbackUsed: false,
    };
  }

  const fallbackModel = standard || Deno.env.get("VERTEX_MODEL")?.trim() ||
    "gemini-2.5-flash";
  return {
    provider: "google",
    model: fallbackModel,
    tier: "standard",
    reason: `${reason}:provider_fallback`,
    fallbackUsed: true,
  };
}

export function resolveImageRoute(
  quality: RouteOptions["imageQuality"] = "standard",
): ImageRoute {
  const normalizedQuality = quality === "low" ? "draft" : quality ?? "standard";
  return {
    provider: imageProviderEnv("IMAGE_PROVIDER_DEFAULT") ?? "openai",
    model: normalizedQuality === "premium"
      ? imageModel("IMAGE_MODEL_PREMIUM", "gpt-image-2")
      : imageModel("IMAGE_MODEL_DRAFT", "gpt-image-1-mini"),
    fallbackProvider: imageProviderEnv("IMAGE_PROVIDER_FALLBACK") ??
      "stability",
    fallbackModel: imageModel("IMAGE_MODEL_FALLBACK", "stable-image-ultra"),
    quality: normalizedQuality,
  };
}

export function routeOptionsFromPayload(
  value: Record<string, unknown> | undefined,
): RouteOptions {
  const options = value ?? {};
  return {
    premium: truthy(options.premium) || options.tier === "premium",
    clinical: truthy(options.clinical) || options.style === "clinical",
    hard: truthy(options.hard) || options.difficulty === "hard",
    cheap: truthy(options.cheap) || options.tier === "cheap",
    short: truthy(options.short) || options.mode === "short",
    structured: truthy(options.structured) || options.mode === "structured" ||
      options.mode === "exam-morning",
    personalized: truthy(options.personalized),
    naturalNarration: truthy(options.naturalNarration),
    complex: truthy(options.complex),
    imageQuality: imageQuality(options.imageQuality),
  };
}

export function isImageProviderAvailable(provider: ImageProviderName) {
  if (provider === "openai") return Boolean(Deno.env.get("OPENAI_API_KEY"));
  return Boolean(Deno.env.get("STABILITY_API_KEY"));
}

function isTextProviderAvailable(provider: TextProvider) {
  if (provider === "google") return true;
  if (provider === "openai") return Boolean(Deno.env.get("OPENAI_API_KEY"));
  return Boolean(Deno.env.get("ANTHROPIC_API_KEY"));
}

function providerForModel(model: string, fallback: TextProvider): TextProvider {
  const normalized = model.toLowerCase();
  if (normalized.startsWith("gpt-") || normalized.startsWith("o")) {
    return "openai";
  }
  if (normalized.includes("claude")) return "anthropic";
  if (normalized.includes("gemini")) return "google";
  return fallback;
}

function textModel(name: string, fallback: string) {
  return Deno.env.get(name)?.trim() || fallback;
}

function imageModel(name: string, fallback: string) {
  return Deno.env.get(name)?.trim() || fallback;
}

function textProviderEnv(name: string): TextProvider | undefined {
  const value = Deno.env.get(name)?.trim().toLowerCase();
  return value === "google" || value === "openai" || value === "anthropic"
    ? value
    : undefined;
}

function imageProviderEnv(name: string): ImageProviderName | undefined {
  const value = Deno.env.get(name)?.trim().toLowerCase();
  return value === "openai" || value === "stability" ? value : undefined;
}

function truthy(value: unknown) {
  return value === true || value?.toString().toLowerCase() === "true";
}

function imageQuality(value: unknown): RouteOptions["imageQuality"] {
  const text = value?.toString().trim().toLowerCase();
  if (
    text === "draft" || text === "standard" || text === "premium" ||
    text === "low"
  ) {
    return text;
  }
  return undefined;
}
