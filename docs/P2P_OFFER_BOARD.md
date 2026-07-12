# P2P Offer Board — Supabase setup

The public P2P offer board stores signed offers in a Supabase (PostgREST)
table. It needs no paid Apple Developer Program and no iCloud account —
just a free Supabase project. The board is **discovery only**: every offer
is re-validated on-chain (signature, nonce, balances, allowance, live
protocol fee) by `P2PTradeService.validateOffer` before a buyer can accept
it, so a fake or stale listing can never take anyone's funds.

## One-time setup (~5 minutes)

1. Create a free project at https://supabase.com (any region).
2. In the project, open **SQL Editor** and run the script below.
3. In **Project Settings → API**, copy:
   - **Project URL** (e.g. `https://abcdefgh.supabase.co`)
   - **anon / public API key**
4. Paste both into `Wpayin_Wallet/Core/Config/Config.swift`:
   ```swift
   static let p2pBoardURL = "https://abcdefgh.supabase.co"
   static let p2pBoardAnonKey = "eyJ..."
   ```
   The board (Buy-tab marketplace, Public/Private offer toggle, publish
   button) turns on automatically once both values are set.

## SQL

```sql
-- Signed P2P offers published by sellers.
create table public.p2p_offers (
  id           text primary key,
  payload      text not null check (char_length(payload) between 1 and 4000),
  chain_id     bigint not null,
  sell_symbol  text not null check (char_length(sell_symbol) <= 20),
  buy_symbol   text not null check (char_length(buy_symbol) <= 20),
  sell_amount  double precision not null,
  buy_amount   double precision not null,
  expiry       timestamptz not null,
  signer       text not null check (char_length(signer) = 42),
  created_at   timestamptz not null default now()
);

alter table public.p2p_offers enable row level security;

-- Anyone may browse live offers…
create policy "anon read live offers"
  on public.p2p_offers for select
  using (expiry > now());

-- …publish offers with a sane expiry (app caps at 72 h)…
create policy "anon publish"
  on public.p2p_offers for insert
  with check (expiry > now() and expiry < now() + interval '8 days');

-- …and remove listings (used after cancel/fill; unauthenticated by design —
-- see "Trust model" below).
create policy "anon delete"
  on public.p2p_offers for delete
  using (true);

-- Abuse reports from the app (write-only for the anon key).
create table public.p2p_reports (
  id          bigint generated always as identity primary key,
  listing_id  text not null,
  signer      text,
  reason      text,
  created_at  timestamptz not null default now()
);

alter table public.p2p_reports enable row level security;

create policy "anon report"
  on public.p2p_reports for insert
  with check (true);
```

### Optional: auto-purge expired rows

Database → Extensions → enable `pg_cron`, then:

```sql
select cron.schedule(
  'purge-expired-p2p-offers',
  '30 * * * *',
  $$ delete from public.p2p_offers where expiry < now() - interval '1 day' $$
);
```

(Not required — expired rows are already invisible to the app thanks to the
select policy; this just keeps the table small.)

## Trust model & known limits

- The anon key ships inside the app, so writes are effectively public.
  Funds are never at risk (on-chain validation is the source of truth), but:
  - anyone could insert junk rows — the app drops rows whose payload does
    not decode into a validly signed offer;
  - anyone could delete listings (grief). Sellers can simply re-publish
    (`Publish to Offer Board` on the share screen).
- If griefing ever becomes a real problem, move deletes behind a Supabase
  Edge Function that verifies an EIP-191 signature from the offer's signer
  wallet, and change the delete policy to `using (false)`.
- The old CloudKit implementation was replaced on 2026-07-11 because free
  personal Apple teams cannot sign the iCloud entitlement at all.
