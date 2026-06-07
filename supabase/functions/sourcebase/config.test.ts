import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { runtimeConfigStatus } from "./config.ts";

Deno.test("runtime config reports S3 and invalid Vertex JSON status", () => {
  withEnv(
    {
      SOURCEBASE_S3_BUCKET: "medasistorage",
      SOURCEBASE_S3_ENDPOINT: "https://storage.medasi.com.tr",
      SOURCEBASE_S3_ACCESS_KEY: "access",
      SOURCEBASE_S3_SECRET_KEY: "secret",
      VERTEX_SERVICE_ACCOUNT_JSON: "not-json",
      CLIENT_EXTRACTION_ENABLED: undefined,
      OPENAI_API_KEY: undefined,
      STABILITY_API_KEY: undefined,
    },
    () => {
      const status = runtimeConfigStatus();
      assertEquals(status.storage.provider, "s3");
      assertEquals(status.storage.s3Configured, true);
      assertEquals(status.vertex.serviceAccountConfigured, true);
      assertEquals(status.vertex.serviceAccountValid, false);
      assertEquals(status.image.providerConfigured, false);
      assertEquals(status.extraction.clientExtractionEnabled, true);
    },
  );
});

Deno.test("runtime config can disable client extraction", () => {
  withEnv({ CLIENT_EXTRACTION_ENABLED: "off" }, () => {
    const status = runtimeConfigStatus();
    assertEquals(status.extraction.clientExtractionEnabled, false);
  });
});

function withEnv(
  values: Record<string, string | undefined>,
  run: () => void,
) {
  const previous = Object.fromEntries(
    Object.keys(values).map((key) => [key, Deno.env.get(key)]),
  );
  for (const [key, value] of Object.entries(values)) {
    setOrDelete(key, value);
  }
  try {
    run();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      setOrDelete(key, value);
    }
  }
}

function setOrDelete(key: string, value: string | undefined) {
  if (value === undefined) {
    Deno.env.delete(key);
  } else {
    Deno.env.set(key, value);
  }
}
