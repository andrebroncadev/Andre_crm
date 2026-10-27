-- CRM André: schema inicial com RLS.
-- Apenas tabelas crm_*; não altera tabelas preexistentes do BancoImob, Maré ou Feedback Maker.
create schema if not exists crm_private;

create table public.crm_workspaces (
 id uuid primary key default gen_random_uuid(), name text not null default 'CRM André',
 created_by uuid not null references auth.users(id) on delete restrict, created_at timestamptz not null default now()
);
create table public.crm_workspace_members (
 workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'admin' check(role in ('admin','member','viewer')),
 created_at timestamptz not null default now(), primary key(workspace_id,user_id)
);

create or replace function crm_private.is_workspace_member(p_workspace_id uuid)
returns boolean language sql stable security definer
set search_path=pg_catalog,public,crm_private
as $$ select exists(select 1 from public.crm_workspace_members m where m.workspace_id=p_workspace_id and m.user_id=auth.uid()); $$;
revoke all on function crm_private.is_workspace_member(uuid) from public;
grant usage on schema crm_private to authenticated;
grant execute on function crm_private.is_workspace_member(uuid) to authenticated;

create or replace function crm_private.is_workspace_admin(p_workspace_id uuid)
returns boolean language sql stable security definer
set search_path=pg_catalog,public,crm_private
as $$ select exists(select 1 from public.crm_workspace_members m where m.workspace_id=p_workspace_id and m.user_id=auth.uid() and m.role='admin'); $$;
revoke all on function crm_private.is_workspace_admin(uuid) from public;
grant execute on function crm_private.is_workspace_admin(uuid) to authenticated;

create or replace function public.crm_ensure_workspace()
returns uuid language plpgsql security definer
set search_path=pg_catalog,public,crm_private
as $$
declare v_user uuid; v_workspace uuid;
begin
 v_user:=auth.uid();
 if v_user is null then raise exception 'Autenticação necessária'; end if;
 select workspace_id into v_workspace from public.crm_workspace_members where user_id=v_user order by created_at limit 1;
 if v_workspace is null then
  insert into public.crm_workspaces(name,created_by) values('CRM André',v_user) returning id into v_workspace;
  insert into public.crm_workspace_members(workspace_id,user_id,role) values(v_workspace,v_user,'admin');
 end if;
 return v_workspace;
end; $$;
revoke all on function public.crm_ensure_workspace() from public;
revoke execute on function public.crm_ensure_workspace() from anon;
grant execute on function public.crm_ensure_workspace() to authenticated;

create table public.crm_contacts (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 name text not null, phone text, email text, roles text[] not null default '{}', source text, location text,
 rank text not null default 'C' check(rank in ('A','B','C','D','E','F','O')), birthday date, notes text,
 status text not null default 'active' check(status in ('active','paused','archived','review')),
 data_confidence text not null default 'confirmed' check(data_confidence in ('confirmed','inferred','review')),
 external_ref text, created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.crm_properties (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 nickname text not null, property_type text, owner_contact_id uuid references public.crm_contacts(id) on delete set null,
 city text default 'São Sebastião', neighborhood text, address text, bedrooms integer, suites integer, capacity integer,
 beach_distance_m integer, beachfront boolean not null default false, pool boolean, barbecue boolean, beach_service boolean,
 air_conditioning text, photos jsonb not null default '[]'::jsonb, source_system text, external_url text, external_id text,
 commission_percent numeric(5,2), base_price numeric(12,2), cleaning_fee numeric(12,2),
 status text not null default 'review' check(status in ('active','inactive','review','archived')), notes text,
 last_availability_check timestamptz, data_confidence text not null default 'review' check(data_confidence in ('confirmed','inferred','review')),
 created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.crm_availability (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 property_id uuid not null references public.crm_properties(id) on delete cascade, start_date date not null, end_date date not null,
 availability_status text not null default 'unknown' check(availability_status in ('available','reserved','unavailable','pending','unknown')),
 price numeric(12,2), cleaning_fee numeric(12,2), other_fees numeric(12,2), source text, confirmed_by uuid references auth.users(id),
 confirmed_at timestamptz, conflict_notes jsonb not null default '[]'::jsonb, notes text, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), check(end_date>start_date)
);
create table public.crm_deals (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 title text not null, kind text not null check(kind in ('Venda','Locação de temporada','Locação tradicional','Captação de imóvel')),
 contact_id uuid references public.crm_contacts(id) on delete set null, property_id uuid references public.crm_properties(id) on delete set null,
 stage text not null default 'Novo lead', status text not null default 'open' check(status in ('open','won','lost','paused','archived')),
 value numeric(12,2), budget numeric(12,2), check_in date, check_out date, people integer, neighborhood text, bedrooms integer, suites integer,
 requirements jsonb not null default '{}'::jsonb, source text, priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 next_action text, next_date date, loss_reason text, notes text,
 data_confidence text not null default 'review' check(data_confidence in ('confirmed','inferred','review')),
 created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.crm_tasks (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 title text not null, contact_id uuid references public.crm_contacts(id) on delete set null, deal_id uuid references public.crm_deals(id) on delete set null,
 property_id uuid references public.crm_properties(id) on delete set null, kind text not null default 'Follow-up',
 due date, priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 done boolean not null default false, completed_at timestamptz, notes text, created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.crm_activities (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 contact_id uuid references public.crm_contacts(id) on delete set null, deal_id uuid references public.crm_deals(id) on delete set null,
 property_id uuid references public.crm_properties(id) on delete set null, type text not null, description text not null,
 occurred_at timestamptz not null default now(), result text, next_action text, next_date date,
 created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now()
);
create table public.crm_points (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 activity_id uuid references public.crm_activities(id) on delete set null, contact_id uuid references public.crm_contacts(id) on delete set null,
 deal_id uuid references public.crm_deals(id) on delete set null, date date not null default current_date, category text not null,
 point_type text not null default 'activity' check(point_type in ('activity','result','adjustment')), value numeric(10,2) not null,
 reason text not null, adjustment_reason text, created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now()
);
create table public.crm_personal_notes (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 owner_user_id uuid not null default auth.uid() references auth.users(id) on delete cascade, contact_id uuid references public.crm_contacts(id) on delete set null,
 note text not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.crm_goals (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 title text not null, metric text not null, target numeric(12,2) not null, period_start date not null, period_end date not null,
 active boolean not null default true, created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(),
 check(period_end>=period_start)
);
create table public.crm_settings (
 workspace_id uuid primary key references public.crm_workspaces(id) on delete cascade, point_rules jsonb not null default '{}'::jsonb,
 stale_after_days integer not null default 3, hot_opportunity_days integer not null default 2, timezone text not null default 'America/Sao_Paulo',
 preferences jsonb not null default '{}'::jsonb, updated_by uuid default auth.uid() references auth.users(id), updated_at timestamptz not null default now()
);
create table public.crm_import_batches (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 source text not null, status text not null default 'staging' check(status in ('staging','review','imported','cancelled')),
 total_records integer not null default 0, imported_records integer not null default 0, warnings jsonb not null default '[]'::jsonb,
 created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(), completed_at timestamptz
);
create table public.crm_import_records (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 batch_id uuid not null references public.crm_import_batches(id) on delete cascade, source_ref text, suggested_name text, phone text, category text, summary text,
 last_contact_at date, message_count integer, confidence text not null default 'review' check(confidence in ('confirmed','inferred','review')),
 import_status text not null default 'pending' check(import_status in ('pending','approved','imported','skipped','duplicate')),
 matched_contact_id uuid references public.crm_contacts(id) on delete set null, raw_metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table public.crm_audit_log (
 id bigint generated always as identity primary key, workspace_id uuid not null references public.crm_workspaces(id) on delete cascade,
 table_name text not null, record_id text not null, action text not null check(action in ('insert','update','archive','import','adjustment','login')),
 before_data jsonb, after_data jsonb, reason text, actor_id uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now()
);

create index crm_contacts_workspace_name_idx on public.crm_contacts(workspace_id,name);
create index crm_contacts_workspace_phone_idx on public.crm_contacts(workspace_id,phone);
create index crm_deals_workspace_stage_idx on public.crm_deals(workspace_id,status,stage);
create index crm_tasks_workspace_due_idx on public.crm_tasks(workspace_id,done,due);
create index crm_activities_workspace_time_idx on public.crm_activities(workspace_id,occurred_at desc);
create index crm_properties_workspace_neighborhood_idx on public.crm_properties(workspace_id,neighborhood);
create index crm_availability_property_dates_idx on public.crm_availability(property_id,start_date,end_date);
create index crm_import_records_workspace_status_idx on public.crm_import_records(workspace_id,import_status);

alter table public.crm_workspaces enable row level security;
alter table public.crm_workspace_members enable row level security;
alter table public.crm_contacts enable row level security;
alter table public.crm_properties enable row level security;
alter table public.crm_availability enable row level security;
alter table public.crm_deals enable row level security;
alter table public.crm_tasks enable row level security;
alter table public.crm_activities enable row level security;
alter table public.crm_points enable row level security;
alter table public.crm_personal_notes enable row level security;
alter table public.crm_goals enable row level security;
alter table public.crm_settings enable row level security;
alter table public.crm_import_batches enable row level security;
alter table public.crm_import_records enable row level security;
alter table public.crm_audit_log enable row level security;

create policy crm_workspace_select on public.crm_workspaces for select to authenticated using(crm_private.is_workspace_member(id));
create policy crm_workspace_update on public.crm_workspaces for update to authenticated using(crm_private.is_workspace_member(id)) with check(crm_private.is_workspace_member(id));
create policy crm_members_select on public.crm_workspace_members for select to authenticated using(crm_private.is_workspace_member(workspace_id));
create policy crm_members_admin_insert on public.crm_workspace_members for insert to authenticated with check(crm_private.is_workspace_admin(workspace_id));
create policy crm_members_admin_update on public.crm_workspace_members for update to authenticated using(crm_private.is_workspace_admin(workspace_id)) with check(crm_private.is_workspace_admin(workspace_id));

do $$ declare t text; begin
 foreach t in array array['crm_contacts','crm_properties','crm_availability','crm_deals','crm_tasks','crm_activities','crm_points','crm_goals','crm_settings','crm_import_batches','crm_import_records','crm_audit_log'] loop
  execute format('create policy %I on public.%I for select to authenticated using(crm_private.is_workspace_member(workspace_id))',t||'_select',t);
  execute format('create policy %I on public.%I for insert to authenticated with check(crm_private.is_workspace_member(workspace_id))',t||'_insert',t);
  execute format('create policy %I on public.%I for update to authenticated using(crm_private.is_workspace_member(workspace_id)) with check(crm_private.is_workspace_member(workspace_id))',t||'_update',t);
  execute format('create policy %I on public.%I for delete to authenticated using(crm_private.is_workspace_member(workspace_id))',t||'_delete',t);
 end loop;
end $$;
create policy crm_personal_notes_owner_select on public.crm_personal_notes for select to authenticated using(owner_user_id=auth.uid());
create policy crm_personal_notes_owner_insert on public.crm_personal_notes for insert to authenticated with check(owner_user_id=auth.uid() and crm_private.is_workspace_member(workspace_id));
create policy crm_personal_notes_owner_update on public.crm_personal_notes for update to authenticated using(owner_user_id=auth.uid()) with check(owner_user_id=auth.uid() and crm_private.is_workspace_member(workspace_id));
create policy crm_personal_notes_owner_delete on public.crm_personal_notes for delete to authenticated using(owner_user_id=auth.uid());

grant select,insert,update,delete on public.crm_workspace_members to authenticated;
grant select,update on public.crm_workspaces to authenticated;
grant select,insert,update,delete on public.crm_contacts,public.crm_properties,public.crm_availability,public.crm_deals,public.crm_tasks,public.crm_activities,public.crm_points,public.crm_personal_notes,public.crm_goals,public.crm_settings,public.crm_import_batches,public.crm_import_records,public.crm_audit_log to authenticated;
