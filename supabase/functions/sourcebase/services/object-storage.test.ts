import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { SafeError } from "../types.ts";
import { createSignedPutUrl } from "./object-storage.ts";

Deno.test("createSignedPutUrl uses SourceBase S3 path-style object paths", async () => {
  const url = await createSignedPutUrl({
    storage: {
      provider: "s3",
      publicEndpoint: "https://storage.medasi.com.tr",
      endpoint: "https://storage.medasi.com.tr",
      bucket: "medasistorage",
      region: "us-east-1",
      accessKeyId: "access",
      secretAccessKey: "secret",
    },
    objectName:
      "sourcebase/users/user-1/uploads/2026/06/00000000-0000-4000-8000-000000000000-test.pdf",
    expiresInSeconds: 900,
  });

  const parsed = new URL(url);
  assertEquals(parsed.origin, "https://storage.medasi.com.tr");
  assertEquals(
    parsed.pathname,
    "/medasistorage/sourcebase/users/user-1/uploads/2026/06/00000000-0000-4000-8000-000000000000-test.pdf",
  );
  assertEquals(parsed.searchParams.get("X-Amz-Algorithm"), "AWS4-HMAC-SHA256");
  assert(parsed.searchParams.has("X-Amz-Signature"));
});

Deno.test("createSignedPutUrl rejects unsafe object paths", async () => {
  await assertRejects(
    () =>
      createSignedPutUrl({
        storage: {
          provider: "s3",
          publicEndpoint: "https://storage.medasi.com.tr",
          endpoint: "https://storage.medasi.com.tr",
          bucket: "medasistorage",
          region: "us-east-1",
          accessKeyId: "access",
          secretAccessKey: "secret",
        },
        objectName: "../escape.pdf",
        expiresInSeconds: 900,
      }),
    SafeError,
  );
});
