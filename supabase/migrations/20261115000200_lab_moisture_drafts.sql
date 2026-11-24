-- Lab-owned MC capture only. No Plant measurement, request, canonical result,
-- pass/fail, QA decision, lot release or account is created by these APIs.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';
create table plantlab_lab.moisture_drafts (
 id uuid primary key,lab_site_id uuid not null references plantlab_master.sites(id),
 lot_id uuid not null references plantlab_core.lots(id),created_by uuid not null references plantlab_platform.identities(id),
 revision int not null check(revision>0),content jsonb not null check(jsonb_typeof(content)='object'),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create index moisture_drafts_site_time_idx on plantlab_lab.moisture_drafts(lab_site_id,updated_at desc,id);
create table plantlab_lab.moisture_draft_revisions (
 draft_id uuid not null references plantlab_lab.moisture_drafts(id),revision int not null,
 actor_id uuid not null references plantlab_platform.identities(id),action_id uuid not null,
 payload jsonb not null,response jsonb not null,recorded_at timestamptz not null default now(),
 primary key(draft_id,revision),unique(actor_id,action_id)
);
alter table plantlab_lab.moisture_drafts enable row level security;
alter table plantlab_lab.moisture_draft_revisions enable row level security;
revoke all on plantlab_lab.moisture_drafts,plantlab_lab.moisture_draft_revisions from PUBLIC,anon,authenticated,service_role;
create trigger moisture_revisions_immutable before update or delete on plantlab_lab.moisture_draft_revisions for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_lab.normalize_moisture_draft(p_content jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare result jsonb:='{"version":1}';k text;v jsonb;rows jsonb:='[]';t timestamptz;received timestamptz;measured timestamptz;
begin
 if jsonb_typeof(p_content) is distinct from 'object' or octet_length(p_content::text)>8000 or p_content->'version' is distinct from '1'::jsonb then raise exception 'MC draft version1 required' using errcode='22023';end if;
 if exists(select from jsonb_object_keys(p_content) x where x not in('version','sample_reference','sample_type','received_at','measured_at','instrument','method','analyst_name','note','readings')) then raise exception 'Unknown MC field' using errcode='22023';end if;
 foreach k in array array['sample_reference','sample_type','instrument','method','analyst_name','note'] loop
  v:=coalesce(p_content->k,'null'::jsonb);
  if v<>'null'::jsonb and (jsonb_typeof(v)<>'string' or length(p_content->>k)>case when k='note' then 1000 else 120 end) then raise exception 'Invalid MC text' using errcode='22023';end if;
  result:=result||jsonb_build_object(k,nullif(btrim(p_content->>k),''));
 end loop;
 foreach k in array array['received_at','measured_at'] loop
  v:=coalesce(p_content->k,'null'::jsonb);t:=null;
  if v<>'null'::jsonb then
   if jsonb_typeof(v)<>'string' then raise exception 'Actual MC time required' using errcode='22023';end if;
   t:=(p_content->>k)::timestamptz;
   if not isfinite(t) or t>now() then raise exception 'MC time cannot be future/infinite' using errcode='22023';end if;
  end if;
  if k='received_at' then received:=t;else measured:=t;end if;
  result:=result||jsonb_build_object(k,t);
 end loop;
 if measured<received then raise exception 'Measurement before sample available' using errcode='22023';end if;
 if jsonb_typeof(p_content->'readings') is distinct from 'array' or jsonb_array_length(p_content->'readings')<>3 then raise exception 'Exactly3 MC reading slots required' using errcode='22023';end if;
 for v in select value from jsonb_array_elements(p_content->'readings') loop
  if v<>'null'::jsonb and (jsonb_typeof(v)<>'number' or (v::text)::numeric<0 or (v::text)::numeric>100) then raise exception 'MC percentages0to100; null means unknown' using errcode='22023';end if;
  rows:=rows||jsonb_build_array(v);
 end loop;
 return result||jsonb_build_object('readings',rows);
end;$$;

create function plantlab_lab.moisture_draft_json(p_id uuid)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',d.id,'lab_site_id',d.lab_site_id,'lot_id',d.lot_id,'lot_code',l.lot_code,'stage_code',l.stage_code,
  'hybrid',p.name,'lab_name',s.site_name,'created_by',d.created_by,'revision',d.revision,'status','DRAFT','content',d.content,'updated_at',d.updated_at,
  'can_edit',d.created_by=auth.uid() and plantlab_lab.can_use_routine_lab(d.lab_site_id,true),
  'entered_count',(select count(*) from jsonb_array_elements(d.content->'readings') v where v<>'null'::jsonb),
  'mean_percent',case when not exists(select from jsonb_array_elements(d.content->'readings') v where v='null'::jsonb)
    then (select avg((v::text)::numeric) from jsonb_array_elements(d.content->'readings') v) else null end,
  'authorizes_lot_release',false,'qa_enabled',false)
 from plantlab_lab.moisture_drafts d join plantlab_core.lots l on l.id=d.lot_id
 join plantlab_master.products p on p.id=l.product_id join plantlab_master.sites s on s.id=d.lab_site_id where d.id=p_id;
$$;

create function plantlab_api.save_lab_moisture_draft(p_draft_id uuid,p_expected_revision int,p_action_id uuid,p_lab_site_id uuid,p_lot_id uuid,p_content jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d plantlab_lab.moisture_drafts;r plantlab_lab.moisture_draft_revisions;normalized jsonb;payload jsonb;response jsonb;
begin
 if not plantlab_lab.can_use_routine_lab(p_lab_site_id,true) then raise exception 'Assigned Lab Analyst required' using errcode='42501';end if;
 if p_draft_id is null or p_action_id is null or p_expected_revision is null or p_expected_revision<0 then raise exception 'ID/revision required' using errcode='22023';end if;
 if not exists(select from plantlab_core.lots l join plantlab_master.sites s on s.id=l.plant_site_id and s.is_active and s.site_type='PLANT' and s.company_id=l.company_id join plantlab_master.sites lab on lab.id=p_lab_site_id and lab.company_id=l.company_id where l.id=p_lot_id) then raise exception 'Lot outside Lab company' using errcode='42501';end if;
 normalized:=plantlab_lab.normalize_moisture_draft(p_content);
 payload:=jsonb_build_object('id',p_draft_id,'expected_revision',p_expected_revision,'lab_site_id',p_lab_site_id,'lot_id',p_lot_id,'content',normalized);
 perform pg_advisory_xact_lock(hashtextextended('MC_ACTION:'||auth.uid()||':'||p_action_id,0));
 select * into r from plantlab_lab.moisture_draft_revisions where actor_id=auth.uid() and action_id=p_action_id;
 if found then
  if r.payload is distinct from payload then raise exception 'MC action replay changed' using errcode='23505';end if;
  return r.response;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('MC_DRAFT:'||p_draft_id,0));
 select * into d from plantlab_lab.moisture_drafts where id=p_draft_id for update;
 if found then
  if d.created_by<>auth.uid() or d.lab_site_id<>p_lab_site_id then raise exception 'Only original Lab Analyst may edit' using errcode='42501';end if;
  if d.revision<>p_expected_revision then raise exception 'MC draft changed; reload' using errcode='40001';end if;
  if d.lot_id<>p_lot_id then raise exception 'Saved lot locked' using errcode='22023';end if;
  update plantlab_lab.moisture_drafts set content=normalized,revision=revision+1,updated_at=now() where id=p_draft_id returning * into d;
 else
  if p_expected_revision<>0 then raise exception 'MC draft not found' using errcode='40001';end if;
  insert into plantlab_lab.moisture_drafts(id,lab_site_id,lot_id,created_by,revision,content) values(p_draft_id,p_lab_site_id,p_lot_id,auth.uid(),1,normalized) returning * into d;
 end if;
 response:=jsonb_build_object('draft_id',d.id,'revision',d.revision,'status','DRAFT');
 insert into plantlab_lab.moisture_draft_revisions values(d.id,d.revision,auth.uid(),p_action_id,payload,response,now());
 return response;
end;$$;

create function plantlab_api.get_lab_moisture_draft(p_draft_id uuid,p_expected_revision int default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d plantlab_lab.moisture_drafts;
begin
 select * into d from plantlab_lab.moisture_drafts where id=p_draft_id;
 if not found or not plantlab_lab.can_use_routine_lab(d.lab_site_id) or not exists(select from plantlab_core.lots l join plantlab_master.sites lab on lab.id=d.lab_site_id and lab.company_id=l.company_id where l.id=d.lot_id) then raise exception 'Assigned Lab scope required' using errcode='42501';end if;
 if p_expected_revision is not null and d.revision<>p_expected_revision then raise exception 'Reload MC revision' using errcode='40001';end if;
 return plantlab_lab.moisture_draft_json(d.id);
end;$$;

create function plantlab_api.list_lab_moisture_drafts(p_lab_site_id uuid,p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not plantlab_lab.can_use_routine_lab(p_lab_site_id) then raise exception 'Assigned Lab role required' using errcode='42501';end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid offset' using errcode='22023';end if;
 with eligible as materialized(select d.* from plantlab_lab.moisture_drafts d join plantlab_core.lots l on l.id=d.lot_id join plantlab_master.sites lab on lab.id=d.lab_site_id and lab.company_id=l.company_id where d.lab_site_id=p_lab_site_id),
 page as(select * from eligible order by updated_at desc,id limit 50 offset p_offset)
 select jsonb_build_object('drafts',coalesce((select jsonb_agg(plantlab_lab.moisture_draft_json(page.id) order by updated_at desc,id) from page),'[]'::jsonb),'total',(select count(*) from eligible),'offset',p_offset,'has_more',(select count(*)>p_offset+50 from eligible)) into result;
 return result;
end;$$;
create function plantlab_api.list_mc_sample_references(p_lab_site_id uuid,p_lot_id uuid,p_search text default '',p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 -- Invoke the established scoped validator; do not merge already-paginated lists.
 perform plantlab_api.list_routine_sample_references(p_lab_site_id,p_lot_id,p_search,0);
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid offset' using errcode='22023';end if;
 with candidates as (
  select coalesce(nullif(btrim(s.metadata->>'sample_reference'),''),s.sample_code) reference,s.sample_code,'RECEIVED'::text source_kind,sr.received_at recorded_at,0 priority
  from plantlab_core.samples s join plantlab_lab.request_samples rs on rs.sample_id=s.id
  join plantlab_lab.requests q on q.id=rs.request_id and q.lot_id=s.lot_id and q.target_lab_site_id=p_lab_site_id
  join plantlab_lab.sample_receipts sr on sr.request_sample_id=rs.id and sr.decision='ACCEPT' and sr.status='ACCEPTED' where s.lot_id=p_lot_id
  union all select nullif(btrim(d.content->>'sample_reference'),''),null::text,'DRAFT',d.updated_at,1 from plantlab_lab.routine_drafts d
   where d.lab_site_id=p_lab_site_id and d.lot_id=p_lot_id and not exists(select from plantlab_lab.routine_submissions s where s.draft_id=d.id)
  union all select nullif(btrim(d.content->>'sample_reference'),''),null::text,'DRAFT',d.updated_at,1 from plantlab_lab.moisture_drafts d where d.lab_site_id=p_lab_site_id and d.lot_id=p_lot_id
 ), refs as materialized(select distinct on(reference) reference,sample_code,source_kind,recorded_at from candidates where reference is not null and length(reference)<=120 order by reference,priority,recorded_at desc,sample_code nulls last),
 matched as materialized(select * from refs where coalesce(btrim(p_search),'')='' or position(lower(btrim(p_search)) in lower(reference||' '||coalesce(sample_code,'')))>0),
 page as(select * from matched order by reference collate "C" limit 50 offset p_offset)
 select jsonb_build_object('references',coalesce((select jsonb_agg(to_jsonb(page) order by reference collate "C") from page),'[]'::jsonb),'total',(select count(*) from matched),'offset',p_offset,'has_more',(select count(*)>p_offset+50 from matched)) into result;
 return result;
end;$$;
revoke all on function plantlab_api.list_mc_sample_references(uuid,uuid,text,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.list_mc_sample_references(uuid,uuid,text,int) to authenticated;
revoke all on function plantlab_lab.normalize_moisture_draft(jsonb),plantlab_lab.moisture_draft_json(uuid),plantlab_api.save_lab_moisture_draft(uuid,int,uuid,uuid,uuid,jsonb),plantlab_api.get_lab_moisture_draft(uuid,int),plantlab_api.list_lab_moisture_drafts(uuid,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.save_lab_moisture_draft(uuid,int,uuid,uuid,uuid,jsonb),plantlab_api.get_lab_moisture_draft(uuid,int),plantlab_api.list_lab_moisture_drafts(uuid,int) to authenticated;
comment on table plantlab_lab.moisture_drafts is 'Lab MC drafts. Three actual percentage readings per KC Lab; mean available only when all3 known. No Plant MC copy, no assumed method, tolerance/specification or QA approval.';
notify pgrst,'reload schema';
commit;
