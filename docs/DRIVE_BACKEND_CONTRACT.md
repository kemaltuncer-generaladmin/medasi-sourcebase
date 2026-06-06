# Drive Backend Contract

This document is the deployment contract for the Supabase Edge Function action
named `sourcebase`. The iOS client now expects Drive status to be authoritative
on the backend instead of synthesized from recent files.

## `drive_bootstrap`

The `data` object should include:

- `courses`, `sections`, `files`, `generatedOutputs` or `generated_outputs`
- `uploads` or `uploadTasks` or `upload_tasks`

Each upload row should include either a nested `file` object or enough file
fields to build one, plus:

- `status`: `uploading`, `processing`, `completed`, `failed`, or `draft`
- `progress`: `0...1` or `0...100`
- `errorLabel` / `error_label` / `errorMessage` / `error_message` when failed
- `updated_at` or equivalent ordering metadata on the file row

If `uploads` is absent, the Uploads screen intentionally shows no authoritative
upload lifecycle instead of inventing one from recent files.

## Upload Actions

`create_upload_session` must return:

- `uploadUrl` or `upload_url`
- `objectName` or `object_name`
- `bucket`
- `headers`
- `expiresAt` or `expires_at`

`expiresAt` must be parseable and at least 45 seconds in the future when the
client receives it.

`complete_upload` should atomically verify:

- object exists in the expected bucket
- object belongs to the authenticated user/session
- object size is nonzero and matches session metadata
- content type and extension are supported
- text extraction / processing is queued or the returned file status clearly
  indicates failure

The client no longer silently calls `retry_file_processing` after upload
completion. If processing cannot be queued, return a failed file status or an
action error.

## Generation Jobs

`list_user_jobs` should return `data` as an array or `{ jobs: [...] }` /
`{ rows: [...] }`.

Each job row should include:

- `id` or `jobId` / `job_id`
- `fileId` / `file_id` / `sourceFileId` / `source_file_id`
- `sourceTitle` / `source_title` or file title
- `jobType` / `job_type` / `output_type` / `kind`
- `status`: `queued`, `pending`, `running`, `processing`, `completed`,
  `failed`, or `cancelled`
- `progress`: `0...1` or `0...100`
- `outputId` / `output_id` when a generated output is ready
- `errorMessage` / `error_message` when failed

Completed generation must expose content through `get_generated_content` or a
materialized generated output row. The client treats completed-without-content
as a failure and will not create a placeholder output.
