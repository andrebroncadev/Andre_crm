-- Importa os registros em staging como contatos em revisão, sem marcar negócios como fechados.
create or replace function public.crm_bulk_import_staging(p_batch_id uuid default null)
returns jsonb language plpgsql security invoker
set search_path=pg_catalog,public,crm_private
as $$
declare v_workspace uuid; r record; v_phone text; v_dup uuid; v_contact uuid; v_imported integer:=0; v_duplicates integer:=0; v_name text; v_notes text;
begin
 select m.workspace_id into v_workspace from public.crm_workspace_members m where m.user_id=auth.uid() order by m.created_at limit 1;
 if v_workspace is null or auth.uid() is null then raise exception 'Autenticação necessária'; end if;
 for r in select * from public.crm_import_records where workspace_id=v_workspace and import_status='pending' and (p_batch_id is null or batch_id=p_batch_id) order by created_at loop
  v_phone:=regexp_replace(coalesce(r.phone,''),'[^0-9]','','g'); v_dup:=null;
  if length(v_phone)>=8 then
   select c.id into v_dup from public.crm_contacts c where c.workspace_id=v_workspace and regexp_replace(coalesce(c.phone,''),'[^0-9]','','g')=v_phone limit 1;
  end if;
  if v_dup is not null then
   update public.crm_import_records set import_status='duplicate',matched_contact_id=v_dup where id=r.id and workspace_id=v_workspace;
   v_duplicates:=v_duplicates+1; continue;
  end if;
  v_name:=nullif(btrim(coalesce(r.suggested_name,'')),'');
  if v_name is null or v_name='Contato sem nome' or v_name=v_phone then v_name:=case when v_phone<>'' then 'Contato '||v_phone else 'Contato a identificar' end; end if;
  v_notes:='Importado para revisão; não classificar como lead confirmado apenas por palavras-chave. '||coalesce(r.summary,'');
  if r.source_ref is not null then v_notes:=v_notes||' Origem: '||r.source_ref; end if;
  insert into public.crm_contacts(workspace_id,name,phone,roles,source,rank,status,data_confidence,notes,external_ref,created_by)
  values(v_workspace,v_name,nullif(r.phone,''),array['À qualificar',coalesce(r.category,'WhatsApp')],'WhatsApp','C','review','review',v_notes,r.source_ref,auth.uid()) returning id into v_contact;
  update public.crm_import_records set import_status='imported',matched_contact_id=v_contact where id=r.id and workspace_id=v_workspace;
  insert into public.crm_audit_log(workspace_id,table_name,record_id,action,after_data,reason,actor_id)
  values(v_workspace,'crm_contacts',v_contact::text,'import',jsonb_build_object('id',v_contact,'name',v_name,'phone',r.phone),'Importação WhatsApp em revisão',auth.uid());
  v_imported:=v_imported+1;
 end loop;
 update public.crm_import_batches b set imported_records=(select count(*) from public.crm_import_records i where i.batch_id=b.id and i.import_status='imported'),
 status=case when exists(select 1 from public.crm_import_records i where i.batch_id=b.id and i.import_status='pending') then 'review' else 'imported' end,
 completed_at=case when not exists(select 1 from public.crm_import_records i where i.batch_id=b.id and i.import_status='pending') then now() else null end
 where b.workspace_id=v_workspace and (p_batch_id is null or b.id=p_batch_id);
 return jsonb_build_object('imported',v_imported,'duplicates',v_duplicates);
end; $$;
revoke all on function public.crm_bulk_import_staging(uuid) from public;
revoke execute on function public.crm_bulk_import_staging(uuid) from anon;
grant execute on function public.crm_bulk_import_staging(uuid) to authenticated;
