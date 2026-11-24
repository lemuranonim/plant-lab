-- Read-only workload and timing. No SLA, quality rule, row, role or old API changes.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';

create function plantlab_lab.monitoring_hours(p_start timestamptz,p_end timestamptz,p_as_of timestamptz)
returns numeric language sql immutable set search_path='' as $$
 select case when p_start is not null and p_end is not null and isfinite(p_start) and isfinite(p_end)
 and p_start<=p_end and p_end<=p_as_of then round(extract(epoch from(p_end-p_start))/3600.0,3) end;
$$;

create function plantlab_lab.monitoring_entries(p_lab uuid,p_as_of timestamptz)
returns table(entry jsonb) language sql stable set search_path='' as $$
 with sources as (
  select e.*,run.id as canonical_run_id,run.submitted_at as run_submitted_at,
   coalesce(sub.draft_snapshot,d.content) as routine_content,mc.content as mc_content,
   case when e.entry_kind='ROUTINE' then (coalesce(sub.draft_snapshot,d.content)->>'received_at')::timestamptz
    when e.entry_kind='MC_DRAFT' then (mc.content->>'received_at')::timestamptz else receipt.received_at end as sample_at,
   case when e.entry_kind='MC_DRAFT' then sealed.submitted_at else coalesce(sub.submitted_at,run.submitted_at) end as sent_to_qa,
   case when e.entry_kind='MC_DRAFT' then mc_review.reviewed_at else decision.decided_at end as decision_at,
   case when e.entry_kind='MC_DRAFT' then mc_review.decision else decision.decision end as qa_decision,
   case when e.entry_kind='MC_DRAFT' then 'MC_ACTUAL_INPUT' when e.entry_kind='ROUTINE' then 'LAB_AVAILABLE_ACTUAL_INPUT'
    when receipt.source_at is not null then 'RECEIPT_SOURCE_TIME' when receipt.received_at is not null then 'RECEIPT_EVENT_TIME' else 'NOT_RECORDED' end as receipt_basis,
   exists(select from plantlab_lab.test_runs newer where newer.retest_of_id=run.id)
     or exists(select from plantlab_lab.routine_retest_drafts child where child.previous_run_id=run.id) as has_next_attempt,
   case when e.entry_kind='ROUTINE' then (coalesce(sub.draft_snapshot,d.content)->>'started_at')::timestamptz
    when e.entry_kind='MC_DRAFT' then (mc.content->>'measured_at')::timestamptz else run.started_at end as work_started_at
  from plantlab_lab.logbook_entries(p_lab) e
  left join plantlab_lab.routine_drafts d on e.entry_kind='ROUTINE' and d.id=e.entry_id and d.lab_site_id=p_lab
  left join plantlab_lab.routine_submissions sub on sub.draft_id=d.id
  left join plantlab_lab.test_runs run on (e.entry_kind='PLANT_RUN' and run.id=e.entry_id) or (e.entry_kind='ROUTINE' and run.id=sub.test_run_id)
  left join plantlab_lab.request_items item on item.id=case when e.entry_kind='PLANT_PENDING' then e.entry_id else run.request_item_id end
  left join plantlab_lab.requests q on q.id=item.request_id and q.target_lab_site_id=p_lab
  left join plantlab_lab.moisture_drafts mc on e.entry_kind='MC_DRAFT' and mc.id=e.entry_id and mc.lab_site_id=p_lab
  left join plantlab_lab.moisture_submissions sealed on sealed.draft_id=mc.id and sealed.revision=mc.revision
  left join plantlab_lab.moisture_record_reviews mc_review on mc_review.submission_id=sealed.id
  left join lateral(select z.decision,z.decided_at from plantlab_lab.result_decisions z where z.test_run_id=run.id order by z.id desc limit 1) decision on true
  left join lateral(
   select coalesce(sr.source_received_at,sr.received_at) received_at,sr.source_received_at source_at
   from plantlab_lab.sample_receipts sr join plantlab_lab.request_samples rs on rs.id=sr.request_sample_id and rs.request_id=q.id
   where sr.decision='ACCEPT' and ((run.id is null and rs.is_primary) or
    (rs.sample_id=run.sample_id and sr.id=(select incoming_receipt_id from plantlab_lab.test_cycles where id=run.test_cycle_id)))
   order by sr.received_at desc,sr.id limit 1
  ) receipt on true
 ),classified as (
  select s.*,case
   when status in('CANCELLED','REJECTED') or source_status in('CANCELLED','CLOSED','REJECTED') then 'CLOSED'
   when status='APPROVED' and result_state='QA_APPROVED' or status='VERIFIED_RECORD' then 'COMPLETED'
   when status='RETEST' and has_next_attempt then 'HISTORY'
   when status='RETEST' then 'RETEST'
   when status='RETURNED' then 'RETURNED'
   when status in('SUBMITTED','IN_REVIEW') then 'WAITING_QA'
   when status='IN_PROGRESS' then 'TESTING'
   when entry_kind='PLANT_PENDING' and source_status in('REQUESTED','ACCEPTED','PREPARED','SENT') then 'WAITING_SAMPLE'
   when status in('ASSIGNED','WAITING_TEST') then 'WAITING_TEST'
   when status='DRAFT' and sample_at is not null and work_started_at is not null then 'TESTING'
   when status='DRAFT' and sample_at is not null then 'WAITING_TEST'
   else 'INCOMPLETE' end as work_group
  from sources s
 ),timed as (
  select c.*,
   plantlab_lab.monitoring_hours(sample_at,sent_to_qa,p_as_of) as sample_to_submit_hours,
   plantlab_lab.monitoring_hours(sent_to_qa,decision_at,p_as_of) as qa_tat_hours,
   case when work_group in('WAITING_TEST','TESTING') and sent_to_qa is null then plantlab_lab.monitoring_hours(sample_at,p_as_of,p_as_of) end as open_sample_hours,
   case when work_group='WAITING_QA' then plantlab_lab.monitoring_hours(sent_to_qa,p_as_of,p_as_of) end as waiting_qa_hours,
   case when work_group='RETEST' then plantlab_lab.monitoring_hours(decision_at,p_as_of,p_as_of) end as retest_wait_hours,
   (sample_at>p_as_of or sent_to_qa>p_as_of or decision_at>p_as_of or work_started_at>p_as_of or work_started_at<sample_at or sent_to_qa<sample_at or decision_at<sent_to_qa) is true as clock_issue
  from classified c
 ) select (to_jsonb(t)-'routine_content'-'mc_content'-'run_submitted_at'-'work_started_at')||jsonb_build_object(
  'received_at',sample_at,'submitted_at',sent_to_qa,'decision_at',decision_at,
  'sample_clock_missing',sample_at is null,'qa_clock_missing',sent_to_qa is null and work_group='WAITING_QA',
  'active',work_group in('WAITING_SAMPLE','WAITING_TEST','TESTING','WAITING_QA','RETEST','RETURNED','INCOMPLETE'),
  'active_hours',coalesce(waiting_qa_hours,retest_wait_hours,open_sample_hours),
  'clock_issue',clock_issue) from timed t;
$$;

create function plantlab_api.get_lab_work_monitoring(p_lab_site_id uuid default null,p_search text default '',p_from date default null,p_to date default null,
 p_date_basis text default 'RECORDED',p_origin text default 'ALL',p_method text default 'ALL',p_work_group text default 'ALL',p_offset int default 0,p_limit int default 50)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare catalog jsonb;lab uuid;basis text:=upper(btrim(p_date_basis));work text:=upper(btrim(p_work_group));origin text:=upper(btrim(p_origin));method text:=upper(btrim(p_method));result jsonb;stamp timestamptz:=statement_timestamp();
begin
 -- Reuse existing Lab scope, method/origin validation and catalog. No client table access.
 catalog:=plantlab_api.get_lab_logbook(p_lab_site_id,p_search,p_from,p_to,'RECORDED',p_origin,p_method,'ALL',0,1);
 lab:=(catalog->>'selected_lab_site_id')::uuid;
 if basis is null or basis not in('RECORDED','RECEIVED','REVIEWED') or work is null or work not in('ALL','ACTIVE','WAITING_SAMPLE','WAITING_TEST','TESTING','WAITING_QA','RETEST','RETURNED','COMPLETED','HISTORY','CLOSED','INCOMPLETE')
 or p_offset is null or p_offset<0 or p_offset>100000 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid monitoring filters' using errcode='22023';end if;
 with entries as materialized(select entry e from plantlab_lab.monitoring_entries(lab,stamp)),filtered as materialized(
  select e from entries where
   (coalesce(btrim(p_search),'')='' or position(lower(btrim(p_search)) in lower(concat_ws(' ',e->>'lot_code',e->>'hybrid',e->>'sample_reference',e->>'request_code',e->>'run_code')))>0)
   and (origin='ALL' or origin='PLANT' and e->>'entry_kind' in('PLANT_RUN','PLANT_PENDING') or origin='ROUTINE' and e->>'entry_kind'='ROUTINE' or origin='MC' and e->>'entry_kind'='MC_DRAFT')
   and (method='ALL' or e->>'method_code'=method)
   and (work='ALL' or work='ACTIVE' and (e->>'active')::boolean or e->>'work_group'=work)
   and (p_from is null or ((case basis when 'RECORDED' then e->>'recorded_at' when 'RECEIVED' then e->>'received_at' else e->>'decision_at' end)::timestamptz at time zone 'Asia/Jakarta')::date>=p_from)
   and (p_to is null or ((case basis when 'RECORDED' then e->>'recorded_at' when 'RECEIVED' then e->>'received_at' else e->>'decision_at' end)::timestamptz at time zone 'Asia/Jakarta')::date<=p_to)
 ),page as(select e from filtered order by (e->>'active')::boolean desc,(e->>'active_hours')::numeric desc nulls last,(e->>'recorded_at')::timestamptz,e->>'entry_kind',e->>'entry_id' limit p_limit offset p_offset),
 totals as(select count(*) total,
  count(*)filter(where (e->>'active')::boolean) as active,
  count(*)filter(where e->>'work_group'='WAITING_SAMPLE') waiting_sample,
  count(*)filter(where e->>'work_group'='WAITING_TEST') waiting_test,
  count(*)filter(where e->>'work_group'='TESTING') testing,
  count(*)filter(where e->>'work_group'='WAITING_QA') waiting_qa,
  count(*)filter(where e->>'work_group'='RETEST') retest,
  count(*)filter(where e->>'work_group'='RETURNED') returned,
  count(*)filter(where e->>'work_group'='INCOMPLETE') incomplete,
  count(*)filter(where e->>'result_state'='QA_APPROVED') approved_analysis,
  count(*)filter(where e->>'status'='VERIFIED_RECORD') verified_mc,
  count(*)filter(where (e->>'sample_clock_missing')::boolean) missing_sample_time,
  count(*)filter(where (e->>'qa_clock_missing')::boolean) missing_qa_time,
  count(*)filter(where (e->>'clock_issue')::boolean) clock_issues,
  count(*)filter(where e->>'entry_kind'<>'MC_DRAFT' and e->>'qa_decision' in('APPROVE','REJECT','RETEST')) analytical_decisions,
  count(*)filter(where e->>'entry_kind'<>'MC_DRAFT' and e->>'qa_decision'='RETEST') retest_decisions,
  count((e->>'sample_to_submit_hours')::numeric)filter(where e->>'entry_kind'<>'MC_DRAFT') sample_tat_count,
  round(avg((e->>'sample_to_submit_hours')::numeric)filter(where e->>'entry_kind'<>'MC_DRAFT'),3) sample_tat_hours,
  count((e->>'qa_tat_hours')::numeric)filter(where e->>'entry_kind'<>'MC_DRAFT') qa_tat_count,
  round(avg((e->>'qa_tat_hours')::numeric)filter(where e->>'entry_kind'<>'MC_DRAFT'),3) qa_tat_hours,
  count((e->>'qa_tat_hours')::numeric)filter(where e->>'entry_kind'='MC_DRAFT') mc_qa_count,
  round(avg((e->>'qa_tat_hours')::numeric)filter(where e->>'entry_kind'='MC_DRAFT'),3) mc_qa_hours
  from filtered)
 select jsonb_build_object('version',1,'read_only',true,'authorizes_lot_release',false,'history_included',false,'sla_applied',false,
 'selected_lab_site_id',lab,'lab_sites',catalog->'lab_sites','method_options',catalog->'method_options',
 'filters',jsonb_build_object('search',coalesce(p_search,''),'from',p_from,'to',p_to,'date_basis',basis,'origin',origin,'method',method,'work_group',work),
 'entries',coalesce((select jsonb_agg(e order by (e->>'active')::boolean desc,(e->>'active_hours')::numeric desc nulls last,(e->>'recorded_at')::timestamptz,e->>'entry_kind',e->>'entry_id')from page),'[]'::jsonb),
 'total',total,'offset',p_offset,'limit',p_limit,'has_more',total>p_offset+p_limit,'summary',to_jsonb(totals)||jsonb_build_object(
 'retest_rate_percent',case when analytical_decisions>0 then round(retest_decisions*100.0/analytical_decisions,2) end),
 'as_of',stamp,'grain','ONE_TEST_ATTEMPT_OR_UNSTARTED_ITEM_OR_DRAFT') into result from totals;
 return result;
end$$;

revoke all on function plantlab_lab.monitoring_hours(timestamptz,timestamptz,timestamptz),plantlab_lab.monitoring_entries(uuid,timestamptz),
 plantlab_api.get_lab_work_monitoring(uuid,text,date,date,text,text,text,text,int,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_lab_work_monitoring(uuid,text,date,date,text,text,text,text,int,int) to authenticated;
comment on function plantlab_api.get_lab_work_monitoring(uuid,text,date,date,text,text,text,text,int,int) is 'Read-only Lab work monitoring from existing logbook sources. Per attempt/item/draft, never physical sample counts. Separate sample-to-submit/QA/MC timing, null vs zero, archived QA retests and decision-based retest rate. WIB filters; no SLA, business writes, imports or lot release.';
notify pgrst,'reload schema';
commit;
