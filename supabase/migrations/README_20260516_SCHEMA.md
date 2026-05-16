# SourceBase Schema Completion - Migration 20260516

## Overview

This migration completes the SourceBase database schema by adding all core tables required for:
- Content generation and storage
- Flashcard management
- Marketplace functionality
- Payment and entitlements
- Study progress tracking
- User role management

## Critical Rules Followed

✅ **Qlinik Protection**: No Qlinik tables were modified
✅ **Schema Isolation**: All tables are in `sourcebase` schema
✅ **RLS Enabled**: Row Level Security is active on all tables
✅ **Idempotent**: Uses `IF NOT EXISTS` for safe re-runs
✅ **AGENTS.md Compliant**: Follows all ecosystem rules

## Tables Created

### 1. `sourcebase.sources`
**Purpose**: Store user-uploaded content for AI generation

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| owner_user_id | uuid | References auth.users |
| source_type | text | Type: manual_text, pdf, docx, url, qlinik_context, admin_seed |
| title | text | Optional title |
| original_filename | text | Original file name |
| storage_path | text | GCS/Storage path |
| text_content | text | Extracted text content |
| metadata | jsonb | Additional metadata |
| status | text | Status: active, archived, deleted, processing, failed |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**RLS**: Users can only access their own sources

### 2. `sourcebase.decks`
**Purpose**: Flashcard collections (private or marketplace)

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| owner_user_id | uuid | References auth.users (nullable for admin decks) |
| visibility | text | Visibility: private, unlisted, marketplace, admin |
| title | text | Deck title |
| description | text | Deck description |
| language | text | Content language |
| subject | text | Subject area |
| level | text | Difficulty level |
| source_id | uuid | References sourcebase.sources |
| is_marketplace_item | boolean | Is this a marketplace product? |
| status | text | Status: active, draft, published, archived, deleted |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**RLS**: 
- Users see their own decks
- Everyone sees published marketplace decks
- Users see decks they have entitlement to

### 3. `sourcebase.cards`
**Purpose**: Individual flashcards within decks

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| deck_id | uuid | References sourcebase.decks |
| front | text | Card front (question/prompt) |
| back | text | Card back (answer) |
| explanation | text | Optional explanation |
| tags | text[] | Array of tags |
| difficulty | text | Difficulty: easy, medium, hard |
| sort_order | integer | Display order |
| metadata | jsonb | Additional metadata |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**RLS**: 
- Users see cards from their own decks
- Users see cards from marketplace decks (preview)
- Users see cards from entitled decks

### 4. `sourcebase.generated_jobs`
**Purpose**: Track AI content generation jobs

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| owner_user_id | uuid | References auth.users |
| source_id | uuid | References sourcebase.sources |
| deck_id | uuid | References sourcebase.decks |
| job_type | text | Type: flashcards, summary, quiz, notes, outline, questions |
| status | text | Status: queued, processing, completed, failed, cancelled |
| model | text | AI model used |
| input_tokens | integer | Token count input |
| output_tokens | integer | Token count output |
| cost_estimate | numeric | Estimated cost |
| error_message | text | Error details if failed |
| metadata | jsonb | Additional metadata |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**RLS**: Users can only access their own jobs

### 5. `sourcebase.products`
**Purpose**: Marketplace products for sale

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| slug | text | Unique URL slug |
| title | text | Product title |
| description | text | Product description |
| price_cents | integer | Price in cents (must be >= 0) |
| currency | text | Currency code (default: TRY) |
| status | text | Status: draft, published, archived, deleted |
| metadata | jsonb | Additional metadata |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**RLS**: Everyone can see published products

### 6. `sourcebase.product_decks`
**Purpose**: Link products to their included decks

| Column | Type | Description |
|--------|------|-------------|
| product_id | uuid | References sourcebase.products |
| deck_id | uuid | References sourcebase.decks |
| created_at | timestamptz | Creation timestamp |

**Primary Key**: (product_id, deck_id)
**RLS**: Everyone can see associations for published products

### 7. `sourcebase.purchases`
**Purpose**: Track user purchases

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | References auth.users |
| product_id | uuid | References sourcebase.products |
| provider | text | Provider: stripe, iyzico, manual, admin_grant |
| provider_payment_id | text | External payment ID |
| amount_cents | integer | Amount paid in cents |
| currency | text | Currency code |
| status | text | Status: pending, completed, failed, refunded, cancelled |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**RLS**: Users can only see their own purchases

### 8. `sourcebase.entitlements`
**Purpose**: Grant access to premium content

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | References auth.users |
| product_id | uuid | References sourcebase.products |
| deck_id | uuid | References sourcebase.decks |
| source_purchase_id | uuid | References sourcebase.purchases |
| status | text | Status: active, expired, revoked, suspended |
| starts_at | timestamptz | Entitlement start time |
| ends_at | timestamptz | Entitlement end time |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**RLS**: Users can only see their own entitlements

### 9. `sourcebase.study_sessions`
**Purpose**: Track study sessions

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | References auth.users |
| deck_id | uuid | References sourcebase.decks |
| started_at | timestamptz | Session start time |
| ended_at | timestamptz | Session end time |
| metadata | jsonb | Session metadata |

**RLS**: Users can only access their own sessions

### 10. `sourcebase.study_progress`
**Purpose**: Track individual card review progress

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | References auth.users |
| card_id | uuid | References sourcebase.cards |
| deck_id | uuid | References sourcebase.decks |
| ease_score | numeric | Spaced repetition ease factor |
| review_count | integer | Number of reviews |
| last_reviewed_at | timestamptz | Last review time |
| next_review_at | timestamptz | Next scheduled review |
| status | text | Status: new, learning, reviewing, mastered, suspended |
| metadata | jsonb | Progress metadata |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**Unique Constraint**: (user_id, card_id)
**RLS**: Users can only access their own progress

### 11. `sourcebase.app_memberships`
**Purpose**: Manage user roles and permissions

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | References auth.users |
| app_code | text | App: sourcebase, qlinik |
| role | text | Role: user, premium, admin, owner |
| status | text | Status: active, suspended, cancelled |
| created_at | timestamptz | Creation timestamp |
| updated_at | timestamptz | Last update timestamp |

**Unique Constraint**: (user_id, app_code)
**RLS**: Users can only see their own memberships

## Indexes Created

### Performance Indexes
- **sources**: owner_user_id, (source_type, status)
- **decks**: owner_user_id, (visibility, status), is_marketplace_item, source_id
- **cards**: deck_id, (deck_id, sort_order), tags (GIN)
- **generated_jobs**: owner_user_id, status, source_id, deck_id
- **products**: slug, status
- **purchases**: user_id, product_id, (provider, provider_payment_id)
- **entitlements**: user_id, product_id, deck_id, (user_id, deck_id), status
- **study_sessions**: user_id, deck_id, (user_id, deck_id)
- **study_progress**: user_id, card_id, deck_id, next_review_at
- **app_memberships**: user_id, (app_code, role)

## Triggers Created

All tables with `updated_at` column have automatic update triggers:
- `sourcebase.sources`
- `sourcebase.decks`
- `sourcebase.cards`
- `sourcebase.generated_jobs`
- `sourcebase.products`
- `sourcebase.purchases`
- `sourcebase.entitlements`
- `sourcebase.study_progress`
- `sourcebase.app_memberships`

## Helper Functions

### `sourcebase.is_admin(check_user_id uuid)`
Returns `boolean` - checks if user has admin role in SourceBase

### `sourcebase.has_deck_entitlement(check_user_id uuid, check_deck_id uuid)`
Returns `boolean` - checks if user has active entitlement to a deck

## Security Model

### Owner-Based Access
- Users can only access their own sources, jobs, purchases, sessions, and progress
- Users can manage their own decks and cards

### Marketplace Access
- Published marketplace decks are visible to everyone
- Card details require entitlement for premium content

### Entitlement-Based Access
- Purchases create entitlements
- Entitlements grant access to premium decks and cards
- Time-based entitlements supported (starts_at, ends_at)

### Admin Access
- Admin operations handled via Edge Function with service_role key
- Products, entitlements, and memberships managed server-side

## Migration Safety

✅ **Idempotent**: Can be run multiple times safely
✅ **No Data Loss**: Only creates new tables
✅ **No Qlinik Impact**: Completely isolated from Qlinik schema
✅ **Rollback Safe**: Can be rolled back without affecting existing data

## Testing Checklist

Before applying to production:

- [ ] Backup database
- [ ] Test on staging/local environment
- [ ] Verify RLS policies work correctly
- [ ] Test user can create deck
- [ ] Test user cannot see other user's private data
- [ ] Test marketplace visibility works
- [ ] Test entitlement access works
- [ ] Verify indexes are created
- [ ] Verify triggers work (updated_at auto-updates)
- [ ] Test helper functions
- [ ] Verify no Qlinik tables were affected

## Next Steps

After migration:

1. **Update Edge Function** - Add routes for new tables
2. **Create Admin Panel** - UI for managing products and entitlements
3. **Implement AI Generation** - Connect to OpenAI for content generation
4. **Add Payment Integration** - Stripe/Iyzico webhook handlers
5. **Build Study Interface** - Spaced repetition algorithm
6. **Add Qlinik Bridge** - Read-only view/RPC for Qlinik context

## Support

For issues or questions:
- Check AGENTS.md for ecosystem rules
- Review RLS policies if access issues occur
- Use audit_logs table for debugging
- Contact: SourceBase development team
