# mideas_touch_creator

A new Flutter project.

## Auth / Supabase setup

Customer and Creator users are **separate**, even with the same email and different passwords.

Supabase Auth emails must be unique, so Creator accounts:

- login/register with the **real email** in the UI (e.g. `siri@easycloud.in`)
- Auth stores `creator-siri@easycloud.in` and maps it in `creator_accounts`
- keep a separate password from the customer app

1. In Supabase → **Authentication → Providers → Email**:
   - Enable Email
   - **Disable Confirm email**

2. For **web login**, in Supabase → **Authentication → URL Configuration**:
   - Site URL: `https://midas-touch-creator.web.app`
   - Redirect URLs add:
     - `https://midas-touch-creator.web.app/**`
     - `http://localhost:*/**`
     - `http://127.0.0.1:*/**`

3. Run this SQL in the Supabase SQL Editor:

```sql
-- Design ownership (published_by stores the creator's real email)
alter table templates
  add column if not exists published_by text;

alter table saved_templates
  add column if not exists published_by text;

-- If published_by was previously uuid, convert it to email text:
alter table templates drop constraint if exists templates_published_by_fkey;
alter table saved_templates drop constraint if exists saved_templates_published_by_fkey;

-- templates: uuid -> text, then map auth user id -> email
alter table templates
  alter column published_by type text using published_by::text;

update templates t
set published_by = c.email
from public.creator_accounts c
where t.published_by = c.auth_user_id::text;

-- saved_templates: same conversion
alter table saved_templates
  alter column published_by type text using published_by::text;

update saved_templates t
set published_by = c.email
from public.creator_accounts c
where t.published_by = c.auth_user_id::text;

create index if not exists templates_published_by_idx
  on templates (published_by);

create index if not exists saved_templates_published_by_idx
  on saved_templates (published_by);

-- Same column names (created_at / updated_at), Indian format: yyyy-mm-dd HH-mm-ss
drop trigger if exists templates_sync_ist_timestamps on templates;
drop function if exists public.sync_templates_ist_timestamps();
alter table templates drop column if exists created_at_ist;
alter table templates drop column if exists updated_at_ist;

alter table templates
  alter column created_at drop default,
  alter column updated_at drop default;

alter table templates
  alter column created_at type text
  using to_char(created_at at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24-MI-SS'),
  alter column updated_at type text
  using to_char(coalesce(updated_at, created_at) at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24-MI-SS');

alter table templates
  alter column created_at set default to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS'),
  alter column updated_at set default to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS');

create or replace function public.set_templates_ist_timestamps()
returns trigger
language plpgsql
as $$
declare
  stamp text := to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM-DD HH24-MI-SS');
begin
  if tg_op = 'INSERT' then
    if new.created_at is null or new.created_at = '' then
      new.created_at := stamp;
    end if;
  end if;
  new.updated_at := stamp;
  return new;
end;
$$;

drop trigger if exists templates_set_ist_timestamps on templates;
create trigger templates_set_ist_timestamps
  before insert or update
  on templates
  for each row
  execute function public.set_templates_ist_timestamps();

-- Separate creator login mapping (real email -> private auth email)
create table if not exists public.creator_accounts (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  auth_email text not null unique,
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists creator_accounts_email_idx
  on public.creator_accounts (lower(email));

alter table public.creator_accounts enable row level security;

drop policy if exists "creator_accounts_insert_own" on public.creator_accounts;
create policy "creator_accounts_insert_own"
  on public.creator_accounts
  for insert
  to authenticated
  with check (auth.uid() = auth_user_id);

drop policy if exists "creator_accounts_select_own" on public.creator_accounts;
create policy "creator_accounts_select_own"
  on public.creator_accounts
  for select
  to authenticated
  using (auth.uid() = auth_user_id);

create or replace function public.creator_auth_email(p_email text)
returns text
language sql
security definer
set search_path = public
as $$
  select auth_email
  from public.creator_accounts
  where lower(email) = lower(trim(p_email))
  limit 1;
$$;

grant execute on function public.creator_auth_email(text) to anon, authenticated;
```

My designs shows only rows where `published_by` is the logged-in creator (published also limited to the last 1 day).

## Getting Started

# web deployment 
flutter build web --release --base-href /
firebase deploy --only hosting --project midas-touch-creator

# web url 

# https://midas-touch-creator.web.app


This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
