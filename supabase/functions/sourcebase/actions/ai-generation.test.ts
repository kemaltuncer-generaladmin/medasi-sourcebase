import { defaultMaxTokens } from "./ai-generation.ts";

Deno.test("defaultMaxTokens protects structured generation jobs from truncation", () => {
  assertEquals(defaultMaxTokens("summary", 1_200), 4096);
  assertEquals(defaultMaxTokens("learning_plan", 1_200), 4096);
  assertEquals(defaultMaxTokens("algorithm", 1_200), 4096);
});

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}
