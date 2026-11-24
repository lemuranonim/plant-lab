-- Lab-to-Plant logistics only. No canonical test request, run or QA decision is created.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';

create table plantlab_lab.plant_sample_requests (
 id uuid primary key default gen_random_uuid(),
 lab_site_id uuid not null references plantlab_master.sites(id),
 plant_site_id uuid not null references plantlab_master.sites(id),
 lot_id uuid not null references plantlab_core.lots(id),
 company_id bigint not null references plantlab_master.companies(id),
 purpose text not null check(length(purpose) between 1 and 500),
 status text not null check(status in('REQUESTED','SENT','RECEIVED','DECLINED','CANCELLED')),
 requested_by uuid not null references plantlab_platform.identities(id),
 requested_at timestamptz not null,
 updated_at timestamptz not null,
 sample_label text check(length(sample_label) between 1 and 120),
 sent_grams numeric check(sent_grams>0 and sent_grams<'Infinity'::numeric),
 sent_note text check(length(sent_note) between 1 and 500),
 sent_at timestamptz,
 received_grams numeric check(received_grams>0 and received_grams<'Infinity'::numeric),
 received_note text check(length(received_note) between 1 and 500),
 received_at timestamptz,
 closure_note text check(length(closure_note) between 1 and 500),
 check ((status in('SENT','RECEIVED'))=(sent_at is not null and sample_label is not null and sent_grams is not null and sent_note is not null)),
 check ((status='RECEIVED')=(received_at is not null and received_grams is not null and received_note is not null)),
 check ((status in('DECLINED','CANCELLED'))=(closure_note is not null))
);
create index plant_sample_requests_lab_idx on plantlab_lab.plant_sample_requests(lab_site_id,updated_at desc,id);
create index plant_sample_requests_plant_idx on plantlab_lab.plant_sample_requests(plant_site_id,updated_at desc,id);
create index plant_sample_requests_labels_idx on plantlab_lab.plant_sample_requests(lab_site_id,lot_id,received_at desc) where status='RECEIVED';
create table plantlab_lab.plant_sample_request_events (
 request_id uuid not null references plantlab_lab.plant_sample_requests(id),
 actor_id uuid not null references plantlab_platform.identities(id),
 action_id uuid not null,
 action text not null check(action in('CREATE','SEND','RECEIVE','DECLINE','CANCEL')),
 payload jsonb not null,
 response jsonb not null,
 recorded_at timestamptz not null,
 primary key(actor_id,action_id),
 unique(request_id,action)
);
create trigger plant_sample_request_events_immutable before update or delete on plantlab_lab.plant_sample_request_events
 for each row execute function plantlab_lab.guard_uac_reference_history();
alter table plantlab_lab.plant_sample_requests enable row level security;
alter table plantlab_lab.plant_sample_request_events enable row level security;
revoke all on plantlab_lab.plant_sample_requests,plantlab_lab.plant_sample_request_events from public,anon,authenticated,service_role;

create function plantlab_lab.can_use_plant_sample_requests(p_module text,p_site uuid,p_write boolean default false)
returns boolean language sql stable set search_path='' as $$
 select case p_module when 'LAB' then plantlab_lab.can_use_routine_lab(p_site,p_write)
 when 'PLANT' then auth.uid() is not null and exists(select from plantlab_master.sites s
  where s.id=p_site and s.site_type='PLANT' and s.is_active
  and (plantlab_platform.has_exact_scoped_role('PLANT','PLANT_OPERATOR',s.id,s.company_id)
   or plantlab_platform.has_exact_scoped_role('PLANT','PLANT_SPV',s.id,s.company_id))
  and (not p_write or plantlab_platform.has_permission('PLANT','dispatch.write',s.id,s.company_id)))
 else false end;
$$;

create function plantlab_api.list_plant_sample_requests(p_module text,p_site_id uuid default null,p_search text default '',p_status text default 'ALL',p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare selected uuid:=p_site_id;result jsonb;
begin
 if p_module is null or p_module not in('LAB','PLANT') or p_status is null or p_status not in('ALL','ACTIVE','REQUESTED','SENT','RECEIVED','DECLINED','CANCELLED')
 or length(coalesce(p_search,''))>120 or p_offset is null or p_offset not between 0 and 100000 then raise exception 'Invalid sample request filters' using errcode='22023';end if;
 if selected is null then
  select s.id into selected from plantlab_master.sites s where plantlab_lab.can_use_plant_sample_requests(p_module,s.id) order by s.site_name,s.id limit 1;
 end if;
 if selected is null or not plantlab_lab.can_use_plant_sample_requests(p_module,selected) then raise exception 'Assigned site required' using errcode='42501';end if;
 with matched as materialized (
  select r.id,r.lab_site_id,r.lot_id,r.status,l.lot_code,p.name hybrid,src.site_name plant_site,dst.site_name lab_site,
  r.purpose,r.requested_at,r.updated_at,r.sample_label,r.sent_grams,r.sent_note,r.sent_at,r.received_grams,r.received_note,r.received_at,r.closure_note
  from plantlab_lab.plant_sample_requests r
  join plantlab_core.lots l on l.id=r.lot_id and l.company_id=r.company_id
  join plantlab_master.products p on p.id=l.product_id
  join plantlab_master.sites src on src.id=r.plant_site_id and src.company_id=r.company_id and src.site_type='PLANT'
  join plantlab_master.sites dst on dst.id=r.lab_site_id and dst.company_id=r.company_id and dst.site_type='LAB'
  where (case when p_module='LAB' then r.lab_site_id else r.plant_site_id end)=selected
   and (p_status='ALL' or p_status=r.status or p_status='ACTIVE' and r.status in('REQUESTED','SENT'))
   and (nullif(btrim(p_search),'') is null or position(lower(btrim(p_search)) in lower(concat_ws(' ',l.lot_code,p.name,r.sample_label)))>0)
 ), page as (select * from matched order by updated_at desc,id limit 30 offset p_offset)
 select jsonb_build_object('version',1,'selected_site_id',selected,'can_write',plantlab_lab.can_use_plant_sample_requests(p_module,selected,true),
 'sites',(select jsonb_agg(jsonb_build_object('id',s.id,'site_name',s.site_name) order by s.site_name,s.id) from plantlab_master.sites s where plantlab_lab.can_use_plant_sample_requests(p_module,s.id)),
 'rows',coalesce((select jsonb_agg(to_jsonb(page) order by updated_at desc,id) from page),'[]'::jsonb),
 'total',(select count(*) from matched),'offset',p_offset,'limit',30,'has_more',(select count(*)>p_offset+30 from matched)) into result;
 return result;
end$$;

create function plantlab_api.record_plant_sample_request(
 p_module text,p_action text,p_action_id uuid,p_request_id uuid default null,
 p_lab_site_id uuid default null,p_lot_id uuid default null,p_note text default null,
 p_sample_label text default null,p_grams numeric default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();r plantlab_lab.plant_sample_requests;old_event plantlab_lab.plant_sample_request_events;
 note text:=nullif(btrim(p_note),'');label text:=nullif(btrim(p_sample_label),'');payload jsonb;response jsonb;stamp timestamptz;
begin
 if actor is null or not coalesce((p_module='LAB' and p_action in('CREATE','RECEIVE','CANCEL')) or
  (p_module='PLANT' and p_action in('SEND','DECLINE')),false) then raise exception 'Action is outside the assigned role' using errcode='42501';end if;
 if p_action_id is null or note is null or length(note)>500 or
   (case when p_action='CREATE' then p_request_id is not null or p_lab_site_id is null or p_lot_id is null
    else p_request_id is null or p_lab_site_id is not null or p_lot_id is not null end) or
   (case when p_action in('SEND','RECEIVE') then label is null or length(label)>120 or p_grams is null or p_grams<=0 or p_grams>999999999 or scale(p_grams)>3
    else label is not null or p_grams is not null end)
 then raise exception 'Invalid sample request details' using errcode='22023';end if;
 payload:=jsonb_build_object('module',p_module,'action',p_action,'request_id',p_request_id,'lab_site_id',p_lab_site_id,'lot_id',p_lot_id,'note',note,'label',label,'grams',p_grams);
 perform pg_advisory_xact_lock(hashtextextended('PLANT_SAMPLE:'||actor||':'||p_action_id,0));
 select * into old_event from plantlab_lab.plant_sample_request_events e where e.actor_id=actor and e.action_id=p_action_id;
 if found then
  if old_event.payload is distinct from payload then raise exception 'Action already recorded with different details' using errcode='23505';end if;
  select * into r from plantlab_lab.plant_sample_requests s where s.id=old_event.request_id;
  if not plantlab_lab.can_use_plant_sample_requests(p_module,case p_module when 'LAB' then r.lab_site_id else r.plant_site_id end,true)
  then raise exception 'Assigned site required' using errcode='42501';end if;
  return old_event.response;
 end if;
 if p_action='CREATE' then
  if not plantlab_lab.can_use_plant_sample_requests('LAB',p_lab_site_id,true) then raise exception 'Assigned Analyst required' using errcode='42501';end if;
  stamp:=clock_timestamp();
  insert into plantlab_lab.plant_sample_requests(lab_site_id,plant_site_id,lot_id,company_id,purpose,status,requested_by,requested_at,updated_at)
   select lab.id,plant.id,l.id,l.company_id,note,'REQUESTED',actor,stamp,stamp
   from plantlab_core.lots l
   join plantlab_master.sites lab on lab.id=p_lab_site_id and lab.company_id=l.company_id and lab.site_type='LAB' and lab.is_active
   join plantlab_master.sites plant on plant.id=l.plant_site_id and plant.company_id=l.company_id and plant.site_type='PLANT' and plant.is_active
   where l.id=p_lot_id returning * into r;
  if not found then raise exception 'Lot and Plant outside assigned Lab company' using errcode='42501';end if;
 else
  select s.* into r from plantlab_lab.plant_sample_requests s
  where s.id=p_request_id and plantlab_lab.can_use_plant_sample_requests(p_module,case p_module when 'LAB' then s.lab_site_id else s.plant_site_id end,true)
  for update of s;
  if not found then raise exception 'Assigned site required' using errcode='42501';end if;
  if p_action='RECEIVE' then
   if r.status<>'SENT' then raise exception 'Sample not awaiting receipt' using errcode='55000';end if;
   if label is distinct from r.sample_label then raise exception 'Physical label does not match dispatch' using errcode='22023';end if;
  elsif r.status<>'REQUESTED' then raise exception 'Request is no longer awaiting dispatch' using errcode='55000';end if;
  stamp:=clock_timestamp();
  update plantlab_lab.plant_sample_requests s set updated_at=stamp,
   status=case p_action when 'SEND' then 'SENT' when 'RECEIVE' then 'RECEIVED' when 'DECLINE' then 'DECLINED' else 'CANCELLED' end,
   sample_label=case when p_action='SEND' then label else s.sample_label end,
   sent_grams=case when p_action='SEND' then p_grams else s.sent_grams end,
   sent_note=case when p_action='SEND' then note else s.sent_note end,
   sent_at=case when p_action='SEND' then stamp else s.sent_at end,
   received_grams=case when p_action='RECEIVE' then p_grams else s.received_grams end,
   received_note=case when p_action='RECEIVE' then note else s.received_note end,
   received_at=case when p_action='RECEIVE' then stamp else s.received_at end,
   closure_note=case when p_action in('DECLINE','CANCEL') then note else s.closure_note end
  where s.id=r.id returning * into r;
 end if;
 response:=jsonb_build_object('id',r.id,'status',r.status,'recorded_at',stamp);
 insert into plantlab_lab.plant_sample_request_events(request_id,actor_id,action_id,action,payload,response,recorded_at)
 values(r.id,actor,p_action_id,p_action,payload,response,stamp);
 return response;
end$$;

revoke all on function plantlab_lab.can_use_plant_sample_requests(text,uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function plantlab_api.list_plant_sample_requests(text,uuid,text,text,int),
 plantlab_api.record_plant_sample_request(text,text,uuid,uuid,uuid,uuid,text,text,numeric) from public,anon,authenticated,service_role;
grant execute on function plantlab_api.list_plant_sample_requests(text,uuid,text,text,int),
 plantlab_api.record_plant_sample_request(text,text,uuid,uuid,uuid,uuid,text,text,numeric) to authenticated;
-- Only physical receipts enter the existing suggestions. No date/count is copied into a draft.
create or replace function plantlab_api.list_routine_sample_references(
 p_lab_site_id uuid,p_lot_id uuid,p_search text default '',p_offset int default 0
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not plantlab_lab.can_use_routine_lab(p_lab_site_id) then
  raise exception 'Assigned Lab role required' using errcode='42501';
 end if;
 if not exists(select from plantlab_core.lots l
  join plantlab_master.sites lab on lab.id=p_lab_site_id and lab.company_id=l.company_id
  join plantlab_master.sites src on src.id=l.plant_site_id and src.company_id=l.company_id and src.is_active and src.site_type='PLANT'
  where l.id=p_lot_id) then
  raise exception 'Lot outside assigned Lab company' using errcode='42501';
 end if;
 if coalesce(length(p_search),0)>120 or p_offset is null or p_offset<0 or p_offset>100000 then
  raise exception 'Invalid search or offset' using errcode='22023';
 end if;
 with candidates as (
  select coalesce(nullif(btrim(s.metadata->>'sample_reference'),''),s.sample_code) as reference,
   s.sample_code,'RECEIVED'::text as source_kind,sr.received_at as recorded_at,0 as priority
  from plantlab_core.samples s
  join plantlab_lab.request_samples rs on rs.sample_id=s.id
  join plantlab_lab.requests q on q.id=rs.request_id and q.lot_id=s.lot_id and q.target_lab_site_id=p_lab_site_id
  join plantlab_lab.sample_receipts sr on sr.request_sample_id=rs.id and sr.decision='ACCEPT' and sr.status='ACCEPTED'
  where s.lot_id=p_lot_id
  union all
  select r.sample_label,r.sample_label,'RECEIVED'::text,r.received_at,0
  from plantlab_lab.plant_sample_requests r
  where r.lab_site_id=p_lab_site_id and r.lot_id=p_lot_id and r.status='RECEIVED'
  union all
  select nullif(btrim(d.content->>'sample_reference'),''),null::text,'DRAFT',d.updated_at,1
  from plantlab_lab.routine_drafts d
  where d.lab_site_id=p_lab_site_id and d.lot_id=p_lot_id
   and not exists(select from plantlab_lab.routine_submissions sub where sub.draft_id=d.id)
 ), distinct_refs as materialized (
  select distinct on (reference) reference,sample_code,source_kind,recorded_at
  from candidates where reference is not null and length(reference)<=120
  order by reference,priority,recorded_at desc,sample_code nulls last
 ), matched as materialized (
  select * from distinct_refs where coalesce(btrim(p_search),'')=''
   or position(lower(btrim(p_search)) in lower(reference||' '||coalesce(sample_code,'')))>0
 ), page as (
  select * from matched order by reference collate "C" limit 50 offset p_offset
 ) select jsonb_build_object('references',coalesce((select jsonb_agg(to_jsonb(page) order by reference collate "C") from page),'[]'::jsonb),
  'total',(select count(*) from matched),'offset',p_offset,'limit',50,
  'has_more',(select count(*)>p_offset+50 from matched)) into result;
 return result;
end;
$$;
notify pgrst,'reload schema';
commit;
