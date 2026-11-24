-- Separate read-only Germination/Vigour request forms. Never split recorded replicates.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';
create function plantlab_api.list_request_germination_form_runs(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare entries jsonb;amount int;
begin
 if auth.uid() is null or not exists(select from plantlab_lab.requests q join plantlab_core.lots l on l.id=q.lot_id
  join plantlab_master.sites lab on lab.id=q.target_lab_site_id and lab.company_id=l.company_id and lab.site_type='LAB' and lab.is_active
  where q.id=p_request_id and q.source_module='PLANT' and plantlab_platform.has_permission('LAB','result.read',q.target_lab_site_id,l.company_id)) then
  raise exception 'Request outside assigned Lab scope' using errcode='42501';end if;
 select count(*) into amount from plantlab_lab.test_runs r join plantlab_lab.request_items i on i.id=r.request_item_id
 join plantlab_lab.test_types tt on tt.id=i.test_type_id and tt.test_code='GERMINATION'
 join plantlab_lab.methods m on m.id=r.method_id and m.method_code='SAND_25C'
 where i.request_id=p_request_id and not exists(select from plantlab_lab.routine_submissions s where s.test_run_id=r.id);
 if amount>100 then raise exception 'More than100 saved attempts; request coordinator assistance' using errcode='54000';end if;
 select coalesce(jsonb_agg(jsonb_build_object('run_code',r.test_code,'status',r.status,'attempt_no',r.attempt_no,'method_code',m.method_code) order by r.attempt_no desc,r.created_at desc,r.id),'[]'::jsonb) into entries
 from plantlab_lab.test_runs r join plantlab_lab.request_items i on i.id=r.request_item_id
 join plantlab_lab.test_types tt on tt.id=i.test_type_id and tt.test_code='GERMINATION'
 join plantlab_lab.methods m on m.id=r.method_id and m.method_code='SAND_25C'
 where i.request_id=p_request_id and not exists(select from plantlab_lab.routine_submissions s where s.test_run_id=r.id);
 return jsonb_build_object('request_id',p_request_id,'runs',entries,'total',amount,'read_only',true,'authorizes_lot_release',false);
end;
$$;
create function plantlab_api.get_request_seedling_form_export(p_run_code text,p_expected_status text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare run plantlab_lab.test_runs;q plantlab_lab.requests;l plantlab_core.lots;sample plantlab_core.samples;receipt plantlab_lab.sample_receipts;
 decision plantlab_lab.result_decisions;context plantlab_lab.vigour_run_contexts;kind text;method text;method_name text;
 detail jsonb;observations jsonb;final_time timestamptz;first_time timestamptz;value numeric;matched boolean;approved boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 if p_run_code is null or p_run_code !~ '^LT-[A-Z0-9]{1,60}$' or p_expected_status is null
 or p_expected_status not in('IN_PROGRESS','SUBMITTED','IN_REVIEW','APPROVED','RETEST','REJECTED','CANCELLED') then raise exception 'Saved run/status required' using errcode='22023';end if;
 select r.* into run from plantlab_lab.test_runs r join plantlab_lab.request_items i on i.id=r.request_item_id
 join plantlab_lab.requests req on req.id=i.request_id and req.source_module='PLANT' join plantlab_core.lots lot on lot.id=req.lot_id
 join plantlab_master.sites lab on lab.id=req.target_lab_site_id and lab.site_type='LAB' and lab.is_active and lab.company_id=lot.company_id
 join plantlab_master.sites src on src.id=req.request_site_id and src.site_type='PLANT' and src.is_active and src.company_id=lot.company_id
 where r.test_code=p_run_code and plantlab_platform.has_permission('LAB','result.read',req.target_lab_site_id,lot.company_id)
 and not exists(select from plantlab_lab.routine_submissions s where s.test_run_id=r.id);
 if not found then raise exception 'Run outside assigned Lab request scope' using errcode='42501';end if;
 if run.status<>p_expected_status then raise exception 'Run status changed; reload before download' using errcode='40001';end if;
 select tt.test_code,m.method_code,m.method_name into kind,method,method_name from plantlab_lab.request_items i
 join plantlab_lab.test_types tt on tt.id=i.test_type_id join plantlab_lab.methods m on m.id=run.method_id where i.id=run.request_item_id;
 if not coalesce((kind='GERMINATION' and method='SAND_25C') or (kind='VIGOUR' and exists(select from plantlab_lab.vigour_calculation_contracts c where c.method_id=run.method_id and c.calculation_code='EXCEL_ROUND_AVERAGE_2X100')),false) then
  raise exception 'Germination or ordinary Vigour request form only; RET stays separate' using errcode='22023';end if;
 select req.* into strict q from plantlab_lab.requests req join plantlab_lab.request_items i on i.request_id=req.id where i.id=run.request_item_id;
 select * into strict l from plantlab_core.lots where id=q.lot_id;
 select * into strict sample from plantlab_core.samples where id=run.sample_id and lot_id=l.id;
 select r.* into receipt from plantlab_lab.test_cycles cycle join plantlab_lab.sample_receipts r on r.id=cycle.incoming_receipt_id
 join plantlab_lab.request_samples rs on rs.id=r.request_sample_id and rs.request_id=q.id and rs.sample_id=run.sample_id
 where cycle.id=run.test_cycle_id and cycle.request_id=q.id and cycle.sample_id=run.sample_id;
 if receipt.id is null then raise exception 'Exact sample receipt evidence missing' using errcode='22023';end if;
 select * into context from plantlab_lab.vigour_run_contexts where test_run_id=run.id;
 if kind='VIGOUR' and context.test_run_id is null then raise exception 'Vigour actual input evidence missing' using errcode='22023';end if;
 select e.metadata,e.event_at into detail,final_time from plantlab_lab.test_run_events e
 where e.test_run_id=run.id and e.idempotency_key=(case when kind='GERMINATION' then 'GERMINATION_FINAL:' else 'VIGOUR_FINAL:' end)||run.id;
 select min(observed_at) into first_time from plantlab_lab.test_run_observations where test_run_id=run.id and observation_phase='FIRST_COUNT';
 with reps as(select distinct replicate_no from plantlab_lab.test_run_observations where test_run_id=run.id and observation_phase in('FIRST_COUNT','FINAL'))
 select coalesce(jsonb_agg(jsonb_build_object('replicate_no',n.replicate_no,'tested',case when o.normal_count is not null and o.abnormal_count is not null and o.dead_count is not null then o.total_count end,
  'normal',o.normal_count,'abnormal',o.abnormal_count,'dead',o.dead_count,'first_normal',f.normal_count,
  'remarks',nullif(concat_ws(E'\n',case when f.remarks is not null then 'First count: '||f.remarks end,case when o.remarks is not null then 'Final: '||o.remarks end),'')) order by n.replicate_no),'[]'::jsonb) into observations
 from reps n left join plantlab_lab.test_run_observations o on o.test_run_id=run.id and o.observation_phase='FINAL' and o.replicate_no=n.replicate_no
 left join plantlab_lab.test_run_observations f on f.test_run_id=run.id and f.observation_phase='FIRST_COUNT' and f.replicate_no=n.replicate_no;
 select rv.numeric_value into value from plantlab_lab.result_values rv join plantlab_lab.parameters p on p.id=rv.parameter_id
 where rv.test_run_id=run.id and p.parameter_code=case when kind='GERMINATION' then 'GERMINATION_PERCENT' else 'VIGOUR_PERCENT' end;
 matched:=coalesce(value=(detail->>case when kind='GERMINATION' then 'germination_percent' else 'vigour_percent' end)::numeric,false);
 select * into decision from plantlab_lab.result_decisions where test_run_id=run.id order by id desc limit 1;
 approved:=coalesce(run.status='APPROVED' and decision.decision='APPROVE' and decision.resulting_status='APPROVED' and decision.reviewer_id<>run.performed_by
  and decision.decided_at is not null and (detail->>'within_tolerance')::boolean is true and matched,false);
 return jsonb_build_object('request_form_version',1,'source','PLANT_REQUEST','read_only',true,'authorizes_lot_release',false,'id',run.id,'run_code',run.test_code,
  'revision',null,'status',run.status,'export_status',case when run.status='APPROVED' and not approved then 'APPROVAL_INCOMPLETE' else run.status end,
  'qa_approval_verified',approved,'qa_decision',decision.decision,'attempt_no',run.attempt_no,'retest_of_run_id',run.retest_of_id,
  'request_id',q.id,'request_code',q.request_code,'plant_site_name',(select site_name from plantlab_master.sites where id=q.request_site_id),
  'lot_code',l.lot_code,'hybrid',(select name from plantlab_master.products where id=l.product_id),'stage_code',l.stage_code,'crop_category',l.crop_category_code,
  'lab_name',(select site_name from plantlab_master.sites where id=q.target_lab_site_id),'test_code',kind,'method_code',method,'method_name',method_name,
  'sample_reference',coalesce(nullif(btrim(sample.metadata->>'sample_reference'),''),sample.sample_code),'sample_code',sample.sample_code,'lab_accession',receipt.external_accession_no,
  'receipt_code',receipt.receipt_code,'dispatch_code',(select dispatch_code from plantlab_plant.sample_dispatches where lab_request_id=q.id and sample_id=run.sample_id),
  'received_at',coalesce(receipt.source_received_at,receipt.received_at),'source_time_basis',case when kind='GERMINATION' then 'APPLICATION_EVENT_TIME' else 'ANALYST_ACTUAL_INPUT' end,
  'started_at',case when kind='GERMINATION' then run.started_at else context.actual_started_at end,
  'observed_at',case when kind='GERMINATION' then final_time else (detail->>'observed_at')::timestamptz end,'first_count_at',first_time,
  'conditions_note',context.conditions_note,'observation_note',detail->>'observation_note','observations',observations,'summary',detail,'result_percent',value,'result_value_matches_summary',matched,
  'analyst_id',run.performed_by,'reviewer_id',decision.reviewer_id,'review_reason',decision.reason,'reviewed_at',decision.decided_at,'updated_at',run.updated_at,'snapshot_at',statement_timestamp());
end;
$$;
revoke all on function plantlab_api.list_request_germination_form_runs(uuid),plantlab_api.get_request_seedling_form_export(text,text) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.list_request_germination_form_runs(uuid),plantlab_api.get_request_seedling_form_export(text,text) to authenticated;
comment on function plantlab_api.get_request_seedling_form_export(text,text) is 'Read-only request Germination/ordinary Vigour form per saved attempt. Actual recorded replicate totals preserved, including legacy50; never split into50 subreps or invent fresh/hard/names/physical dates. Same Lab result.read scope; RET and routine excluded; no business or lot-release writes.';
notify pgrst,'reload schema';
commit;
