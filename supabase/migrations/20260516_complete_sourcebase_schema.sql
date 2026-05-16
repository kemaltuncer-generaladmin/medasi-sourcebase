-- SourceBase Schema Completion Migration
-- Date: 2026-05-16
-- Purpose: Add all missing tables for flashcards, marketplace, study progress, and app memberships
-- CRITICAL: This migration only touches sourcebase schema - Qlinik tables are NOT modified

-- ============================================================================
-- PART 1: SOURCES TABLE (for content generation)
-- ============================================================================

create table if not exists sourcebase.sources (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null check (source_type in ('manual_text', 'pdf', 'docx', 'url', 'qlinik_context', 'admin_seed')),
  title text,
  original_filename text,
  storage_path text,
  text_content text,
  metadata jsonb not null default '{}',
  status text not null default 'active' check (status in ('active', 'archived', 'deleted', 'processing', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- PART 2: DECKS TABLE (flashcard collections)
-- ============================================================================

create table if not exists sourcebase.decks (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete cascade,
  visibility text not null default 'private' check (visibility in ('private', 'unlisted', 'marketplace', 'admin')),
  title text not null,
  description text,
  language text,
  subject text,
  level text,
  source_id uuid references sourcebase.sources(id) on delete set null,
  is_marketplace_item boolean not null default false,
  status text not null default 'active' check (status in ('active', 'draft', 'published', 'archived', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- PART 3: CARDS TABLE (individual flashcards)
-- ============================================================================

create table if not exists sourcebase.cards (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references sourcebase.decks(id) on delete cascade,
  front text not null,
  back text not null,
  explanation text,
  tags text[] not null default '{}',
  difficulty text check (difficulty in ('easy', 'medium', 'hard')),
  sort_order integer not null default 0,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- PART 4: GENERATED_JOBS TABLE (AI content generation tracking)
-- ============================================================================

create table if not exists sourcebase.generated_jobs (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  source_id uuid references sourcebase.sources(id) on delete set null,
  deck_id uuid references sourcebase.decks(id) on delete set null,
  job_type text not null check (job_type in ('flashcards', 'summary', 'quiz', 'notes', 'outline', 'questions')),
  status text not null default 'queued' check (status in ('queued', 'processing', 'completed', 'failed', 'cancelled')),
  model text,
  input_tokens integer,
  output_tokens integer,
  cost_estimate numeric(10, 6),
  error_message text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- PART 5: MARKETPLACE PRODUCTS
-- ============================================================================

create table if not exists sourcebase.products (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  description text,
  price_cents integer not null check (price_cents >= 0),
  currency text not null default 'TRY',
  status text not null default 'draft' check (status in ('draft', 'published', 'archived', 'deleted')),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sourcebase.product_decks (
  product_id uuid not null references sourcebase.products(id) on delete cascade,
  deck_id uuid not null references sourcebase.decks(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (product_id, deck_id)
);

-- ============================================================================
-- PART 6: PURCHASES & ENTITLEMENTS
-- ============================================================================

create table if not exists sourcebase.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references sourcebase.products(id) on delete restrict,
  provider text not null check (provider in ('stripe', 'iyzico', 'manual', 'admin_grant')),
  provider_payment_id text,
  amount_cents integer not null check (amount_cents >= 0),
  currency text not null default 'TRY',
  status text not null default 'pending' check (status in ('pending', 'completed', 'failed', 'refunded', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sourcebase.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid references sourcebase.products(id) on delete set null,
  deck_id uuid references sourcebase.decks(id) on delete cascade,
  source_purchase_id uuid references sourcebase.purchases(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'expired', 'revoked', 'suspended')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- PART 7: STUDY SESSIONS & PROGRESS
-- ============================================================================

create table if not exists sourcebase.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  deck_id uuid not null references sourcebase.decks(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  metadata jsonb not null default '{}'
);

create table if not exists sourcebase.study_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null references sourcebase.cards(id) on delete cascade,
  deck_id uuid not null references sourcebase.decks(id) on delete cascade,
  ease_score numeric(5, 2),
  review_count integer not null default 0,
  last_reviewed_at timestamptz,
  next_review_at timestamptz,
  status text not null default 'new' check (status in ('new', 'learning', 'reviewing', 'mastered', 'suspended')),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, card_id)
);

-- ============================================================================
-- PART 8: APP MEMBERSHIPS (role & permission management)
-- ============================================================================

create table if not exists sourcebase.app_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  app_code text not null check (app_code in ('sourcebase', 'qlinik')),
  role text not null check (role in ('user', 'premium', 'admin', 'owner')),
  status text not null default 'active' check (status in ('active', 'suspended', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, app_code)
);

-- ============================================================================
-- PART 9: INDEXES FOR PERFORMANCE
-- ============================================================================

-- Sources indexes
create index if not exists sourcebase_sources_owner_idx on sourcebase.sources(owner_user_id);
create index if not exists sourcebase_sources_type_status_idx on sourcebase.sources(source_type, status);

-- Decks indexes
create index if not exists sourcebase_decks_owner_idx on sourcebase.decks(owner_user_id);
create index if not exists sourcebase_decks_visibility_status_idx on sourcebase.decks(visibility, status);
create index if not exists sourcebase_decks_marketplace_idx on sourcebase.decks(is_marketplace_item) where is_marketplace_item = true;
create index if not exists sourcebase_decks_source_idx on sourcebase.decks(source_id);

-- Cards indexes
create index if not exists sourcebase_cards_deck_idx on sourcebase.cards(deck_id);
create index if not exists sourcebase_cards_deck_sort_idx on sourcebase.cards(deck_id, sort_order);
create index if not exists sourcebase_cards_tags_idx on sourcebase.cards using gin(tags);

-- Generated jobs indexes
create index if not exists sourcebase_generated_jobs_owner_idx on sourcebase.generated_jobs(owner_user_id);
create index if not exists sourcebase_generated_jobs_status_idx on sourcebase.generated_jobs(status);
create index if not exists sourcebase_generated_jobs_source_idx on sourcebase.generated_jobs(source_id);
create index if not exists sourcebase_generated_jobs_deck_idx on sourcebase.generated_jobs(deck_id);

-- Products indexes
create index if not exists sourcebase_products_slug_idx on sourcebase.products(slug);
create index if not exists sourcebase_products_status_idx on sourcebase.products(status);

-- Purchases indexes
create index if not exists sourcebase_purchases_user_idx on sourcebase.purchases(user_id);
create index if not exists sourcebase_purchases_product_idx on sourcebase.purchases(product_id);
create index if not exists sourcebase_purchases_provider_payment_idx on sourcebase.purchases(provider, provider_payment_id);

-- Entitlements indexes
create index if not exists sourcebase_entitlements_user_idx on sourcebase.entitlements(user_id);
create index if not exists sourcebase_entitlements_product_idx on sourcebase.entitlements(product_id);
create index if not exists sourcebase_entitlements_deck_idx on sourcebase.entitlements(deck_id);
create index if not exists sourcebase_entitlements_user_deck_idx on sourcebase.entitlements(user_id, deck_id);
create index if not exists sourcebase_entitlements_status_idx on sourcebase.entitlements(status);

-- Study sessions indexes
create index if not exists sourcebase_study_sessions_user_idx on sourcebase.study_sessions(user_id);
create index if not exists sourcebase_study_sessions_deck_idx on sourcebase.study_sessions(deck_id);
create index if not exists sourcebase_study_sessions_user_deck_idx on sourcebase.study_sessions(user_id, deck_id);

-- Study progress indexes
create index if not exists sourcebase_study_progress_user_idx on sourcebase.study_progress(user_id);
create index if not exists sourcebase_study_progress_card_idx on sourcebase.study_progress(card_id);
create index if not exists sourcebase_study_progress_deck_idx on sourcebase.study_progress(deck_id);
create index if not exists sourcebase_study_progress_next_review_idx on sourcebase.study_progress(next_review_at) where status in ('learning', 'reviewing');

-- App memberships indexes
create index if not exists sourcebase_app_memberships_user_idx on sourcebase.app_memberships(user_id);
create index if not exists sourcebase_app_memberships_app_role_idx on sourcebase.app_memberships(app_code, role);

-- ============================================================================
-- PART 10: UPDATED_AT TRIGGERS
-- ============================================================================

-- Create trigger function if not exists
create or replace function sourcebase.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply triggers to all tables with updated_at
create trigger update_sourcebase_sources_updated_at before update on sourcebase.sources
  for each row execute function sourcebase.update_updated_at_column();

create trigger update_sourcebase_decks_updated_at before update on sourcebase.decks
  for each row execute function sourcebase.update_updated_at_column();

create trigger update_sourcebase_cards_updated_at before update on sourcebase.cards
  for each row execute function sourcebase.update_updated_at_column();

create trigger update_sourcebase_generated_jobs_updated_at before update on sourcebase.generated_jobs
  for each row execute function sourcebase.update_updated_at_column();

create trigger update_sourcebase_products_updated_at before update on sourcebase.products
  for each row execute function sourcebase.update_updated_at_column();

create trigger update_sourcebase_purchases_updated_at before update on sourcebase.purchases
  for each row execute function sourcebase.update_updated_at_column();

create trigger update_sourcebase_entitlements_updated_at before update on sourcebase.entitlements
  for each row execute function sourcebase.update_updated_at_column();

create trigger update_sourcebase_study_progress_updated_at before update on sourcebase.study_progress
  for each row execute function sourcebase.update_updated_at_column();

create trigger update_sourcebase_app_memberships_updated_at before update on sourcebase.app_memberships
  for each row execute function sourcebase.update_updated_at_column();

-- ============================================================================
-- PART 11: ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
alter table sourcebase.sources enable row level security;
alter table sourcebase.decks enable row level security;
alter table sourcebase.cards enable row level security;
alter table sourcebase.generated_jobs enable row level security;
alter table sourcebase.products enable row level security;
alter table sourcebase.product_decks enable row level security;
alter table sourcebase.purchases enable row level security;
alter table sourcebase.entitlements enable row level security;
alter table sourcebase.study_sessions enable row level security;
alter table sourcebase.study_progress enable row level security;
alter table sourcebase.app_memberships enable row level security;

-- ============================================================================
-- SOURCES POLICIES
-- ============================================================================

drop policy if exists "sourcebase_sources_owner_all" on sourcebase.sources;
create policy "sourcebase_sources_owner_all"
  on sourcebase.sources for all
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

-- ============================================================================
-- DECKS POLICIES
-- ============================================================================

-- Users can see their own decks
drop policy if exists "sourcebase_decks_owner_select" on sourcebase.decks;
create policy "sourcebase_decks_owner_select"
  on sourcebase.decks for select
  using (owner_user_id = auth.uid());

-- Users can see marketplace decks
drop policy if exists "sourcebase_decks_marketplace_select" on sourcebase.decks;
create policy "sourcebase_decks_marketplace_select"
  on sourcebase.decks for select
  using (visibility = 'marketplace' and status = 'published');

-- Users can see decks they have entitlement to
drop policy if exists "sourcebase_decks_entitled_select" on sourcebase.decks;
create policy "sourcebase_decks_entitled_select"
  on sourcebase.decks for select
  using (
    exists (
      select 1 from sourcebase.entitlements
      where entitlements.user_id = auth.uid()
        and entitlements.deck_id = decks.id
        and entitlements.status = 'active'
    )
  );

-- Users can insert their own decks
drop policy if exists "sourcebase_decks_owner_insert" on sourcebase.decks;
create policy "sourcebase_decks_owner_insert"
  on sourcebase.decks for insert
  with check (owner_user_id = auth.uid());

-- Users can update their own decks
drop policy if exists "sourcebase_decks_owner_update" on sourcebase.decks;
create policy "sourcebase_decks_owner_update"
  on sourcebase.decks for update
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

-- Users can delete their own decks
drop policy if exists "sourcebase_decks_owner_delete" on sourcebase.decks;
create policy "sourcebase_decks_owner_delete"
  on sourcebase.decks for delete
  using (owner_user_id = auth.uid());

-- ============================================================================
-- CARDS POLICIES
-- ============================================================================

-- Users can see cards from their own decks
drop policy if exists "sourcebase_cards_owner_select" on sourcebase.cards;
create policy "sourcebase_cards_owner_select"
  on sourcebase.cards for select
  using (
    exists (
      select 1 from sourcebase.decks
      where decks.id = cards.deck_id
        and decks.owner_user_id = auth.uid()
    )
  );

-- Users can see cards from marketplace decks (preview)
drop policy if exists "sourcebase_cards_marketplace_select" on sourcebase.cards;
create policy "sourcebase_cards_marketplace_select"
  on sourcebase.cards for select
  using (
    exists (
      select 1 from sourcebase.decks
      where decks.id = cards.deck_id
        and decks.visibility = 'marketplace'
        and decks.status = 'published'
    )
  );

-- Users can see cards from decks they have entitlement to
drop policy if exists "sourcebase_cards_entitled_select" on sourcebase.cards;
create policy "sourcebase_cards_entitled_select"
  on sourcebase.cards for select
  using (
    exists (
      select 1 from sourcebase.entitlements
      where entitlements.user_id = auth.uid()
        and entitlements.deck_id = cards.deck_id
        and entitlements.status = 'active'
    )
  );

-- Users can insert cards into their own decks
drop policy if exists "sourcebase_cards_owner_insert" on sourcebase.cards;
create policy "sourcebase_cards_owner_insert"
  on sourcebase.cards for insert
  with check (
    exists (
      select 1 from sourcebase.decks
      where decks.id = cards.deck_id
        and decks.owner_user_id = auth.uid()
    )
  );

-- Users can update cards in their own decks
drop policy if exists "sourcebase_cards_owner_update" on sourcebase.cards;
create policy "sourcebase_cards_owner_update"
  on sourcebase.cards for update
  using (
    exists (
      select 1 from sourcebase.decks
      where decks.id = cards.deck_id
        and decks.owner_user_id = auth.uid()
    )
  );

-- Users can delete cards from their own decks
drop policy if exists "sourcebase_cards_owner_delete" on sourcebase.cards;
create policy "sourcebase_cards_owner_delete"
  on sourcebase.cards for delete
  using (
    exists (
      select 1 from sourcebase.decks
      where decks.id = cards.deck_id
        and decks.owner_user_id = auth.uid()
    )
  );

-- ============================================================================
-- GENERATED_JOBS POLICIES
-- ============================================================================

drop policy if exists "sourcebase_generated_jobs_owner_all" on sourcebase.generated_jobs;
create policy "sourcebase_generated_jobs_owner_all"
  on sourcebase.generated_jobs for all
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

-- ============================================================================
-- PRODUCTS POLICIES
-- ============================================================================

-- Everyone can see published products
drop policy if exists "sourcebase_products_public_select" on sourcebase.products;
create policy "sourcebase_products_public_select"
  on sourcebase.products for select
  using (status = 'published');

-- Only admins can insert/update/delete products (handled via Edge Function with service role)

-- ============================================================================
-- PRODUCT_DECKS POLICIES
-- ============================================================================

-- Everyone can see product-deck associations for published products
drop policy if exists "sourcebase_product_decks_public_select" on sourcebase.product_decks;
create policy "sourcebase_product_decks_public_select"
  on sourcebase.product_decks for select
  using (
    exists (
      select 1 from sourcebase.products
      where products.id = product_decks.product_id
        and products.status = 'published'
    )
  );

-- ============================================================================
-- PURCHASES POLICIES
-- ============================================================================

-- Users can see their own purchases
drop policy if exists "sourcebase_purchases_owner_select" on sourcebase.purchases;
create policy "sourcebase_purchases_owner_select"
  on sourcebase.purchases for select
  using (user_id = auth.uid());

-- Purchases are created via Edge Function (service role)

-- ============================================================================
-- ENTITLEMENTS POLICIES
-- ============================================================================

-- Users can see their own entitlements
drop policy if exists "sourcebase_entitlements_owner_select" on sourcebase.entitlements;
create policy "sourcebase_entitlements_owner_select"
  on sourcebase.entitlements for select
  using (user_id = auth.uid());

-- Entitlements are created via Edge Function (service role)

-- ============================================================================
-- STUDY_SESSIONS POLICIES
-- ============================================================================

drop policy if exists "sourcebase_study_sessions_owner_all" on sourcebase.study_sessions;
create policy "sourcebase_study_sessions_owner_all"
  on sourcebase.study_sessions for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================================
-- STUDY_PROGRESS POLICIES
-- ============================================================================

drop policy if exists "sourcebase_study_progress_owner_all" on sourcebase.study_progress;
create policy "sourcebase_study_progress_owner_all"
  on sourcebase.study_progress for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================================
-- APP_MEMBERSHIPS POLICIES
-- ============================================================================

-- Users can see their own memberships
drop policy if exists "sourcebase_app_memberships_owner_select" on sourcebase.app_memberships;
create policy "sourcebase_app_memberships_owner_select"
  on sourcebase.app_memberships for select
  using (user_id = auth.uid());

-- Memberships are managed via Edge Function (service role)

-- ============================================================================
-- PART 12: HELPER FUNCTIONS
-- ============================================================================

-- Function to check if user has admin role in SourceBase
create or replace function sourcebase.is_admin(check_user_id uuid default auth.uid())
returns boolean as $$
begin
  return exists (
    select 1 from sourcebase.app_memberships
    where user_id = check_user_id
      and app_code = 'sourcebase'
      and role in ('admin', 'owner')
      and status = 'active'
  );
end;
$$ language plpgsql security definer;

-- Function to check if user has entitlement to a deck
create or replace function sourcebase.has_deck_entitlement(check_user_id uuid, check_deck_id uuid)
returns boolean as $$
begin
  return exists (
    select 1 from sourcebase.entitlements
    where user_id = check_user_id
      and deck_id = check_deck_id
      and status = 'active'
      and (starts_at is null or starts_at <= now())
      and (ends_at is null or ends_at > now())
  );
end;
$$ language plpgsql security definer;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Log migration completion
insert into sourcebase.audit_logs (action, entity_type, metadata)
values (
  'schema_migration_completed',
  'migration',
  jsonb_build_object(
    'migration_file', '20260516_complete_sourcebase_schema.sql',
    'tables_created', array[
      'sources', 'decks', 'cards', 'generated_jobs',
      'products', 'product_decks', 'purchases', 'entitlements',
      'study_sessions', 'study_progress', 'app_memberships'
    ],
    'timestamp', now()
  )
);
