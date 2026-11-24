-- Read-only suggestions, not physical-sample verification or sample reuse.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create function plantlab_api.list_routine_sample_references(
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
revoke all on function plantlab_api.list_routine_sample_references(uuid,uuid,text,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.list_routine_sample_references(uuid,uuid,text,int) to authenticated;
comment on function plantlab_api.list_routine_sample_references(uuid,uuid,text,int) is
 'Scoped suggestions only. Received sample labels and unsubmitted draft labels are distinguished. Selecting a reference does not verify physical identity, reuse a canonical sample, or copy times/counts.';
notify pgrst,'reload schema';
commit;
