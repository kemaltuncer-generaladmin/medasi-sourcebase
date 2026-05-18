import { GenerationType, SafeError } from "../types.ts";
import {
  resolveImageRoute,
  resolveTextRoute,
  RouteOptions,
} from "./model-router.ts";

export type QualityTier = "economy" | "standard" | "premium";
export type SourceSizeTier = "tiny" | "short" | "medium" | "large" | "huge";

export interface McPricingQuote {
  estimated_provider_cost_tl: number;
  target_margin: number;
  estimated_revenue_tl: number;
  raw_mc_cost: number;
  final_mc_cost: number;
  amount_units: number;
  mc_unit: number;
  quality_tier: QualityTier;
  model_tier: string;
  source_size_tier: SourceSizeTier;
  reserved_mc: number;
  route: {
    provider: string;
    model: string;
    tier: string;
    reason: string;
    fallbackUsed: boolean;
  };
}

const MC_UNITS_PER_MC = 100;
const FALLBACK_MC_TL_VALUE_CENTS = 350;
const FALLBACK_COST_RATIO_BPS = 3000;
const FALLBACK_MARGIN = 0.7;

const SOURCE_MULTIPLIER_BPS: Record<SourceSizeTier, number> = {
  tiny: 10_000,
  short: 10_000,
  medium: 11_500,
  large: 13_500,
  huge: 17_500,
};

const MIN_UNITS: Record<string, Record<QualityTier, number>> = {
  central_ai: { economy: 5, standard: 10, premium: 200 },
  summary: { economy: 25, standard: 50, premium: 100 },
  flashcard: { economy: 25, standard: 75, premium: 150 },
  quiz: { economy: 50, standard: 100, premium: 200 },
  algorithm: { economy: 100, standard: 100, premium: 200 },
  comparison: { economy: 100, standard: 100, premium: 200 },
  mind_map: { economy: 100, standard: 100, premium: 200 },
  clinical_scenario: { economy: 200, standard: 200, premium: 400 },
  learning_plan: { economy: 150, standard: 150, premium: 300 },
  podcast: { economy: 150, standard: 150, premium: 300 },
  infographic: { economy: 300, standard: 300, premium: 600 },
};

const MODEL_COST_MICRO_TL: Record<string, { input: number; output: number }> = {
  "gemini-2.5-flash-lite": { input: 15, output: 60 },
  "gemini-2.5-flash": { input: 30, output: 120 },
  "gpt-5.4-mini": { input: 120, output: 480 },
  "gpt-5.4": { input: 400, output: 1600 },
};

const IMAGE_COST_MICRO_TL: Record<string, number> = {
  "gpt-image-1-mini": 1_500_000,
  "gpt-image-2": 4_000_000,
  "stable-image-ultra": 3_000_000,
};

export function normalizeQualityTier(value: unknown): QualityTier {
  const text = value?.toString().trim().toLowerCase();
  if (text === "economy" || text === "standard" || text === "premium") {
    return text;
  }
  return "standard";
}

export function routeOptionsForQuality(
  qualityTier: QualityTier,
  options: RouteOptions,
): RouteOptions {
  return {
    ...options,
    cheap: qualityTier === "economy" || options.cheap,
    premium: qualityTier === "premium" || options.premium,
    imageQuality: qualityTier === "premium"
      ? "premium"
      : options.imageQuality ?? "standard",
  };
}

export function estimateGenerationPricing(input: {
  jobType: GenerationType | "central_ai";
  sourceTextLength: number;
  maxTokens?: number;
  count?: number;
  qualityTier: QualityTier;
  routeOptions?: RouteOptions;
}): McPricingQuote {
  const sourceSizeTier = classifySourceSize(input.sourceTextLength);
  const routeOptions = routeOptionsForQuality(
    input.qualityTier,
    input.routeOptions ?? {},
  );
  const route = resolveTextRoute(
    input.jobType === "central_ai" ? "central_ai_chat" : input.jobType,
    routeOptions,
    input.sourceTextLength,
  );
  const modelCost = modelCostMicroTl(route.model);
  const inputTokens = Math.max(1, Math.ceil(input.sourceTextLength / 4));
  const outputTokens = Math.max(
    256,
    input.maxTokens ?? defaultOutputTokens(input.jobType, input.count),
  );
  let providerCostMicroTl = inputTokens * modelCost.input +
    outputTokens * modelCost.output;
  providerCostMicroTl = Math.ceil(
    providerCostMicroTl * SOURCE_MULTIPLIER_BPS[sourceSizeTier] / 10_000,
  );

  if (input.jobType === "infographic") {
    const imageRoute = resolveImageRoute(routeOptions.imageQuality);
    providerCostMicroTl += imageCostMicroTl(imageRoute.model);
  }

  const calculatedUnits = costMicroTlToMcUnits(providerCostMicroTl);
  const minimumUnits = minUnits(input.jobType, input.qualityTier);
  const finalUnits = input.qualityTier === "premium"
    ? roundUpUnitsToStep(Math.max(calculatedUnits, minimumUnits))
    : roundUpUnitsToStep(Math.max(calculatedUnits, minimumUnits));
  const standardUnits = input.qualityTier === "premium"
    ? estimateGenerationPricing({
      ...input,
      qualityTier: "standard",
      routeOptions: { ...(input.routeOptions ?? {}), premium: false },
    }).amount_units
    : undefined;
  const amountUnits = input.qualityTier === "premium" && standardUnits
    ? roundUpUnitsToStep(Math.max(finalUnits, standardUnits * 2))
    : finalUnits;

  return quoteFromUnits({
    providerCostMicroTl,
    amountUnits,
    qualityTier: input.qualityTier,
    sourceSizeTier,
    route,
  });
}

export function formatMc(units: number) {
  const whole = Math.trunc(units / MC_UNITS_PER_MC);
  const cents = units % MC_UNITS_PER_MC;
  if (cents === 0) return `${whole}`;
  return `${whole}.${String(cents).padStart(2, "0").replace(/0+$/, "")}`;
}

function quoteFromUnits(input: {
  providerCostMicroTl: number;
  amountUnits: number;
  qualityTier: QualityTier;
  sourceSizeTier: SourceSizeTier;
  route: ReturnType<typeof resolveTextRoute>;
}): McPricingQuote {
  const providerCostTl = input.providerCostMicroTl / 1_000_000;
  const revenueTl = providerCostTl / costRatio();
  const rawMc = revenueTl / mcTlValue();
  const finalMc = input.amountUnits / MC_UNITS_PER_MC;
  return {
    estimated_provider_cost_tl: roundMoney(providerCostTl),
    target_margin: targetMargin(),
    estimated_revenue_tl: roundMoney(revenueTl),
    raw_mc_cost: roundMc(rawMc),
    final_mc_cost: finalMc,
    amount_units: input.amountUnits,
    mc_unit: minMcUnit(),
    quality_tier: input.qualityTier,
    model_tier: input.route.tier,
    source_size_tier: input.sourceSizeTier,
    reserved_mc: finalMc,
    route: {
      provider: input.route.provider,
      model: input.route.model,
      tier: input.route.tier,
      reason: input.route.reason,
      fallbackUsed: input.route.fallbackUsed,
    },
  };
}

function costMicroTlToMcUnits(providerCostMicroTl: number) {
  const mcTlCents = mcTlValueCents();
  const costRatioBps = costRatioBasisPoints();
  const denominator = costRatioBps * mcTlCents;
  const numerator = providerCostMicroTl * 100;
  return roundUpUnitsToStep(Math.ceil(numerator / denominator));
}

function minUnits(jobType: GenerationType | "central_ai", tier: QualityTier) {
  return MIN_UNITS[jobType]?.[tier] ?? MIN_UNITS.summary[tier];
}

function modelCostMicroTl(model: string) {
  return MODEL_COST_MICRO_TL[model] ?? MODEL_COST_MICRO_TL[
    Deno.env.get("TEXT_MODEL_STANDARD")?.trim() || "gemini-2.5-flash"
  ] ?? MODEL_COST_MICRO_TL["gemini-2.5-flash"];
}

function imageCostMicroTl(model: string) {
  return IMAGE_COST_MICRO_TL[model] ?? IMAGE_COST_MICRO_TL[
    Deno.env.get("IMAGE_MODEL_DRAFT")?.trim() || "gpt-image-1-mini"
  ] ?? IMAGE_COST_MICRO_TL["gpt-image-1-mini"];
}

function classifySourceSize(length: number): SourceSizeTier {
  if (length < 1_500) return "tiny";
  if (length < 15_000) return "short";
  if (length < 90_000) return "medium";
  if (length < 300_000) return "large";
  return "huge";
}

function defaultOutputTokens(
  jobType: GenerationType | "central_ai",
  count?: number,
) {
  switch (jobType) {
    case "flashcard":
      return Math.max(1024, (count ?? 20) * 90);
    case "quiz":
      return Math.max(1200, (count ?? 10) * 140);
    case "summary":
      return 1200;
    case "infographic":
      return 1600;
    case "central_ai":
      return 900;
    default:
      return 1500;
  }
}

function roundUpUnitsToStep(units: number) {
  const step = minUnitAsUnits();
  return Math.ceil(units / step) * step;
}

function mcTlValue() {
  return mcTlValueCents() / 100;
}

function mcTlValueCents() {
  return Math.round(
    Number(Deno.env.get("MC_TL_VALUE") ?? "3.5") * 100,
  ) || FALLBACK_MC_TL_VALUE_CENTS;
}

function targetMargin() {
  return Number(Deno.env.get("TARGET_GROSS_MARGIN") ?? "0.70") ||
    FALLBACK_MARGIN;
}

function costRatio() {
  return costRatioBasisPoints() / 10_000;
}

function costRatioBasisPoints() {
  return Math.round((1 - targetMargin()) * 10_000) ||
    FALLBACK_COST_RATIO_BPS;
}

function minMcUnit() {
  return Number(Deno.env.get("MIN_MC_UNIT") ?? "0.05") || 0.05;
}

function minUnitAsUnits() {
  return Math.max(1, Math.round(minMcUnit() * MC_UNITS_PER_MC));
}

function roundMoney(value: number) {
  return Math.round(value * 10_000) / 10_000;
}

function roundMc(value: number) {
  return Math.round(value * 10_000) / 10_000;
}

export function insufficientBalance(
  balanceUnits: number,
  quote: McPricingQuote,
) {
  return new SafeError(
    "INSUFFICIENT_MC",
    `Yetersiz MedasiCoin bakiyesi. Gerekli: ${
      formatMc(quote.amount_units)
    } MC.`,
    402,
  );
}
