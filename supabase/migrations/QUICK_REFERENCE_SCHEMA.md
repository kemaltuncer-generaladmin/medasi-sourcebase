# SourceBase Schema Quick Reference

## Table Relationships

```
auth.users (Supabase Auth)
    ↓
    ├─→ sourcebase.app_memberships (user roles)
    ├─→ sourcebase.sources (user content)
    │       ↓
    │       └─→ sourcebase.decks (flashcard collections)
    │               ↓
    │               ├─→ sourcebase.cards (individual flashcards)
    │               └─→ sourcebase.study_progress (user progress per card)
    │
    ├─→ sourcebase.generated_jobs (AI generation tracking)
    ├─→ sourcebase.purchases (payment records)
    │       ↓
    │       └─→ sourcebase.entitlements (access grants)
    │
    └─→ sourcebase.study_sessions (study tracking)

sourcebase.products (marketplace items)
    ↓
    └─→ sourcebase.product_decks (product → deck mapping)
```

## Common Queries

### User Management

```sql
-- Check user's role in SourceBase
select role, status 
from sourcebase.app_memberships 
where user_id = auth.uid() and app_code = 'sourcebase';

-- Check if user is admin
select sourcebase.is_admin(auth.uid());
```

### Deck & Card Access

```sql
-- Get user's own decks
select * from sourcebase.decks 
where owner_user_id = auth.uid();

-- Get marketplace decks
select * from sourcebase.decks 
where visibility = 'marketplace' and status = 'published';

-- Get decks user has entitlement to
select d.* 
from sourcebase.decks d
join sourcebase.entitlements e on e.deck_id = d.id
where e.user_id = auth.uid() and e.status = 'active';

-- Check if user has access to a deck
select sourcebase.has_deck_entitlement(auth.uid(), '<deck_id>');

-- Get cards from a deck (with RLS protection)
select * from sourcebase.cards 
where deck_id = '<deck_id>'
order by sort_order;
```

### Content Generation

```sql
-- Create a source
insert into sourcebase.sources (owner_user_id, source_type, title, text_content, status)
values (auth.uid(), 'manual_text', 'My Notes', 'Content here...', 'active')
returning *;

-- Track AI generation job
insert into sourcebase.generated_jobs (
  owner_user_id, source_id, job_type, status, model
)
values (
  auth.uid(), '<source_id>', 'flashcards', 'queued', 'gpt-4'
)
returning *;

-- Update job status
update sourcebase.generated_jobs
set status = 'completed', 
    output_tokens = 1500,
    cost_estimate = 0.045
where id = '<job_id>' and owner_user_id = auth.uid();
```

### Marketplace & Purchases

```sql
-- Get published products
select p.*, 
  (select count(*) from sourcebase.product_decks pd where pd.product_id = p.id) as deck_count
from sourcebase.products p
where status = 'published';

-- Record a purchase
insert into sourcebase.purchases (
  user_id, product_id, provider, provider_payment_id, 
  amount_cents, currency, status
)
values (
  auth.uid(), '<product_id>', 'stripe', 'pi_xxx', 
  9900, 'TRY', 'completed'
)
returning *;

-- Grant entitlement after purchase
insert into sourcebase.entitlements (
  user_id, product_id, deck_id, source_purchase_id, status
)
select 
  '<user_id>', '<product_id>', pd.deck_id, '<purchase_id>', 'active'
from sourcebase.product_decks pd
where pd.product_id = '<product_id>';
```

### Study Progress

```sql
-- Start a study session
insert into sourcebase.study_sessions (user_id, deck_id, started_at)
values (auth.uid(), '<deck_id>', now())
returning *;

-- Get cards due for review
select c.*, sp.next_review_at, sp.ease_score
from sourcebase.cards c
left join sourcebase.study_progress sp 
  on sp.card_id = c.id and sp.user_id = auth.uid()
where c.deck_id = '<deck_id>'
  and (sp.next_review_at is null or sp.next_review_at <= now())
order by sp.next_review_at nulls first, c.sort_order
limit 20;

-- Record card review
insert into sourcebase.study_progress (
  user_id, card_id, deck_id, ease_score, review_count, 
  last_reviewed_at, next_review_at, status
)
values (
  auth.uid(), '<card_id>', '<deck_id>', 2.5, 1,
  now(), now() + interval '1 day', 'learning'
)
on conflict (user_id, card_id) 
do update set
  ease_score = excluded.ease_score,
  review_count = study_progress.review_count + 1,
  last_reviewed_at = excluded.last_reviewed_at,
  next_review_at = excluded.next_review_at,
  status = excluded.status;

-- End study session
update sourcebase.study_sessions
set ended_at = now(),
    metadata = jsonb_build_object(
      'cards_reviewed', 15,
      'duration_seconds', 900
    )
where id = '<session_id>' and user_id = auth.uid();
```

### Admin Operations

```sql
-- Create a marketplace product (via Edge Function with service_role)
insert into sourcebase.products (slug, title, description, price_cents, currency, status)
values ('medical-terminology', 'Medical Terminology Flashcards', 'Complete medical terms', 9900, 'TRY', 'published')
returning *;

-- Link decks to product
insert into sourcebase.product_decks (product_id, deck_id)
values ('<product_id>', '<deck_id>');

-- Grant admin role
insert into sourcebase.app_memberships (user_id, app_code, role, status)
values ('<user_id>', 'sourcebase', 'admin', 'active')
on conflict (user_id, app_code) 
do update set role = 'admin', status = 'active';

-- Revoke entitlement
update sourcebase.entitlements
set status = 'revoked'
where id = '<entitlement_id>';
```

## Status Enums

### source_type
- `manual_text` - User typed content
- `pdf` - PDF upload
- `docx` - Word document
- `url` - Web content
- `qlinik_context` - Data from Qlinik
- `admin_seed` - Admin-created content

### visibility
- `private` - Only owner can see
- `unlisted` - Anyone with link can see
- `marketplace` - Listed in marketplace
- `admin` - Admin-created public content

### job_type
- `flashcards` - Generate flashcards
- `summary` - Generate summary
- `quiz` - Generate quiz questions
- `notes` - Generate study notes
- `outline` - Generate outline
- `questions` - Generate practice questions

### job_status
- `queued` - Waiting to process
- `processing` - Currently generating
- `completed` - Successfully completed
- `failed` - Generation failed
- `cancelled` - User cancelled

### payment_provider
- `stripe` - Stripe payment
- `iyzico` - Iyzico payment
- `manual` - Manual payment
- `admin_grant` - Admin granted access

### entitlement_status
- `active` - Currently active
- `expired` - Time expired
- `revoked` - Manually revoked
- `suspended` - Temporarily suspended

### study_status
- `new` - Never reviewed
- `learning` - Currently learning
- `reviewing` - In review cycle
- `mastered` - Fully mastered
- `suspended` - User suspended

### app_role
- `user` - Regular user
- `premium` - Premium subscriber
- `admin` - Administrator
- `owner` - System owner

## Security Notes

⚠️ **Client-Side**: Only use `SUPABASE_ANON_KEY`
⚠️ **Server-Side**: Use `SUPABASE_SERVICE_ROLE_KEY` only in Edge Functions
⚠️ **RLS**: All tables have RLS enabled - test policies thoroughly
⚠️ **Admin Operations**: Must go through Edge Function with proper auth checks

## Performance Tips

✅ Use indexes for filtering:
- Filter by `owner_user_id` (indexed)
- Filter by `status` (indexed)
- Filter by `visibility` (indexed)
- Use `deck_id` for card queries (indexed)

✅ Pagination:
```sql
select * from sourcebase.decks
where owner_user_id = auth.uid()
order by created_at desc
limit 20 offset 0;
```

✅ Count efficiently:
```sql
select count(*) from sourcebase.cards where deck_id = '<deck_id>';
```

## Audit Logging

```sql
-- Log important actions
insert into sourcebase.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
values (
  auth.uid(),
  'deck_published',
  'deck',
  '<deck_id>',
  jsonb_build_object('visibility', 'marketplace', 'price_cents', 9900)
);

-- Query audit logs
select * from sourcebase.audit_logs
where actor_user_id = auth.uid()
order by created_at desc
limit 50;
```

## Migration Commands

```bash
# Apply migration (Supabase CLI)
supabase db push

# Or via SQL
psql $DATABASE_URL -f supabase/migrations/20260516_complete_sourcebase_schema.sql

# Verify migration
psql $DATABASE_URL -f supabase/migrations/test_20260516_migration.sql
```
