-- Test Script for Migration 20260516
-- This script validates the migration without applying it
-- Run this on a test database first

-- ============================================================================
-- PART 1: Pre-Migration Checks
-- ============================================================================

-- Check if sourcebase schema exists
select exists(
  select 1 from information_schema.schemata 
  where schema_name = 'sourcebase'
) as sourcebase_schema_exists;

-- Check existing sourcebase tables
select table_name 
from information_schema.tables 
where table_schema = 'sourcebase'
order by table_name;

-- ============================================================================
-- PART 2: Post-Migration Validation Queries
-- ============================================================================

-- After running the migration, execute these queries to validate:

-- 1. Verify all tables were created
select 
  table_name,
  (select count(*) from information_schema.columns where table_schema = 'sourcebase' and table_name = t.table_name) as column_count
from information_schema.tables t
where table_schema = 'sourcebase'
  and table_name in (
    'sources', 'decks', 'cards', 'generated_jobs',
    'products', 'product_decks', 'purchases', 'entitlements',
    'study_sessions', 'study_progress', 'app_memberships'
  )
order by table_name;

-- 2. Verify RLS is enabled on all tables
select 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
from pg_tables
where schemaname = 'sourcebase'
order by tablename;

-- 3. Verify indexes were created
select 
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'sourcebase'
  and indexname like 'sourcebase_%'
order by tablename, indexname;

-- 4. Verify triggers were created
select 
  trigger_schema,
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
from information_schema.triggers
where trigger_schema = 'sourcebase'
order by event_object_table, trigger_name;

-- 5. Verify CHECK constraints
select 
  tc.table_name,
  tc.constraint_name,
  cc.check_clause
from information_schema.table_constraints tc
join information_schema.check_constraints cc 
  on tc.constraint_name = cc.constraint_name
where tc.table_schema = 'sourcebase'
  and tc.constraint_type = 'CHECK'
order by tc.table_name, tc.constraint_name;

-- 6. Verify foreign keys
select 
  tc.table_name,
  kcu.column_name,
  ccu.table_name as foreign_table_name,
  ccu.column_name as foreign_column_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name = tc.constraint_name
where tc.table_schema = 'sourcebase'
  and tc.constraint_type = 'FOREIGN KEY'
order by tc.table_name, kcu.column_name;

-- 7. Verify RLS policies
select 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'sourcebase'
order by tablename, policyname;

-- 8. Verify helper functions exist
select 
  routine_schema,
  routine_name,
  routine_type,
  data_type as return_type
from information_schema.routines
where routine_schema = 'sourcebase'
  and routine_name in ('is_admin', 'has_deck_entitlement', 'update_updated_at_column')
order by routine_name;

-- ============================================================================
-- PART 3: Functional Tests
-- ============================================================================

-- Test 1: Create a test user membership (requires auth.uid() to work)
-- This would be run by an authenticated user
/*
insert into sourcebase.app_memberships (user_id, app_code, role, status)
values (auth.uid(), 'sourcebase', 'user', 'active')
returning *;
*/

-- Test 2: Create a test source
/*
insert into sourcebase.sources (owner_user_id, source_type, title, status)
values (auth.uid(), 'manual_text', 'Test Source', 'active')
returning *;
*/

-- Test 3: Create a test deck
/*
insert into sourcebase.decks (owner_user_id, visibility, title, status)
values (auth.uid(), 'private', 'Test Deck', 'active')
returning *;
*/

-- Test 4: Create a test card
/*
insert into sourcebase.cards (deck_id, front, back)
values (
  (select id from sourcebase.decks where owner_user_id = auth.uid() limit 1),
  'Test Question',
  'Test Answer'
)
returning *;
*/

-- Test 5: Verify updated_at trigger works
/*
update sourcebase.decks 
set title = 'Updated Test Deck'
where owner_user_id = auth.uid()
returning id, title, created_at, updated_at;
-- updated_at should be newer than created_at
*/

-- ============================================================================
-- PART 4: RLS Policy Tests
-- ============================================================================

-- Test 6: Verify user can only see their own data
/*
-- As user A, create a deck
insert into sourcebase.decks (owner_user_id, visibility, title, status)
values (auth.uid(), 'private', 'User A Private Deck', 'active');

-- As user B, try to see user A's private deck (should return 0 rows)
select * from sourcebase.decks where title = 'User A Private Deck';
*/

-- Test 7: Verify marketplace visibility
/*
-- As admin, create a marketplace deck
insert into sourcebase.decks (owner_user_id, visibility, title, status, is_marketplace_item)
values (auth.uid(), 'marketplace', 'Public Marketplace Deck', 'published', true);

-- As any user, should be able to see it
select * from sourcebase.decks where visibility = 'marketplace' and status = 'published';
*/

-- Test 8: Verify entitlement access
/*
-- Create entitlement for user
insert into sourcebase.entitlements (user_id, deck_id, status)
values (
  auth.uid(),
  (select id from sourcebase.decks where is_marketplace_item = true limit 1),
  'active'
);

-- User should now see cards from that deck
select c.* 
from sourcebase.cards c
join sourcebase.decks d on d.id = c.deck_id
where d.is_marketplace_item = true;
*/

-- ============================================================================
-- PART 5: Performance Tests
-- ============================================================================

-- Test 9: Verify indexes are being used
explain analyze
select * from sourcebase.decks 
where owner_user_id = auth.uid()
  and visibility = 'private'
  and status = 'active';
-- Should use sourcebase_decks_owner_idx or sourcebase_decks_visibility_status_idx

-- Test 10: Verify composite index usage
explain analyze
select * from sourcebase.cards
where deck_id = (select id from sourcebase.decks limit 1)
order by sort_order;
-- Should use sourcebase_cards_deck_sort_idx

-- ============================================================================
-- PART 6: Safety Note
-- ============================================================================

-- This validation file is intentionally non-destructive.
-- Do not add DROP/TRUNCATE/DELETE cleanup statements here; use disposable test
-- databases for destructive migration rehearsal.

-- ============================================================================
-- VALIDATION SUMMARY
-- ============================================================================

-- Run this query to get a summary of the migration status
select 
  'Tables Created' as check_type,
  count(*) as count
from information_schema.tables
where table_schema = 'sourcebase'
  and table_name in (
    'sources', 'decks', 'cards', 'generated_jobs',
    'products', 'product_decks', 'purchases', 'entitlements',
    'study_sessions', 'study_progress', 'app_memberships'
  )
union all
select 
  'RLS Enabled Tables',
  count(*)
from pg_tables
where schemaname = 'sourcebase'
  and rowsecurity = true
union all
select 
  'Indexes Created',
  count(*)
from pg_indexes
where schemaname = 'sourcebase'
  and indexname like 'sourcebase_%'
union all
select 
  'Triggers Created',
  count(*)
from information_schema.triggers
where trigger_schema = 'sourcebase'
union all
select 
  'RLS Policies Created',
  count(*)
from pg_policies
where schemaname = 'sourcebase'
union all
select 
  'Helper Functions Created',
  count(*)
from information_schema.routines
where routine_schema = 'sourcebase'
  and routine_name in ('is_admin', 'has_deck_entitlement', 'update_updated_at_column');
