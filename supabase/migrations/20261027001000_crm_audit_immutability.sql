-- Keep updated_at reliable and make audit/history append-only.
create or replace function crm_private.touch_updated_at()
returns trigger language plpgsql
set search_path=pg_catalog,public,crm_private
as $$ begin new.updated_at:=now(); return new; end; $$;
revoke all on function crm_private.touch_updated_at() from public;
do $$ declare t text; begin
 foreach t in array array['crm_contacts','crm_properties','crm_availability','crm_deals','crm_tasks','crm_personal_notes','crm_settings'] loop
  execute format('drop trigger if exists %I on public.%I',t||'_touch_updated_at',t);
  execute format('create trigger %I before update on public.%I for each row execute function crm_private.touch_updated_at()',t||'_touch_updated_at',t);
 end loop;
end $$;
do $$ declare t text; begin
 foreach t in array array['crm_contacts','crm_properties','crm_availability','crm_deals','crm_tasks','crm_activities','crm_points','crm_goals','crm_settings','crm_import_batches','crm_import_records','crm_audit_log'] loop
  execute format('drop policy if exists %I on public.%I',t||'_delete',t);
  execute format('revoke delete on public.%I from authenticated',t);
 end loop;
end $$;
drop policy if exists crm_audit_log_update on public.crm_audit_log;
drop policy if exists crm_audit_log_delete on public.crm_audit_log;
revoke update,delete on public.crm_audit_log from authenticated;
grant select,insert on public.crm_audit_log to authenticated;
grant select,insert,update on public.crm_contacts,public.crm_properties,public.crm_availability,public.crm_deals,public.crm_tasks,public.crm_activities,public.crm_points,public.crm_goals,public.crm_settings,public.crm_import_batches,public.crm_import_records to authenticated;
grant select,insert,update,delete on public.crm_personal_notes to authenticated;
