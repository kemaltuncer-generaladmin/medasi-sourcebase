import {
  estimateGenerationPricing,
  routeOptionsForQuality,
} from "./medasicoin-pricing.ts";
import { resolveImageRoute, routeOptionsFromPayload } from "./model-router.ts";

Deno.test("infographic pricing follows OpenAI image quality tiers", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    SOURCEBASE_SYNC_INFOGRAPHIC_IMAGE_ENABLED: "true",
    TEXT_MODEL_REASONING: "gpt-5.4-mini",
    USD_TRY_RATE: "46",
  }, () => {
    const economy = infographicQuote("economy");
    const standard = infographicQuote("standard");
    const premium = infographicQuote("premium");

    assertEquals(economy.image_route?.model, "gpt-image-1-mini");
    assertEquals(economy.image_route?.quality, "draft");
    assertEquals(standard.image_route?.model, "gpt-image-1.5");
    assertEquals(standard.image_route?.quality, "standard");
    assertEquals(standard.image_route?.provider_quality, "standard");
    assertEquals(premium.image_route?.model, "gpt-image-2");
    assertEquals(premium.image_route?.quality, "premium");
    assert(economy.final_mc_cost < standard.final_mc_cost);
    assert(standard.final_mc_cost < premium.final_mc_cost);
    assertEquals(premium.target_margin, 0.7);
  });
});

Deno.test("infographic image route accepts explicit GPT image model aliases", () => {
  const routeOptions = routeOptionsForQuality(
    "premium",
    routeOptionsFromPayload({
      gptImageModel: "gpt-image-2",
      imageQuality: "premium",
    }),
  );
  const route = resolveImageRoute(
    routeOptions.imageQuality,
    routeOptions.imageModel,
  );

  assertEquals(route.provider, "openai");
  assertEquals(route.model, "gpt-image-2");
  assertEquals(route.quality, "premium");
});

Deno.test("infographic pricing uses Stability fallback when OpenAI is absent", () => {
  withEnv({
    OPENAI_API_KEY: undefined,
    STABILITY_API_KEY: "test-key",
    SOURCEBASE_SYNC_INFOGRAPHIC_IMAGE_ENABLED: "true",
    TEXT_MODEL_REASONING: "gpt-5.4-mini",
    USD_TRY_RATE: "46",
  }, () => {
    const quote = infographicQuote("standard");

    assertEquals(quote.image_route?.provider, "stability");
    assertEquals(quote.image_route?.model, "stable-image-ultra");
    assertEquals(quote.image_route?.quality, "standard");
  });
});

Deno.test("infographic pricing includes image route when visual asset is explicitly required", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    SOURCEBASE_SYNC_INFOGRAPHIC_IMAGE_ENABLED: undefined,
    TEXT_MODEL_REASONING: "gpt-5.4-mini",
    USD_TRY_RATE: "46",
  }, () => {
    const quote = infographicQuote(
      "standard",
      routeOptionsFromPayload({
        visualAssetRequired: "true",
        imageModelPolicy: "gpt-image-1.5",
      }),
    );

    assertEquals(quote.image_route?.provider, "openai");
    assertEquals(quote.image_route?.model, "gpt-image-1.5");
    assertEquals(quote.image_route?.quality, "standard");
  });
});

Deno.test("infographic pricing skips image route unless sync image generation is enabled", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    SOURCEBASE_SYNC_INFOGRAPHIC_IMAGE_ENABLED: undefined,
    TEXT_MODEL_REASONING: "gpt-5.4-mini",
    USD_TRY_RATE: "46",
  }, () => {
    const quote = infographicQuote("standard");

    assertEquals(quote.image_route, undefined);
  });
});

Deno.test("quality tier is authoritative over leaked premium signals", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    TEXT_MODEL_CHEAP: "gpt-5.4-mini",
    TEXT_MODEL_STANDARD: "gpt-5.4-mini",
    TEXT_MODEL_REASONING: "gpt-5.4",
  }, () => {
    // The client floods premium-leaning policy strings on every request.
    const flooded = routeOptionsFromPayload({
      modelPolicy: "premium_latest_long_context_summary_synthesis_first",
      preferredModelTier: "latest_premium_reasoning_long_context",
      outputLengthPolicy: "comprehensive_structured_not_short",
      minimumDepth: "premium_deep",
    });

    const economy = summaryQuote("economy", flooded);
    const standard = summaryQuote("standard", flooded);
    const premium = summaryQuote("premium", flooded);

    // Despite the flooded premium signals, the chosen tier wins the model.
    assertEquals(economy.route.model, "gpt-5.4-mini");
    assertEquals(standard.route.model, "gpt-5.4-mini");
    assertEquals(premium.route.model, "gpt-5.4");
    assertEquals(economy.route.tier, "cheap");
    assertEquals(premium.route.tier, "reasoning");

    // …and MC consumption scales with the tier.
    assert(economy.final_mc_cost < standard.final_mc_cost);
    assert(standard.final_mc_cost < premium.final_mc_cost);
  });
});

Deno.test("standard tier still promotes huge sources to the reasoning model", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    TEXT_MODEL_STANDARD: "gpt-5.4-mini",
    TEXT_MODEL_REASONING: "gpt-5.4",
  }, () => {
    const small = summaryQuote("standard", undefined, 4_000);
    const huge = summaryQuote("standard", undefined, 400_000);
    assertEquals(small.route.model, "gpt-5.4-mini");
    assertEquals(huge.route.model, "gpt-5.4");
  });
});

function summaryQuote(
  qualityTier: "economy" | "standard" | "premium",
  routeOptions?: ReturnType<typeof routeOptionsFromPayload>,
  sourceTextLength = 4_000,
) {
  return estimateGenerationPricing({
    jobType: "summary",
    sourceTextLength,
    qualityTier,
    routeOptions,
  });
}

function infographicQuote(
  qualityTier: "economy" | "standard" | "premium",
  routeOptions?: ReturnType<typeof routeOptionsFromPayload>,
) {
  return estimateGenerationPricing({
    jobType: "infographic",
    sourceTextLength: 4_000,
    qualityTier,
    routeOptions,
  });
}

function withEnv(
  updates: Record<string, string | undefined>,
  run: () => void,
) {
  const previous = new Map<string, string | undefined>();
  for (const [key, value] of Object.entries(updates)) {
    previous.set(key, Deno.env.get(key));
    if (value === undefined) Deno.env.delete(key);
    else Deno.env.set(key, value);
  }
  try {
    run();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

function assert(condition: boolean) {
  if (!condition) throw new Error("Expected condition to be true.");
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}
