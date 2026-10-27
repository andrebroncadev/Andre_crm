-- Bootstrap a workspace using the authenticated user's own permissions.
create or replace function crm_private.is_workspace_creator(p_workspace_id uuid)
returns boolean language sql stable security definer
set search_path=pg_catalog,public,crm_private
as $$ select exists(select 1 from public.crm_workspaces w where w.id=p_workspace_id and w.created_by=auth.uid()); $$;
revoke all on function crm_private.is_workspace_creator(uuid) from public;
grant execute on function crm_private.is_workspace_creator(uuid) to authenticated;
create policy crm_workspace_insert_self on public.crm_workspaces for insert to authenticated with check(created_by=auth.uid());
create policy crm_members_self_bootstrap on public.crm_workspace_members for insert to authenticated with check(
 user_id=auth.uid() and crm_private.is_workspace_creator(workspace_id) and not crm_private.is_workspace_member(workspace_id)
);
create or replace function public.crm_ensure_workspace()
returns uuid language plpgsql security invoker
set search_path=pg_catalog,public,crm_private
as $$
declare v_user uuid; v_workspace uuid;
begin
 v_user:=auth.uid();
 if v_user is null then raise exception 'Autenticação necessária'; end if;
 select m.workspace_id into v_workspace from public.crm_workspace_members m where m.user_id=v_user order by m.created_at limit 1;
 if v_workspace is null then
  insert into public.crm_workspaces(name,created_by) values('CRM André',v_user) returning id into v_workspace;
  insert into public.crm_workspace_members(workspace_id,user_id,role) values(v_workspace,v_user,'admin');
 end if;
 return v_workspace;
end; $$;
revoke all on function public.crm_ensure_workspace() from public;
revoke execute on function public.crm_ensure_workspace() from anon;
grant execute on function public.crm_ensure_workspace() to authenticated;
