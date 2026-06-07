import { parseAlgorithmOrFallback } from "./ai-generation-provider.ts";

Deno.test("algorithm fallback avoids exposing raw source headings as steps", () => {
  const algorithm = parseAlgorithmOrFallback(
    '{"title":"Kalp yetmezligi","steps":[',
    "## Kaynak 1\nKalp yetmezligi, EF azalmasi ve klinik konjesyonla izlenir. Diuretik semptom azaltir.",
  );

  assertEquals(algorithm.steps.length, 4);
  assertEquals(algorithm.steps[0].title, "Başlangıç bulgusunu belirle");
  assertEquals(algorithm.steps[0].title.includes("## Kaynak"), false);
  assertEquals(algorithm.steps[0].description.includes("## Kaynak"), false);
});

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}
