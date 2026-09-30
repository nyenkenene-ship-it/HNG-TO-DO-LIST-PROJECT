create extension if not exists pgcrypto;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  color text not null default '#4f46e5',
  created_at timestamptz not null default now(),
  unique(user_id,name)
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  title text not null check (char_length(trim(title)) between 1 and 200),
  notes text not null default '',
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  due_date date,
  due_time time,
  completed boolean not null default false,
  completed_at timestamptz,
  recurring text not null default 'none' check (recurring in ('none','daily','weekly','monthly')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete cascade,
  remind_at timestamptz not null,
  channel text not null default 'in_app' check(channel in ('in_app','email')),
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  timezone text not null default 'Africa/Lagos',
  week_starts_monday boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tasks_user_id_idx on public.tasks(user_id);
create index if not exists tasks_due_date_idx on public.tasks(user_id,due_date);
create index if not exists reminders_user_time_idx on public.reminders(user_id,remind_at);

alter table public.projects enable row level security;
alter table public.tasks enable row level security;
alter table public.reminders enable row level security;
alter table public.user_preferences enable row level security;

drop policy if exists "project owner select" on public.projects;
create policy "project owner select" on public.projects for select using(auth.uid()=user_id);
drop policy if exists "project owner insert" on public.projects;
create policy "project owner insert" on public.projects for insert with check(auth.uid()=user_id);
drop policy if exists "project owner update" on public.projects;
create policy "project owner update" on public.projects for update using(auth.uid()=user_id) with check(auth.uid()=user_id);
drop policy if exists "project owner delete" on public.projects;
create policy "project owner delete" on public.projects for delete using(auth.uid()=user_id);

drop policy if exists "task owner select" on public.tasks;
create policy "task owner select" on public.tasks for select using(auth.uid()=user_id);
drop policy if exists "task owner insert" on public.tasks;
create policy "task owner insert" on public.tasks for insert with check(auth.uid()=user_id);
drop policy if exists "task owner update" on public.tasks;
create policy "task owner update" on public.tasks for update using(auth.uid()=user_id) with check(auth.uid()=user_id);
drop policy if exists "task owner delete" on public.tasks;
create policy "task owner delete" on public.tasks for delete using(auth.uid()=user_id);

drop policy if exists "reminder owner all" on public.reminders;
create policy "reminder owner all" on public.reminders for all using(auth.uid()=user_id) with check(auth.uid()=user_id);

drop policy if exists "preferences owner all" on public.user_preferences;
create policy "preferences owner all" on public.user_preferences for all using(auth.uid()=user_id) with check(auth.uid()=user_id);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists tasks_updated_at on public.tasks;
create trigger tasks_updated_at before update on public.tasks for each row execute function public.set_updated_at();
drop trigger if exists preferences_updated_at on public.user_preferences;
create trigger preferences_updated_at before update on public.user_preferences for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.user_preferences(user_id) values(new.id) on conflict do nothing;
  insert into public.projects(user_id,name) values(new.id,'Personal') on conflict do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
