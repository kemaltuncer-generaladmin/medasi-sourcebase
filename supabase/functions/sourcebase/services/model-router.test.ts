import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isImageRouteAvailable, resolveImageRoute } from "./model-router.ts";
import { estimateGenerationPricing } from "./medasicoin-pricing.ts";

Deno.test("infographic route is optional when image providers are missing", () => {
  withImageProviderEnv(undefined, undefined, () => {
    assertEquals(isImageRouteAvailable(resolveImageRoute()), false);
  });
});

Deno.test("infographic pricing adds image cost only when a provider exists", () => {
  const baseInput = {
    jobType: "infographic" as const,
    sourceTextLength: 1_000,
    qualityTier: "standard" as const,
  };

  withImageProviderEnv(undefined, undefined, () => {
    const withoutImage = estimateGenerationPricing(baseInput);
    withImageProviderEnv("test-openai-key", undefined, () => {
      const withImage = estimateGenerationPricing(baseInput);
      assert(
        withImage.estimated_provider_cost_tl >
          withoutImage.estimated_provider_cost_tl,
      );
    });
  });
});

function withImageProviderEnv(
  openAiKey: string | undefined,
  stabilityKey: string | undefined,
  run: () => void,
) {
  const previousOpenAi = Deno.env.get("OPENAI_API_KEY");
  const previousStability = Deno.env.get("STABILITY_API_KEY");
  setOrDelete("OPENAI_API_KEY", openAiKey);
  setOrDelete("STABILITY_API_KEY", stabilityKey);
  try {
    run();
  } finally {
    setOrDelete("OPENAI_API_KEY", previousOpenAi);
    setOrDelete("STABILITY_API_KEY", previousStability);
  }
}

function setOrDelete(key: string, value: string | undefined) {
  if (value === undefined) {
    Deno.env.delete(key);
  } else {
    Deno.env.set(key, value);
  }
}
