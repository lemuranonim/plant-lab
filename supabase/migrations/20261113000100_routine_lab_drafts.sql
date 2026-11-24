-- Routine Lab capture, phase 1. Drafts only: no canonical request, dispatch,
-- result, decision, lot or assignment is created or changed by these APIs.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create table plantlab_lab.routine_drafts (
 id uuid primary key,
 lab_site_id uuid not null references plantlab_master.sites(id),
 lot_id uuid not null references plantlab_core.lots(id),
 method_id uuid not null references plantlab_lab.methods(id),
 created_by uuid not null references plantlab_platform.identities(id),
 revision int not null check(revision>0),
 status text not null default 'DRAFT' check(status='DRAFT'),
 content jsonb not null check(jsonb_typeof(content)='object'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index routine_drafts_site_time_idx on plantlab_lab.routine_drafts(lab_site_id,updated_at desc,id);
create table plantlab_lab.routine_draft_revisions (
 draft_id uuid not null references plantlab_lab.routine_drafts(id),
 revision int not null,
 actor_id uuid not null references plantlab_platform.identities(id),
 action_id uuid not null,
 payload jsonb not null,
 response jsonb not null,
 recorded_at timestamptz not null default now(),
 primary key(draft_id,revision),unique(actor_id,action_id)
);
alter table plantlab_lab.routine_drafts enable row level security;
alter table plantlab_lab.routine_draft_revisions enable row level security;
revoke all on plantlab_lab.routine_drafts,plantlab_lab.routine_draft_revisions from PUBLIC,anon,authenticated,service_role;
create trigger routine_revisions_immutable before update or delete on plantlab_lab.routine_draft_revisions
 for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_lab.can_use_routine_lab(p_site uuid,p_write boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select from plantlab_master.sites s
 where s.id=p_site and s.site_type='LAB' and s.is_active and
 (plantlab_platform.has_exact_scoped_role('LAB','LAB_ANALYST',s.id,s.company_id)
 or (not p_write and plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',s.id,s.company_id))));
$$;

create function plantlab_api.get_routine_lab_options(p_lab_site_id uuid default null,p_search text default '',p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare selected uuid:=p_lab_site_id; result jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if coalesce(length(p_search),0)>100 or p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid search or offset' using errcode='22023'; end if;
 if selected is null then select id into selected from plantlab_master.sites
 where plantlab_lab.can_use_routine_lab(id) order by site_code,id limit 1; end if;
 if selected is null or not plantlab_lab.can_use_routine_lab(selected) then raise exception 'Assigned Lab role required' using errcode='42501'; end if;
 with eligible as materialized (
 select l.id,l.lot_code,l.stage_code,l.crop_category_code,p.name as hybrid,s.site_name as plant_site
 from plantlab_core.lots l join plantlab_master.sites s on s.id=l.plant_site_id and s.site_type='PLANT' and s.is_active and s.company_id=l.company_id
 join plantlab_master.products p on p.id=l.product_id
 join plantlab_master.sites lab on lab.id=selected and lab.company_id=l.company_id
 where coalesce(btrim(p_search),'')='' or position(lower(btrim(p_search)) in lower(l.lot_code||' '||coalesce(p.name,'')))>0
 ), page as(select * from eligible order by lot_code,id limit 50 offset p_offset)
 select jsonb_build_object('version',1,'draft_only',true,'selected_lab_site_id',selected,
 'can_write',plantlab_lab.can_use_routine_lab(selected,true),
 'lab_sites',(select jsonb_agg(jsonb_build_object('id',id,'site_name',site_name) order by site_name,id) from plantlab_master.sites where plantlab_lab.can_use_routine_lab(id)),
 'methods',(select jsonb_agg(jsonb_build_object('method_code',m.method_code,'method_name',m.method_name,'replicate_count',c.replicate_count,'seeds_per_replicate',c.seeds_per_replicate,'observation_kind',c.observation_kind) order by m.method_code)
 from plantlab_lab.confirmed_method_contracts c join plantlab_lab.methods m on m.id=c.method_id where m.is_active and
 (m.method_code='SAND_25C' or exists(select from plantlab_lab.vigour_calculation_contracts v where v.method_id=m.id))),
 'lots',coalesce((select jsonb_agg(to_jsonb(page) order by lot_code,id) from page),'[]'::jsonb),
 'total',(select count(*) from eligible),'offset',p_offset,'limit',50,'has_more',(select count(*)>p_offset+50 from eligible)) into result;
 return result;
end;
$$;

create function plantlab_lab.normalize_routine_draft(p_method text,p_content jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare n int; radicle boolean:=p_method='RET_16C_72H'; row jsonb; rows jsonb:='[]'; normalized jsonb; k text; value jsonb; idx int:=0; expected int; total int; t timestamptz; received timestamptz; started timestamptz; final_at timestamptz;
begin
 if jsonb_typeof(p_content) is distinct from 'object' or octet_length(p_content::text)>24000 then raise exception 'Draft object required' using errcode='22023'; end if;
 if exists(select from jsonb_object_keys(p_content) x where x not in ('sample_reference','received_at','started_at','final_at','note','replicate_count','observations')) then raise exception 'Unknown draft field' using errcode='22023'; end if;
 if jsonb_typeof(p_content->'replicate_count') is distinct from 'number' or (p_content->>'replicate_count') !~ '^[24]$' then raise exception 'Replicate count2 or4 required' using errcode='22023'; end if;
 n:=(p_content->>'replicate_count')::int;
 if (radicle and n<>4) or (p_method<>'SAND_25C' and not radicle and n<>2) then raise exception 'Replicates outside confirmed method' using errcode='22023'; end if;
 foreach k in array array['sample_reference','note'] loop
 if p_content->k is not null and p_content->k<>'null'::jsonb and jsonb_typeof(p_content->k)<>'string' then raise exception 'Text expected' using errcode='22023'; end if;
 if length(coalesce(p_content->>k,''))>(case k when 'note' then 1000 else 120 end) then raise exception 'Text too long' using errcode='22023'; end if;
 end loop;
 foreach k in array array['received_at','started_at','final_at'] loop
 if p_content->k is not null and p_content->k<>'null'::jsonb and jsonb_typeof(p_content->k)<>'string' then raise exception 'Actual timestamp expected' using errcode='22023'; end if;
 if nullif(p_content->>k,'') is not null then
 t:=(p_content->>k)::timestamptz;
 if not isfinite(t) or t>now() then raise exception 'Actual times cannot be future or infinite' using errcode='22023'; end if;
 if k='received_at' then received:=t; elsif k='started_at' then started:=t; else final_at:=t; end if;
 end if;
 end loop;
 if started<received or final_at<started or final_at<received then raise exception 'Actual dates out of order' using errcode='22023'; end if;
 expected:=case when radicle then n else n*2 end;
 if jsonb_typeof(p_content->'observations') is distinct from 'array' or jsonb_array_length(p_content->'observations')<>expected then raise exception 'Use one row per subreplicate, or4 RET rows' using errcode='22023'; end if;
 for row in select x from jsonb_array_elements(p_content->'observations') x loop
 idx:=idx+1; normalized:='{}'; total:=0;
 if jsonb_typeof(row) is distinct from 'object' then raise exception 'Observation object expected' using errcode='22023'; end if;
 if exists(select from jsonb_object_keys(row) x where x<>all(case when radicle then array['radicle_at_least_2mm'] else array['first_normal','final_normal','abnormal','fresh','hard','dead'] end)) then raise exception 'Unexpected observation category' using errcode='22023'; end if;
 foreach k in array (case when radicle then array['radicle_at_least_2mm'] else array['first_normal','final_normal','abnormal','fresh','hard','dead'] end) loop
 value:=coalesce(row->k,'null'::jsonb);
 if value<>'null'::jsonb then
 if jsonb_typeof(value)<>'number' or value::text !~ '^[0-9]{1,3}$' or value::text::int>(case when radicle then 100 else 50 end) then raise exception 'Integer count outside sample size' using errcode='22023'; end if;
 if k<>'first_normal' then total:=total+value::text::int; end if;
 end if;
 normalized:=normalized||jsonb_build_object(k,value);
 end loop;
 if total>(case when radicle then 100 else 50 end) then raise exception 'Final categories exceed sample size' using errcode='22023'; end if;
 rows:=rows||jsonb_build_array(normalized);
 end loop;
 return jsonb_build_object('sample_reference',nullif(btrim(p_content->>'sample_reference'),''),'received_at',received,'started_at',started,'final_at',final_at,
 'note',nullif(btrim(p_content->>'note'),''),'replicate_count',n,'observations',rows);
end;
$$;

create function plantlab_api.save_routine_lab_draft(p_draft_id uuid,p_expected_revision int,p_action_id uuid,p_lab_site_id uuid,p_lot_id uuid,p_method_code text,p_content jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare draft plantlab_lab.routine_drafts; replay plantlab_lab.routine_draft_revisions; method uuid; payload jsonb; response jsonb; v_content jsonb;
begin
 if not plantlab_lab.can_use_routine_lab(p_lab_site_id,true) then raise exception 'Assigned Lab Analyst required' using errcode='42501'; end if;
 if p_draft_id is null or p_action_id is null or p_expected_revision is null or p_expected_revision<0 then raise exception 'Draft/action ID and revision required' using errcode='22023'; end if;
 if not exists(select from plantlab_core.lots l join plantlab_master.sites s on s.id=l.plant_site_id and s.site_type='PLANT' and s.is_active and s.company_id=l.company_id join plantlab_master.sites lab on lab.id=p_lab_site_id and lab.company_id=l.company_id where l.id=p_lot_id) then raise exception 'Lot outside Lab company' using errcode='42501'; end if;
 select m.id into method from plantlab_lab.confirmed_method_contracts c join plantlab_lab.methods m on m.id=c.method_id where m.method_code=p_method_code and m.is_active and (m.method_code='SAND_25C' or exists(select from plantlab_lab.vigour_calculation_contracts v where v.method_id=m.id));
 if method is null then raise exception 'Confirmed method required' using errcode='22023'; end if;
 v_content:=plantlab_lab.normalize_routine_draft(p_method_code,p_content);
 payload:=jsonb_build_object('draft_id',p_draft_id,'expected_revision',p_expected_revision,'lab_site_id',p_lab_site_id,'lot_id',p_lot_id,'method_code',p_method_code,'content',v_content);
 perform pg_advisory_xact_lock(hashtextextended('ROUTINE_ACTION:'||auth.uid()||':'||p_action_id,0));
 select * into replay from plantlab_lab.routine_draft_revisions where actor_id=auth.uid() and action_id=p_action_id;
 if found then
 if replay.payload is distinct from payload then raise exception 'Action ID reused with different details' using errcode='23505'; end if;
 return replay.response;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('ROUTINE_DRAFT:'||p_draft_id,0));
 select * into draft from plantlab_lab.routine_drafts where id=p_draft_id for update;
 if found then
 if draft.created_by<>auth.uid() or draft.lab_site_id<>p_lab_site_id then raise exception 'Only original analyst in assigned Lab may edit' using errcode='42501'; end if;
 if draft.revision<>p_expected_revision then raise exception 'Draft changed; reload before saving' using errcode='40001'; end if;
 if draft.lot_id<>p_lot_id or draft.method_id<>method then raise exception 'Saved lot/method locked; create a separate draft' using errcode='22023'; end if;
 update plantlab_lab.routine_drafts set content=v_content,revision=revision+1,updated_at=now() where id=p_draft_id returning * into draft;
 else
 if p_expected_revision<>0 then raise exception 'Draft not found; reload' using errcode='40001'; end if;
 insert into plantlab_lab.routine_drafts(id,lab_site_id,lot_id,method_id,created_by,revision,content) values(p_draft_id,p_lab_site_id,p_lot_id,method,auth.uid(),1,v_content) returning * into draft;
 end if;
 response:=jsonb_build_object('draft_id',draft.id,'revision',draft.revision,'status','DRAFT');
 insert into plantlab_lab.routine_draft_revisions values(draft.id,draft.revision,auth.uid(),p_action_id,payload,response,now());
 return response;
end;
$$;

create function plantlab_api.list_routine_lab_drafts(p_lab_site_id uuid,p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not plantlab_lab.can_use_routine_lab(p_lab_site_id) then raise exception 'Assigned Lab role required' using errcode='42501'; end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid offset' using errcode='22023'; end if;
 with records as materialized(select d.id,d.revision,d.status,d.lot_id,l.lot_code,l.stage_code,p.name as hybrid,m.method_code,m.method_name,d.content,d.created_by,d.updated_at,(d.created_by=auth.uid() and plantlab_lab.can_use_routine_lab(d.lab_site_id,true)) as can_edit
 from plantlab_lab.routine_drafts d join plantlab_core.lots l on l.id=d.lot_id join plantlab_master.products p on p.id=l.product_id join plantlab_lab.methods m on m.id=d.method_id where d.lab_site_id=p_lab_site_id),
 page as(select * from records order by updated_at desc,id limit 50 offset p_offset)
 select jsonb_build_object('drafts',coalesce((select jsonb_agg(to_jsonb(page) order by updated_at desc,id) from page),'[]'::jsonb),'total',(select count(*) from records),'offset',p_offset,'has_more',(select count(*)>p_offset+50 from records)) into result;
 return result;
end;
$$;

revoke all on function plantlab_lab.can_use_routine_lab(uuid,boolean),plantlab_lab.normalize_routine_draft(text,jsonb) from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_api.get_routine_lab_options(uuid,text,int),plantlab_api.save_routine_lab_draft(uuid,int,uuid,uuid,uuid,text,jsonb),plantlab_api.list_routine_lab_drafts(uuid,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_routine_lab_options(uuid,text,int),plantlab_api.save_routine_lab_draft(uuid,int,uuid,uuid,uuid,text,jsonb),plantlab_api.list_routine_lab_drafts(uuid,int) to authenticated;
comment on table plantlab_lab.routine_drafts is 'Routine Lab draft capture only. Unknowns remain null. Not canonical observations, historical import, QA approval, specification PASS or lot release. No Plant request/dispatch created.';
notify pgrst,'reload schema';
commit;
