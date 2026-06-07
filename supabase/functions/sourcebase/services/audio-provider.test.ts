import {
  concatAudioBuffers,
  planSpeechChunks,
  splitForSpeech,
} from "./audio-provider.ts";
import { resolvePodcastAudioRoute } from "./model-router.ts";
import { PodcastScript } from "../types.ts";

const route = resolvePodcastAudioRoute({ premium: true });

Deno.test("planSpeechChunks maps host and expert to distinct voices", () => {
  const script: PodcastScript = {
    title: "Kalp yetmezliği",
    duration: "12 dakika",
    segments: [
      { speaker: "host", text: "Bugün kalp yetmezliğini konuşuyoruz." },
      { speaker: "expert", text: "Önce ejeksiyon fraksiyonunu sınıflayalım." },
      { speaker: "host", text: "Peki tedavi nasıl ilerliyor?" },
    ],
  };

  const { chunks, truncated } = planSpeechChunks(script, route);

  assertEquals(chunks.length, 3);
  assertEquals(chunks[0].voice, route.hostVoice);
  assertEquals(chunks[1].voice, route.expertVoice);
  assertEquals(chunks[2].voice, route.hostVoice);
  assertEquals(truncated, false);
});

Deno.test("planSpeechChunks skips empty segments and trims whitespace", () => {
  const script: PodcastScript = {
    title: "Test",
    duration: "5 dakika",
    segments: [
      { speaker: "host", text: "   " },
      { speaker: "expert", text: "Tek\n\n  anlamlı   replik." },
    ],
  };

  const { chunks, characterCount } = planSpeechChunks(script, route);

  assertEquals(chunks.length, 1);
  assertEquals(chunks[0].text, "Tek anlamlı replik.");
  assertEquals(characterCount, "Tek anlamlı replik.".length);
});

Deno.test("planSpeechChunks truncates beyond the total character budget", () => {
  const longText = "A".repeat(20_000);
  const script: PodcastScript = {
    title: "Uzun",
    duration: "30 dakika",
    segments: [{ speaker: "host", text: longText }],
  };

  const { truncated, characterCount } = planSpeechChunks(script, route);

  assertEquals(truncated, true);
  assertEquals(characterCount <= 12_000, true);
});

Deno.test("splitForSpeech keeps every piece within the request ceiling", () => {
  const sentence = "Bu uzun bir tıbbi cümledir. ".repeat(400);
  const pieces = splitForSpeech(sentence);

  assertEquals(pieces.length > 1, true);
  for (const piece of pieces) {
    assertEquals(piece.length <= 3_800, true);
  }
});

Deno.test("concatAudioBuffers preserves order and length", () => {
  const merged = concatAudioBuffers([
    new Uint8Array([1, 2]),
    new Uint8Array([3]),
    new Uint8Array([4, 5, 6]),
  ]);

  assertEquals(Array.from(merged).join(","), "1,2,3,4,5,6");
  assertEquals(merged.byteLength, 6);
});

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}
