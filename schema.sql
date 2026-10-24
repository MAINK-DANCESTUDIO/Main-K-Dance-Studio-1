-- K-Dance Studio · esquema inicial PostgreSQL/Supabase
-- Ejecutar en Supabase > SQL Editor. Revisar las políticas antes de datos reales.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'dancer' check (role in ('admin','coach','dancer')),
  phone text,
  avatar_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.current_role()
returns text language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=auth.uid() and active=true limit 1 $$;
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select coalesce(public.current_role()='admin',false) $$;

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  style text,
  coach_id uuid references public.profiles(id) on delete set null,
  coach_name text,
  weekday text not null check (weekday in ('Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo')),
  start_time time not null,
  end_time time not null,
  room text,
  capacity integer check (capacity is null or capacity > 0),
  published boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.enrollments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'active' check (status in ('active','paused','cancelled')),
  created_at timestamptz not null default now(),
  unique(class_id,user_id)
);
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null default 'Aviso de K-Dance',
  body text not null,
  author_id uuid references public.profiles(id) on delete set null,
  published boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  description text not null,
  amount integer not null check (amount > 0),
  currency text not null default 'CLP' check(currency='CLP'),
  status text not null default 'pending' check(status in ('pending','paid','failed','cancelled','refunded')),
  provider text not null default 'manual' check(provider in ('manual','webpay')),
  provider_order text unique,
  provider_token text,
  authorization_code text,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price integer not null check(price>=0),
  stock integer not null default 0 check(stock>=0),
  image_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'pending' check(status in ('pending','paid','fulfilled','cancelled','refunded')),
  total integer not null check(total>0),
  payment_id uuid references public.payments(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity integer not null check(quantity>0),
  unit_price integer not null check(unit_price>=0)
);
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  event_date timestamptz not null,
  venue text,
  ticket_price integer not null check(ticket_price>=0),
  capacity integer check(capacity is null or capacity>0),
  published boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.tickets (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  payment_id uuid references public.payments(id) on delete set null,
  ticket_code text not null unique default upper(encode(gen_random_bytes(8),'hex')),
  status text not null default 'pending' check(status in ('pending','paid','used','cancelled','refunded')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.enrollments enable row level security;
alter table public.announcements enable row level security;
alter table public.payments enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.events enable row level security;
alter table public.tickets enable row level security;

-- Profiles: cada usuario solo lee su perfil; administración puede leer/gestionar todos.
create policy "profile self or admin read" on public.profiles for select to authenticated using (id=auth.uid() or public.is_admin());
create policy "admin manages profiles" on public.profiles for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- Classes: usuarios autenticados ven clases publicadas; coach ve sus clases; admin gestiona.
create policy "published classes visible" on public.classes for select to authenticated using (published=true or coach_id=auth.uid() or public.is_admin());
create policy "admin manages classes" on public.classes for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "coach manages own classes" on public.classes for update to authenticated using (coach_id=auth.uid() and public.current_role()='coach') with check (coach_id=auth.uid() and public.current_role()='coach');
-- Enrollment records visible to the dancer, assigned coach or admin.
create policy "enrollment relevant read" on public.enrollments for select to authenticated using (user_id=auth.uid() or public.is_admin() or exists(select 1 from public.classes c where c.id=class_id and c.coach_id=auth.uid()));
create policy "admin manages enrollments" on public.enrollments for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- Announcements are visible when published; coaches/admin may post, only admin may delete/manage all.
create policy "published announcements visible" on public.announcements for select to authenticated using (published=true or public.is_admin());
create policy "coach or admin posts announcements" on public.announcements for insert to authenticated with check (author_id=auth.uid() and public.current_role() in ('coach','admin'));
create policy "author or admin edits announcement" on public.announcements for update to authenticated using (author_id=auth.uid() and public.current_role() in ('coach','admin') or public.is_admin()) with check (author_id=auth.uid() and public.current_role() in ('coach','admin') or public.is_admin());
create policy "admin deletes announcements" on public.announcements for delete to authenticated using (public.is_admin());
-- Payment rows are server-created by Edge Functions; users can only read their own.
create policy "own or admin payments read" on public.payments for select to authenticated using (user_id=auth.uid() or public.is_admin());
create policy "admin manages payments" on public.payments for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "active products visible" on public.products for select to authenticated using (active=true or public.is_admin());
create policy "admin manages products" on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "own or admin orders read" on public.orders for select to authenticated using (user_id=auth.uid() or public.is_admin());
create policy "own or admin order items read" on public.order_items for select to authenticated using (public.is_admin() or exists(select 1 from public.orders o where o.id=order_id and o.user_id=auth.uid()));
create policy "published events visible" on public.events for select to authenticated using (published=true or public.is_admin());
create policy "admin manages events" on public.events for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "own or admin tickets read" on public.tickets for select to authenticated using (user_id=auth.uid() or public.is_admin());

-- No public sign-up: disable it in Authentication settings. Invite users from the admin Edge Function.
-- Create the first admin only after its auth user exists, by running this manually with that user's UUID:
-- update public.profiles set role='admin' where id='UUID-DEL-USUARIO';
