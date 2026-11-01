-- Fransızca Rehberim V5: Supabase SQL Editor üzerinde tek kez çalıştırın.
-- Bu script var olan tabloları silmez. Var olan şemaya uygulanırken politikalar için yeni proje önerilir.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'student' check (role in ('student','admin')),
  created_at timestamptz not null default now()
);

-- Rol yükseltme istemciye açık değildir; yalnızca kayıt tetikleyicisi öğrenci oluşturur.
create or replace function public.make_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id,display_name,role)
  values (new.id, left(coalesce(new.raw_user_meta_data->>'display_name',''),80),'student')
  on conflict(id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.make_profile();

-- Eski kayıtları da öğrenci olarak tamamla.
insert into public.profiles (id,display_name,role)
select id, left(coalesce(raw_user_meta_data->>'display_name',''),80), 'student'
from auth.users on conflict(id) do nothing;

create schema if not exists private;
create or replace function private.is_site_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles
   where id = (select auth.uid()) and role='admin');
$$;
revoke all on function private.is_site_admin() from public;
grant usage on schema private to authenticated;
grant execute on function private.is_site_admin() to authenticated;

create table if not exists public.student_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  level text not null default 'A1' check(level in ('A1','A2','B1','B2','C1','C2')),
  completed jsonb not null default '[]'::jsonb check(jsonb_typeof(completed)='array'),
  game_results jsonb not null default '{}'::jsonb check(jsonb_typeof(game_results)='object'),
  best int not null default 0 check(best between 0 and 100000),
  updated_at timestamptz not null default now()
);
create table if not exists public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  preferred_at timestamptz not null,
  lesson_type text not null check(length(lesson_type) between 2 and 80),
  note text not null default '' check(length(note)<=500),
  status text not null default 'pending' check(status in ('pending','confirmed','declined','cancelled')),
  created_at timestamptz not null default now()
);
create index if not exists booking_requests_user_date_idx on public.booking_requests(user_id,created_at desc);
create table if not exists public.catalog_items (
  id uuid primary key default gen_random_uuid(),
  name text not null check(length(name) between 1 and 120),
  description text not null default '',
  price numeric(12,2) not null check(price between 0 and 999999),
  kind text not null default 'kitap' check(kind in ('kitap','dijital','materyal')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.site_notices (
  id uuid primary key default gen_random_uuid(),
  title text not null check(length(title) between 1 and 90),
  body text not null check(length(body) between 1 and 500),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.student_progress enable row level security;
alter table public.booking_requests enable row level security;
alter table public.catalog_items enable row level security;
alter table public.site_notices enable row level security;

-- Güvenlik kuralı: kullanıcı kendi profilini yalnızca OKUYABİLİR; role değerini değiştiremez.
create policy profiles_self_or_admin_read on public.profiles for select to authenticated
using (id=(select auth.uid()) or (select private.is_site_admin()));

create policy progress_self_or_admin_read on public.student_progress for select to authenticated
using (user_id=(select auth.uid()) or (select private.is_site_admin()));
create policy progress_self_write on public.student_progress for insert to authenticated
with check (user_id=(select auth.uid()));
create policy progress_self_update on public.student_progress for update to authenticated
using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));

create policy booking_self_or_admin_read on public.booking_requests for select to authenticated
using (user_id=(select auth.uid()) or (select private.is_site_admin()));
create policy booking_student_create on public.booking_requests for insert to authenticated
with check (user_id=(select auth.uid()) and status='pending' and preferred_at>now());
create policy booking_admin_update on public.booking_requests for update to authenticated
using ((select private.is_site_admin())) with check ((select private.is_site_admin()));

create policy products_public_read on public.catalog_items for select to anon,authenticated
using (active or (select auth.uid()) is not null and (select private.is_site_admin()));
create policy products_admin_create on public.catalog_items for insert to authenticated
with check ((select private.is_site_admin()));
create policy products_admin_update on public.catalog_items for update to authenticated
using ((select private.is_site_admin())) with check ((select private.is_site_admin()));
create policy products_admin_delete on public.catalog_items for delete to authenticated
using ((select private.is_site_admin()));

create policy notices_public_read on public.site_notices for select to anon,authenticated
using (active or (select auth.uid()) is not null and (select private.is_site_admin()));
create policy notices_admin_create on public.site_notices for insert to authenticated
with check ((select private.is_site_admin()));
create policy notices_admin_update on public.site_notices for update to authenticated
using ((select private.is_site_admin())) with check ((select private.is_site_admin()));
create policy notices_admin_delete on public.site_notices for delete to authenticated
using ((select private.is_site_admin()));

-- Yetkiler: public API için sadece açıkça belirtilen izinler.
revoke all on public.profiles, public.student_progress, public.booking_requests, public.catalog_items, public.site_notices from anon, authenticated;
grant select on public.catalog_items,public.site_notices to anon;
grant select on public.profiles,public.student_progress,public.booking_requests,public.catalog_items,public.site_notices to authenticated;
grant insert,update on public.student_progress,public.booking_requests,public.catalog_items,public.site_notices to authenticated;
grant delete on public.catalog_items,public.site_notices to authenticated;

-- İLK ADMIN: Kayıt olduktan sonra, SQL Editor'da aşağıdaki örneği KENDİ e-postanla çalıştır:
-- update public.profiles set role='admin'
-- where id=(select id from auth.users where email='SENIN_EPOSTAN@example.com');
-- Bu güncellemeyi tarayıcıdan, config.js dosyasından veya öğrenci hesabından yapmayın.
