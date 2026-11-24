-- Read-only operational logbook. No materialized totals, write commands,
-- source import, assignments, quality thresholds or lot release changes.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create function plantlab_lab.logbook_entries(p_lab_site_id uuid)
returns table(entry_kind text,entry_id uuid,request_code text,run_code text,lot_id uuid,lot_code text,hybrid text,stage_code text,
 method_code text,method_name text,status text,sample_reference text,recorded_at timestamptz,observed_at timestamptz,
 reviewed_at timestamptz,result_percent numeric,result_state text,revision int,attempt_no int,source_status text)
language sql stable set search_path='' as $$
 with lots as materialized(
  select l.*,p.name as hybrid from plantlab_core.lots l join plantlab_master.products p on p.id=l.product_id
  join plantlab_master.sites lab on lab.id=p_lab_site_id and lab.company_id=l.company_id and lab.is_active and lab.site_type='LAB'
  join plantlab_master.sites src on src.id=l.plant_site_id and src.company_id=l.company_id and src.site_type='PLANT' and src.is_active
  where plantlab_lab.can_use_routine_lab(p_lab_site_id)
 ),
 runs as (
  select r.*,q.request_code,l.lot_code,l.id lot_id,l.hybrid,l.stage_code,m.method_code,m.method_name,
   coalesce(nullif(btrim(s.metadata->>'sample_reference'),''),s.sample_code) sample_reference,
   decision.decision,decision.resulting_status,decision.decided_at,
   value.numeric_value,final.event_at observed_at
  from plantlab_lab.test_runs r join plantlab_lab.request_items i on i.id=r.request_item_id
  join plantlab_lab.requests q on q.id=i.request_id and q.target_lab_site_id=p_lab_site_id and q.source_module='PLANT'
  join lots l on l.id=q.lot_id join plantlab_lab.test_types tt on tt.id=i.test_type_id and tt.test_code in('GERMINATION','VIGOUR')
  left join plantlab_lab.methods m on m.id=r.method_id left join plantlab_core.samples s on s.id=r.sample_id
  left join plantlab_lab.parameters parameter on parameter.parameter_code=case when tt.test_code='GERMINATION' then 'GERMINATION_PERCENT' else 'VIGOUR_PERCENT' end
  left join plantlab_lab.result_values value on value.test_run_id=r.id and value.parameter_id=parameter.id
  left join lateral(select d.decision,d.resulting_status,d.decided_at from plantlab_lab.result_decisions d where d.test_run_id=r.id order by d.id desc limit 1) decision on true
  left join lateral(select e.event_at from plantlab_lab.test_run_events e where e.test_run_id=r.id and e.idempotency_key in('GERMINATION_FINAL:'||r.id,'VIGOUR_FINAL:'||r.id) order by e.sequence_no desc,e.id desc limit 1) final on true
  where not exists(select from plantlab_lab.routine_submissions sub where sub.test_run_id=r.id)
 ),
 records as (
  select 'PLANT_RUN'::text entry_kind,r.id entry_id,r.request_code,r.test_code run_code,r.lot_id,r.lot_code,r.hybrid,r.stage_code,
   coalesce(r.method_code,'UNASSIGNED') method_code,coalesce(r.method_name,'Metode belum dipilih') method_name,
   case when r.status='APPROVED' and not coalesce(r.decision='APPROVE' and r.resulting_status='APPROVED',false) then 'APPROVAL_INCOMPLETE' else r.status end status,
   r.sample_reference,r.created_at recorded_at,r.observed_at,r.decided_at reviewed_at,r.numeric_value result_percent,
   case when r.status='APPROVED' and r.decision='APPROVE' and r.resulting_status='APPROVED' then 'QA_APPROVED' else 'UNAPPROVED' end result_state,
   null::int revision,r.attempt_no,r.status source_status from runs r
  union all
  select 'PLANT_PENDING',i.id,q.request_code,null,l.id,l.lot_code,l.hybrid,l.stage_code,
   coalesce(m.method_code,'UNASSIGNED'),coalesce(m.method_name,'Metode belum dipilih'),
   case when q.status='CANCELLED' or i.status='CANCELLED' then 'CANCELLED' else 'WAITING_TEST' end,
   null,i.created_at,null,null,null,'UNAPPROVED',null,null,q.status
  from plantlab_lab.request_items i join plantlab_lab.requests q on q.id=i.request_id and q.source_module='PLANT' and q.target_lab_site_id=p_lab_site_id
  join lots l on l.id=q.lot_id join plantlab_lab.test_types tt on tt.id=i.test_type_id and tt.test_code in('GERMINATION','VIGOUR')
  left join plantlab_lab.methods m on m.id=i.requested_method_id
  where not exists(select from plantlab_lab.test_runs r where r.request_item_id=i.id)
  union all
  select 'ROUTINE',d.id,null,r.test_code,l.id,l.lot_code,l.hybrid,l.stage_code,m.method_code,m.method_name,
   case when r.status='APPROVED' and not coalesce(decision.decision='APPROVE' and decision.resulting_status='APPROVED',false) then 'APPROVAL_INCOMPLETE' else coalesce(r.status,'DRAFT') end,
   d.content->>'sample_reference',d.created_at,(d.content->>'final_at')::timestamptz,decision.decided_at,value.numeric_value,
   case when r.status='APPROVED' and decision.decision='APPROVE' and decision.resulting_status='APPROVED' then 'QA_APPROVED' else 'UNAPPROVED' end,
   d.revision,r.attempt_no,coalesce(r.status,'DRAFT')
  from plantlab_lab.routine_drafts d join lots l on l.id=d.lot_id join plantlab_lab.methods m on m.id=d.method_id
  left join plantlab_lab.routine_submissions sub on sub.draft_id=d.id left join plantlab_lab.test_runs r on r.id=sub.test_run_id
  left join plantlab_lab.parameters parameter on parameter.parameter_code=case when m.method_code='SAND_25C' then 'GERMINATION_PERCENT' else 'VIGOUR_PERCENT' end
  left join plantlab_lab.result_values value on value.test_run_id=r.id and value.parameter_id=parameter.id
  left join lateral(select z.decision,z.resulting_status,z.decided_at from plantlab_lab.result_decisions z where z.test_run_id=r.id order by z.id desc limit 1) decision on true
  where d.lab_site_id=p_lab_site_id
  union all
  select 'MC_DRAFT',d.id,null,null,l.id,l.lot_code,l.hybrid,l.stage_code,'MC_LAB','MC Lab','DRAFT',d.content->>'sample_reference',d.created_at,
   (d.content->>'measured_at')::timestamptz,null,
   case when not exists(select from jsonb_array_elements(d.content->'readings') v where v='null'::jsonb) then (select avg((v::text)::numeric) from jsonb_array_elements(d.content->'readings') v) else null end,
   'DRAFT_MEAN',d.revision,null,'DRAFT'
  from plantlab_lab.moisture_drafts d join lots l on l.id=d.lot_id where d.lab_site_id=p_lab_site_id
 ) select * from records;
$$;
revoke all on function plantlab_lab.logbook_entries(uuid) from PUBLIC,anon,authenticated,service_role;

create function plantlab_api.get_lab_logbook(p_lab_site_id uuid default null,p_search text default '',p_from date default null,p_to date default null,
 p_date_basis text default 'RECORDED',p_origin text default 'ALL',p_method text default 'ALL',p_status text default 'ALL',p_offset int default 0,p_limit int default 50)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare lab uuid:=p_lab_site_id;result jsonb;basis text:=upper(btrim(p_date_basis));origin text:=upper(btrim(p_origin));method text:=upper(btrim(p_method));state text:=upper(btrim(p_status));
begin
 if lab is null then select s.id into lab from plantlab_master.sites s where plantlab_lab.can_use_routine_lab(s.id) order by s.site_code,s.id limit 1;end if;
 if lab is null or not plantlab_lab.can_use_routine_lab(lab) then raise exception 'Assigned Lab role required' using errcode='42501';end if;
 if coalesce(length(p_search),0)>120 or p_offset is null or p_offset<0 or p_offset>100000 or p_limit is null or p_limit not between 1 and 100 or p_from>p_to
  or basis is null or basis not in('RECORDED','OBSERVED') or origin is null or origin not in('ALL','PLANT','ROUTINE','MC')
  or method is null or (method not in('ALL','MC_LAB','UNASSIGNED') and not exists(select from plantlab_lab.methods m where m.method_code=method))
  or state is null or state not in('ALL','DRAFT','WAITING_TEST','ASSIGNED','IN_PROGRESS','SUBMITTED','IN_REVIEW','APPROVED','RETEST','REJECTED','CANCELLED','APPROVAL_INCOMPLETE') then raise exception 'Invalid logbook filters' using errcode='22023';end if;
 with entries as materialized(select * from plantlab_lab.logbook_entries(lab)),filtered as materialized(
  select e.* from entries e where
   (coalesce(btrim(p_search),'')='' or position(lower(btrim(p_search)) in lower(concat_ws(' ',e.lot_code,e.hybrid,e.sample_reference,e.request_code,e.run_code)))>0)
   and (origin='ALL' or (origin='PLANT' and e.entry_kind in('PLANT_RUN','PLANT_PENDING')) or (origin='ROUTINE' and e.entry_kind='ROUTINE') or (origin='MC' and e.entry_kind='MC_DRAFT'))
   and (method='ALL' or e.method_code=method) and (state='ALL' or e.status=state)
   and (p_from is null or ((case when basis='RECORDED' then e.recorded_at else e.observed_at end) at time zone 'Asia/Jakarta')::date>=p_from)
   and (p_to is null or ((case when basis='RECORDED' then e.recorded_at else e.observed_at end) at time zone 'Asia/Jakarta')::date<=p_to)
 ),page as(select * from filtered order by recorded_at desc,entry_kind,entry_id limit p_limit offset p_offset)
 select jsonb_build_object('version',1,'read_only',true,'selected_lab_site_id',lab,
  'lab_sites',(select jsonb_agg(jsonb_build_object('id',s.id,'site_name',s.site_name) order by s.site_name,s.id) from plantlab_master.sites s where plantlab_lab.can_use_routine_lab(s.id)),
  'method_options',(select jsonb_agg(jsonb_build_object('method_code',x.method_code,'method_name',x.method_name) order by x.method_name) from (
    select distinct m.method_code,m.method_name from plantlab_lab.methods m join plantlab_lab.confirmed_method_contracts c on c.method_id=m.id
    union select distinct e.method_code,e.method_name from entries e union select 'MC_LAB','MC Lab' union select 'UNASSIGNED','Metode belum dipilih')x),
  'entries',coalesce((select jsonb_agg(to_jsonb(page) order by recorded_at desc,entry_kind,entry_id) from page),'[]'::jsonb),
  'total',(select count(*) from filtered),'offset',p_offset,'limit',p_limit,'has_more',(select count(*)>p_offset+p_limit from filtered),
  'summary',(select jsonb_build_object('total',count(*),'approved',count(*) filter(where result_state='QA_APPROVED'),
   'draft',count(*) filter(where status='DRAFT'),'waiting_qa',count(*) filter(where status in('IN_REVIEW','SUBMITTED')),
   'retest',count(*) filter(where status='RETEST'),'other',count(*) filter(where result_state<>'QA_APPROVED' and status not in('DRAFT','IN_REVIEW','SUBMITTED','RETEST')),
   'missing_observation_time',count(*) filter(where observed_at is null)) from filtered),
  'filters',jsonb_build_object('search',coalesce(p_search,''),'from',p_from,'to',p_to,'date_basis',basis,'origin',origin,'method',method,'status',state),
  'as_of',now(),'history_included',false,'authorizes_lot_release',false) into result;
 return result;
end;
$$;
revoke all on function plantlab_api.get_lab_logbook(uuid,text,date,date,text,text,text,text,int,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_lab_logbook(uuid,text,date,date,text,text,text,text,int,int) to authenticated;
comment on function plantlab_api.get_lab_logbook(uuid,text,date,date,text,text,text,text,int,int) is 'Read-only Lab logbook. One row per Plant run/attempt or pending item, routine draft/submission, MC draft. No double-counting routine canonical runs. Filters use explicit recorded or actual observation date in WIB. No average of percentages, historical import, quality pass or lot release.';
notify pgrst,'reload schema';
commit;
