-- SourceBase MedasiCoin micro-pricing ledger.
-- Non-destructive: creates a service-role managed transaction table only.

create table if not exists sourcebase.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid references sourcebase.generated_jobs(id) on delete set null,
  amount_mc numeric(12, 2) not null,
  amount_units integer not null,
  type text not null check (type in ('reserve', 'capture', 'refund', 'purchase', 'admin_adjustment')),
  reason text not null,
  balance_before numeric(12, 2) not null,
  balance_after numeric(12, 2) not null,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists sourcebase_wallet_transactions_user_created_idx
  on sourcebase.wallet_transactions(user_id, created_at desc);

create index if not exists sourcebase_wallet_transactions_job_idx
  on sourcebase.wallet_transactions(job_id);

alter table sourcebase.wallet_transactions enable row level security;

drop policy if exists "sourcebase_wallet_transactions_owner_select"
  on sourcebase.wallet_transactions;
create policy "sourcebase_wallet_transactions_owner_select"
  on sourcebase.wallet_transactions for select
  using (user_id = auth.uid());

grant select, insert on sourcebase.wallet_transactions
  to service_role;

grant select on sourcebase.wallet_transactions
  to authenticated;
