-- One read-only, bounded snapshot of all matching logbook entries, not one UI page.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';
create function plantlab_api.get_lab_logbook_export(p_lab_site_id uuid default null,p_search text default '',p_from date default null,p_to date default null,
 p_date_basis text default 'RECORDED',p_origin text default 'ALL',p_method text default 'ALL',p_status text default 'ALL')
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare base jsonb;records jsonb;lab uuid;basis text;origin text;method text;state text;
begin
 -- Existing API owns authorization and filter validation. Both reads share this statement snapshot.
 base:=plantlab_api.get_lab_logbook(p_lab_site_id,p_search,p_from,p_to,p_date_basis,p_origin,p_method,p_status,0,1);
 if (base->>'total')::int>2000 then raise exception 'More than2000 matching entries; narrow date/search filters; no partial export' using errcode='54000';end if;
 lab:=(base->>'selected_lab_site_id')::uuid;basis:=base#>>'{filters,date_basis}';origin:=base#>>'{filters,origin}';method:=base#>>'{filters,method}';state:=base#>>'{filters,status}';
 with filtered as materialized(select e.* from plantlab_lab.logbook_entries(lab) e where
  (coalesce(btrim(p_search),'')='' or position(lower(btrim(p_search)) in lower(concat_ws(' ',e.lot_code,e.hybrid,e.sample_reference,e.request_code,e.run_code)))>0)
  and (origin='ALL' or (origin='PLANT' and e.entry_kind in('PLANT_RUN','PLANT_PENDING')) or (origin='ROUTINE' and e.entry_kind='ROUTINE') or (origin='MC' and e.entry_kind='MC_DRAFT'))
  and (method='ALL' or e.method_code=method) and (state='ALL' or e.status=state)
  and (p_from is null or ((case when basis='RECORDED' then e.recorded_at else e.observed_at end) at time zone 'Asia/Jakarta')::date>=p_from)
  and (p_to is null or ((case when basis='RECORDED' then e.recorded_at else e.observed_at end) at time zone 'Asia/Jakarta')::date<=p_to))
 select coalesce(jsonb_agg(to_jsonb(e) order by recorded_at desc,entry_kind,entry_id),'[]'::jsonb) into records from filtered e;
 if jsonb_array_length(records)<>(base->>'total')::int then raise exception 'Logbook source/filter changed; reload' using errcode='40001';end if;
 return base||jsonb_build_object('export_version',1,'entries',records,'offset',0,'limit',2000,'has_more',false,
  'lab_name',(select site_name from plantlab_master.sites where id=lab),'as_of',statement_timestamp());
end;
$$;
revoke all on function plantlab_api.get_lab_logbook_export(uuid,text,date,date,text,text,text,text) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_lab_logbook_export(uuid,text,date,date,text,text,text,text) to authenticated;
comment on function plantlab_api.get_lab_logbook_export(uuid,text,date,date,text,text,text,text) is 'Read-only complete filtered Lab logbook snapshot, up to2000 entries or explicit failure. Same authorization/filter semantics as existing logbook. No averaging, duplicate routine runs, import, Auth, role, QA, or lot-release writes.';
notify pgrst,'reload schema';
commit;
