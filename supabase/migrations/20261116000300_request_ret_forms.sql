-- Per-attempt RET form for Plant requests. Only reads existing operational evidence.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';
create function plantlab_api.get_request_ret_form_export(p_run_code text,p_expected_status text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare run plantlab_lab.test_runs;q plantlab_lab.requests;l plantlab_core.lots;c plantlab_lab.vigour_run_contexts;
 protocol plantlab_lab.ret_run_protocols;receipt plantlab_lab.sample_receipts;decision plantlab_lab.result_decisions;
 sample plantlab_core.samples;detail jsonb;observations jsonb;approved boolean:=false;context jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 if p_run_code is null or p_run_code !~ '^LT-[A-Z0-9]{1,60}$' or p_expected_status is null
 or p_expected_status not in('IN_PROGRESS','SUBMITTED','IN_REVIEW','APPROVED','RETEST','REJECTED','CANCELLED') then
  raise exception 'Saved RET run and status required' using errcode='22023';end if;
 select r.* into run from plantlab_lab.test_runs r
 join plantlab_lab.request_items i on i.id=r.request_item_id
 join plantlab_lab.requests req on req.id=i.request_id and req.source_module='PLANT'
 join plantlab_core.lots lot on lot.id=req.lot_id
 join plantlab_master.sites lab on lab.id=req.target_lab_site_id and lab.site_type='LAB' and lab.is_active and lab.company_id=lot.company_id
 join plantlab_master.sites src on src.id=req.request_site_id and src.site_type='PLANT' and src.is_active and src.company_id=lot.company_id
 where r.test_code=p_run_code and plantlab_platform.has_permission('LAB','result.read',req.target_lab_site_id,lot.company_id)
 and not exists(select from plantlab_lab.routine_submissions s where s.test_run_id=r.id);
 if not found then raise exception 'Run outside assigned Lab request scope' using errcode='42501';end if;
 if run.status<>p_expected_status then raise exception 'Run status changed; reload before download' using errcode='40001';end if;
 if not exists(select from plantlab_lab.methods where id=run.method_id and method_code='RET_16C_72H') then
  raise exception 'Dedicated RET request form only' using errcode='22023';end if;
 select * into protocol from plantlab_lab.ret_run_protocols where test_run_id=run.id;
 select * into c from plantlab_lab.vigour_run_contexts where test_run_id=run.id;
 if protocol.test_run_id is null or c.test_run_id is null then raise exception 'RET protocol evidence missing' using errcode='22023';end if;
 select req.* into strict q from plantlab_lab.requests req join plantlab_lab.request_items i on i.request_id=req.id where i.id=run.request_item_id;
 select * into strict l from plantlab_core.lots where id=q.lot_id;
 select * into strict sample from plantlab_core.samples where id=run.sample_id and lot_id=l.id;
 select r.* into receipt from plantlab_lab.test_cycles cycle join plantlab_lab.sample_receipts r on r.id=cycle.incoming_receipt_id
 join plantlab_lab.request_samples rs on rs.id=r.request_sample_id and rs.request_id=q.id and rs.sample_id=run.sample_id
 where cycle.id=run.test_cycle_id and cycle.request_id=q.id and cycle.sample_id=run.sample_id;
 if receipt.id is null then raise exception 'Exact sample receipt evidence missing' using errcode='22023';end if;
 select e.metadata into detail from plantlab_lab.test_run_events e where e.test_run_id=run.id and e.idempotency_key='VIGOUR_FINAL:'||run.id;
 select jsonb_agg(jsonb_build_object('radicle_at_least_2mm',o.radicle_at_least_2mm) order by n) into observations
 from generate_series(1,4) n left join plantlab_lab.ret_radicle_observations o on o.test_run_id=run.id and o.replicate_no=n;
 select * into decision from plantlab_lab.result_decisions where test_run_id=run.id order by id desc limit 1;
 approved:=coalesce(run.status='APPROVED' and decision.decision='APPROVE' and decision.resulting_status='APPROVED'
  and decision.reviewer_id<>run.performed_by and decision.decided_at is not null
  and detail->>'calculation_code'='RET_RADICLE_4X100_V1' and (detail->>'within_tolerance')::boolean is true
  and (detail->>'elapsed_requirement_met')::boolean is true
  and (detail->>'observed_at')::timestamptz>=c.actual_started_at+interval'72hours'
  and protocol.minimum_radicle_mm=2 and protocol.duration_hours=72 and protocol.temperature_celsius=16 and protocol.tolerance_replicates=4,false);
 context:=jsonb_build_object('request_id',q.id,'request_code',q.request_code,'plant_site_name',(select site_name from plantlab_master.sites where id=q.request_site_id),
  'sample_code',sample.sample_code,'lab_accession',receipt.external_accession_no,'receipt_code',receipt.receipt_code,
  'dispatch_code',(select dispatch_code from plantlab_plant.sample_dispatches where lab_request_id=q.id and sample_id=run.sample_id),
  'observation_note',detail->>'observation_note');
 return jsonb_build_object('ret_form_version',1,'source','PLANT_REQUEST','read_only',true,'authorizes_lot_release',false,'operator_names_recorded',false,
  'id',run.id,'revision',null,'status',run.status,'can_edit',false,'created_by',run.created_by,'updated_at',run.updated_at,
  'lot_id',l.id,'lot_code',l.lot_code,'hybrid',(select name from plantlab_master.products where id=l.product_id),'stage_code',l.stage_code,'crop_category',l.crop_category_code,
  'method_code','RET_16C_72H','method_name','Radicle Emergence Test','lab_name',(select site_name from plantlab_master.sites where id=q.target_lab_site_id),
  'content',jsonb_build_object('sample_reference',coalesce(nullif(btrim(sample.metadata->>'sample_reference'),''),sample.sample_code),
   'received_at',coalesce(receipt.source_received_at,receipt.received_at),'started_at',c.actual_started_at,'final_at',detail->>'observed_at',
   'note',c.conditions_note,'replicate_count',4,'observations',observations),
  'workflow',jsonb_build_object('run_id',run.id,'run_code',run.test_code,'status',run.status,'attempt_no',run.attempt_no,'parent_run_id',run.retest_of_id,
   'summary',detail,'analyst_id',run.performed_by,'reviewer_id',decision.reviewer_id,'review_reason',decision.reason,'reviewed_at',decision.decided_at,'can_review',false,'can_retest',false),
  'export_status',case when run.status='APPROVED' and not approved then 'APPROVAL_INCOMPLETE' else run.status end,
  'qa_approval_verified',approved,'qa_decision',decision.decision,'request_context',context,'retest_of_run_id',run.retest_of_id,
  'test_purpose',case when run.retest_of_id is null then 'INITIAL' else 'RETEST_VERIFICATION' end,'snapshot_at',statement_timestamp());
end;
$$;
revoke all on function plantlab_api.get_request_ret_form_export(text,text) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_request_ret_form_export(text,text) to authenticated;
comment on function plantlab_api.get_request_ret_form_export(text,text) is 'Read-only per-attempt RET form for Plant requests, including prior attempts. Same assigned-Lab result.read boundary. Expected source status prevents stale downloads. No invented revision, names, QA, duration, results, or lot release. Routine source excluded.';
notify pgrst,'reload schema';
commit;
