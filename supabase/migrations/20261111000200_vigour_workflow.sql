-- Prospective Vigor workflow. Reuses canonical requests/items, custody, cycles,
-- runs, observations, results and independent decisions. No operational seed data.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create table plantlab_lab.vigour_calculation_contracts (
 method_id uuid primary key references plantlab_lab.methods(id),
 input_contract_id uuid not null references plantlab_lab.confirmed_method_contracts(id),
 version integer not null check(version=1),
 calculation_code text not null check(calculation_code='EXCEL_ROUND_AVERAGE_2X100'),
 source_reference text not null, source_sha256 text not null,
 effective_from timestamptz not null default now()
);
insert into plantlab_lab.vigour_calculation_contracts
select m.id,c.id,1,'EXCEL_ROUND_AVERAGE_2X100',
 'Germ/Vigor update03.11.2026: SOAK CX, AAT DR, SCT/AAT Extend EL; ROUND(AVERAGE(replicate normal sums),0); TOLERATED DIFF!A3:B100. User11Nov confirms2x100. Formula dates are not actual observation evidence.',
 'f32f9ee5c29c8c96144be99d5717033052cf4a1ebc688458195e794ee3b1bb31',now()
from plantlab_lab.confirmed_method_contracts c join plantlab_lab.methods m on m.id=c.method_id
where m.method_code in ('COLD_TEST_5C_24H','AAT_42C_72H_RH90','SCT_10C7D_25C5D','AAT_EXT_42C_96H_RH90') and m.version=1;
create table plantlab_lab.vigour_run_contexts (
 test_run_id uuid primary key references plantlab_lab.test_runs(id),
 calculation_method_id uuid not null references plantlab_lab.vigour_calculation_contracts(method_id),
 actual_started_at timestamptz not null,
 conditions_note text not null check(length(btrim(conditions_note)) between 3 and 1000),
 created_by uuid not null references plantlab_platform.identities(id),
 created_at timestamptz not null default now()
);
create table plantlab_lab.vigour_actions (
 action_id uuid primary key, actor_id uuid not null references plantlab_platform.identities(id),
 command text not null, item_id uuid not null references plantlab_lab.request_items(id),
 payload jsonb not null, response jsonb not null, created_at timestamptz not null default now()
);
alter table plantlab_lab.vigour_calculation_contracts enable row level security;
alter table plantlab_lab.vigour_run_contexts enable row level security;
alter table plantlab_lab.vigour_actions enable row level security;
revoke all on plantlab_lab.vigour_calculation_contracts,plantlab_lab.vigour_run_contexts,plantlab_lab.vigour_actions from PUBLIC,anon,authenticated,service_role;
create trigger vigour_calculation_contracts_immutable before update or delete on plantlab_lab.vigour_calculation_contracts for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger vigour_contexts_immutable before update or delete on plantlab_lab.vigour_run_contexts for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger vigour_actions_immutable before update or delete on plantlab_lab.vigour_actions for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_api.get_vigour_workflow_options()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform plantlab_lab.require_contract_reader();
 return jsonb_build_object('version',1,'methods',(select jsonb_agg(jsonb_build_object('method_code',m.method_code,'method_name',m.method_name,'replicate_count',2,'seeds_per_replicate',100,'procedure_summary',m.procedure_summary) order by m.method_code)
 from plantlab_lab.vigour_calculation_contracts c join plantlab_lab.methods m on m.id=c.method_id where m.is_active),
 'ret_enabled',false,'ret_pending','Actual duration start and applicable RET tolerance/SOP remain unconfirmed; radicle counts are not Germination normal counts.',
 'calculation_note','ROUND(AVERAGE(normal per100-seed replicate),0). Raw counts and unrounded percent retained. Missing tolerance blocks approval; no invented0/1/100 endpoints.',
 'authorizes_lot_release',false);
end;
$$;

-- Preserve immutable input contracts; expose current activation separately from
-- their original source-trace status for installed clients using this catalog.
create or replace function plantlab_api.get_confirmed_lab_contracts()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform plantlab_lab.require_contract_reader();
 return jsonb_build_object('confirmed_on','2026-11-11','schema_version',1,'workflow_version',2,
 'rules',(select jsonb_agg(plantlab_lab.evaluate_programme_reference(r.crop_kind,r.programme_code,r.test_code,null,now()) order by r.programme_code,r.crop_kind,r.test_code) from plantlab_lab.programme_quality_references r where r.version=3),
 'methods',(select jsonb_agg(jsonb_build_object('contract_id',c.id,'contract_version',c.contract_version,'method_code',m.method_code,'method_name',m.method_name,'method_version',m.version,
 'replicate_count',c.replicate_count,'seeds_per_replicate',c.seeds_per_replicate,'total_seeds',c.replicate_count*c.seeds_per_replicate,
 'observation_kind',c.observation_kind,'minimum_radicle_mm',c.minimum_radicle_mm,'duration_days',c.duration_days,
 'calculation_status',case when calc.method_id is not null then 'EXCEL_FORMULA_VERIFIED_V1' else c.calculation_status end,
 'operational_workflow_enabled',m.method_code='SAND_25C' or calc.method_id is not null,'standard_reference',m.standard_reference) order by m.method_code)
 from plantlab_lab.confirmed_method_contracts c join plantlab_lab.methods m on m.id=c.method_id left join plantlab_lab.vigour_calculation_contracts calc on calc.method_id=m.id),
 'lot_registration',jsonb_build_object('creation_event','FIRST_BIN_ENTRY','owner','PLANT_OFFICER','coding_authority','QA_PRODUCT_SPECIFICATION','coding_format_status','PENDING_OFFICIAL_PRODUCT_SPEC','automatic_code_generation_enabled',false),
 'workflow_note','Four count-based Vigor methods enabled using source Excel rounding/tolerance. RET is not enabled. Actual times/conditions are entered by analyst and checked by independent QA; no automatic protocol certification or lot release.');
end;
$$;

create function plantlab_api.submit_vigour_request(p_lot_id uuid,p_target_lab_site_id uuid,p_method_codes text[],p_submission_id uuid,p_sampling_instruction text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare lot plantlab_core.lots; q plantlab_lab.requests; codes text[]; previous_codes text[]; instruction text:=nullif(btrim(p_sampling_instruction),''); key text; method record; test_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_submission_id is null or coalesce(array_length(p_method_codes,1),0) not between 1 and 4 or array_ndims(p_method_codes)<>1 or length(instruction)>500 then raise exception 'Select1..4 unique enabled methods and a submission ID' using errcode='22023'; end if;
 select array_agg(upper(btrim(x)) order by upper(btrim(x))) into codes from unnest(p_method_codes) x;
 if array_position(codes,null) is not null or (select count(distinct x) from unnest(codes) x)<>array_length(codes,1) or
 (select count(*) from plantlab_lab.vigour_calculation_contracts c join plantlab_lab.methods m on m.id=c.method_id where m.method_code=any(codes) and m.is_active)<>array_length(codes,1) then raise exception 'Invalid, duplicate or disabled Vigor method' using errcode='22023'; end if;
 select l.* into lot from plantlab_core.lots l join plantlab_master.sites s on s.id=l.plant_site_id and s.site_type='PLANT' and s.is_active and s.company_id=l.company_id
 where l.id=p_lot_id and plantlab_platform.has_permission('PLANT','request.create',s.id,l.company_id);
 if not found then raise exception 'Lot outside Plant scope' using errcode='42501'; end if;
 if not exists(select from plantlab_master.sites where id=p_target_lab_site_id and site_type='LAB' and is_active and company_id=lot.company_id) then raise exception 'Target Lab outside company' using errcode='22023'; end if;
 key:='VIGOUR_SUBMIT:'||auth.uid()||':'||p_submission_id;
 perform pg_advisory_xact_lock(hashtextextended(key,0));
 select * into q from plantlab_lab.requests where idempotency_key=key;
 if found then
  select array_agg(m.method_code order by m.method_code) into previous_codes from plantlab_lab.request_items i join plantlab_lab.methods m on m.id=i.requested_method_id where i.request_id=q.id and i.is_active;
  if q.lot_id is distinct from p_lot_id or q.target_lab_site_id is distinct from p_target_lab_site_id or q.sampling_instruction is distinct from instruction or previous_codes is distinct from codes then raise exception 'Submission ID already used with different details' using errcode='23505'; end if;
 else
  select id into strict test_id from plantlab_lab.test_types where test_code='VIGOUR' and is_active;
  insert into plantlab_lab.requests(source_module,lot_id,product_id,request_site_id,target_lab_site_id,requested_by,created_by,sampling_instruction,idempotency_key)
  values('PLANT',lot.id,lot.product_id,lot.plant_site_id,p_target_lab_site_id,auth.uid(),auth.uid(),instruction,key) returning * into q;
  for method in select m.id from plantlab_lab.vigour_calculation_contracts c join plantlab_lab.methods m on m.id=c.method_id where m.method_code=any(codes) order by m.method_code loop
   insert into plantlab_lab.request_items(request_id,test_type_id,requested_method_id,created_by) values(q.id,test_id,method.id,auth.uid());
  end loop;
  select * into q from plantlab_lab.submit_request(q.id);
 end if;
 return jsonb_build_object('request_id',q.id,'request_code',q.request_code,'status',q.status,'methods',codes);
end;
$$;

create function plantlab_lab.lock_vigour_item(p_item uuid,p_role text)
returns table(request_id uuid,request_state text,item_state text,sample_id uuid,receipt_id uuid,incoming_at timestamptz,method_id uuid,test_type_id uuid,lot_id uuid)
language plpgsql set search_path='' as $$
begin
 return query select q.id,q.status,i.status,s.id,r.id,coalesce(r.source_received_at,r.received_at),i.requested_method_id,i.test_type_id,l.id
 from plantlab_lab.request_items i join plantlab_lab.requests q on q.id=i.request_id and q.source_module='PLANT'
 join plantlab_core.lots l on l.id=q.lot_id
 join plantlab_lab.test_types t on t.id=i.test_type_id and t.test_code='VIGOUR' and t.is_active
 join plantlab_lab.vigour_calculation_contracts c on c.method_id=i.requested_method_id
 join plantlab_lab.request_samples rs on rs.request_id=q.id and rs.is_primary
 join plantlab_core.samples s on s.id=rs.sample_id and s.lot_id=l.id and s.status='RECEIVED'
 join plantlab_lab.sample_receipts r on r.request_sample_id=rs.id and r.decision='ACCEPT'
 where i.id=p_item and i.is_active and plantlab_platform.has_exact_scoped_role('LAB',p_role,q.target_lab_site_id,l.company_id)
 for update of q,i;
 if not found then raise exception 'Received Vigor item and scoped Lab role required' using errcode='42501'; end if;
end;
$$;
create function plantlab_lab.replay_vigour_action(p_action uuid,p_command text,p_item uuid,p_payload jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare a plantlab_lab.vigour_actions;
begin
 if p_action is null then raise exception 'Action ID required' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('VIGOUR_ACTION:'||p_action,0));
 select * into a from plantlab_lab.vigour_actions where action_id=p_action;
 if found then
  if a.actor_id is distinct from auth.uid() or a.command is distinct from p_command or a.item_id is distinct from p_item or a.payload is distinct from p_payload then raise exception 'Action ID already used with different details' using errcode='23505'; end if;
  return a.response;
 end if;
 return null;
end;
$$;
create function plantlab_api.start_vigour(p_item_id uuid,p_started_at timestamptz,p_conditions_note text,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare scope record; prior plantlab_lab.test_runs; run plantlab_lab.test_runs; cycle plantlab_lab.test_cycles; assignment uuid; payload jsonb; response jsonb; reason text;
begin
 select * into scope from plantlab_lab.lock_vigour_item(p_item_id,'LAB_ANALYST');
 payload:=jsonb_build_object('started_at',p_started_at,'conditions_note',btrim(p_conditions_note));
 response:=plantlab_lab.replay_vigour_action(p_action_id,'START',p_item_id,payload);
 if response is not null then return response; end if;
 if p_started_at is null or not isfinite(p_started_at) or p_started_at>now() or p_started_at<date_trunc('minute',scope.incoming_at) or coalesce(length(btrim(p_conditions_note)),0) not between 3 and 1000 then raise exception 'Actual start after receipt (minute precision), not in future, and conditions note required' using errcode='22023'; end if;
 select * into prior from plantlab_lab.test_runs where request_item_id=p_item_id and sample_id=scope.sample_id order by attempt_no desc limit 1;
 if found and prior.status<>'RETEST' then raise exception 'Latest run is not a decided retest; do not create duplicates' using errcode='55000'; end if;
 if prior.id is null then
  if scope.item_state<>'REQUESTED' or scope.request_state not in ('RECEIVED','TESTING') then raise exception 'Request not ready for first method run' using errcode='55000'; end if;
  update plantlab_lab.request_items set status='READY',updated_by=auth.uid() where id=p_item_id;
 else
  select d.reason into reason from plantlab_lab.result_decisions d where d.test_run_id=prior.id and d.decision='RETEST' order by d.id desc limit 1;
  if reason is null then raise exception 'QA retest reason required' using errcode='55000'; end if;
  if p_started_at<coalesce(prior.completed_at,prior.started_at) then raise exception 'Retest cannot precede previous final observation' using errcode='22023'; end if;
  perform set_config('app.status_reason',reason,true);
  update plantlab_lab.request_items set status='TESTING',status_reason=reason,updated_by=auth.uid() where id=p_item_id and status='RETEST';
  update plantlab_lab.requests set status='TESTING',status_reason=reason,updated_by=auth.uid() where id=scope.request_id and status='RETEST';
 end if;
 select * into cycle from plantlab_lab.create_test_cycle(scope.request_id,scope.sample_id,case when prior.id is null then 'INITIAL' else 'RETEST' end,prior.test_cycle_id,scope.receipt_id,'VIGOUR',reason,'VIGOUR:'||p_action_id,jsonb_build_object('request_item_id',p_item_id));
 update plantlab_lab.test_cycles set status='ACTIVE',updated_by=auth.uid() where id=cycle.id;
 insert into plantlab_lab.test_assignments(request_item_id,sample_id,analyst_id,method_id,assigned_by) values(p_item_id,scope.sample_id,auth.uid(),scope.method_id,auth.uid()) returning id into assignment;
 update plantlab_lab.test_assignments set status='ACCEPTED',accepted_at=now() where id=assignment;
 update plantlab_lab.test_assignments set status='IN_PROGRESS' where id=assignment;
 insert into plantlab_lab.test_runs(assignment_id,request_item_id,sample_id,method_id,test_cycle_id,attempt_no,retest_of_id,created_by,started_at)
 values(assignment,p_item_id,scope.sample_id,scope.method_id,cycle.id,coalesce(prior.attempt_no,0)+1,prior.id,auth.uid(),p_started_at) returning * into run;
 insert into plantlab_lab.vigour_run_contexts(test_run_id,calculation_method_id,actual_started_at,conditions_note,created_by)
 values(run.id,scope.method_id,p_started_at,btrim(p_conditions_note),auth.uid());
 select * into run from plantlab_lab.advance_test_run(run.id,'IN_PROGRESS');
 perform plantlab_lab.record_test_run_event(run.id,'PLANTED',p_started_at,null,jsonb_build_object('conditions_note',btrim(p_conditions_note),'source','ANALYST_ACTUAL_INPUT'),'VIGOUR_START:'||run.id);
 response:=jsonb_build_object('run_id',run.id,'run_code',run.test_code,'status',run.status,'attempt_no',run.attempt_no);
 insert into plantlab_lab.vigour_actions values(p_action_id,auth.uid(),'START',p_item_id,payload,response,now());
 return response;
end;
$$;

create function plantlab_lab.calculate_vigour_counts(p_replicates jsonb,p_test_type uuid,p_method uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare r jsonb; normal_count int; total_normal int:=0; lo int:=100; hi int:=0; raw_percent numeric; rounded_percent numeric; tolerance numeric;
begin
 perform plantlab_lab.validate_confirmed_germination_counts(p_replicates);
 for r in select value from jsonb_array_elements(p_replicates) loop
  if exists(select from jsonb_object_keys(r) k where k not in ('normal','abnormal','dead')) or jsonb_typeof(r->'normal')<>'number' or jsonb_typeof(r->'abnormal')<>'number' or jsonb_typeof(r->'dead')<>'number' then raise exception 'Only actual integer normal/abnormal/dead counts allowed' using errcode='22023'; end if;
  normal_count:=(r->>'normal')::int; total_normal:=total_normal+normal_count;lo:=least(lo,normal_count);hi:=greatest(hi,normal_count);
 end loop;
 raw_percent:=total_normal/2.0; rounded_percent:=round(raw_percent,0);
 tolerance:=plantlab_lab.get_tolerance_limit(2,rounded_percent,p_test_type,p_method);
 return jsonb_build_object('replicates',p_replicates,'total_tested',200,'unrounded_percent',raw_percent,'vigour_percent',rounded_percent,
 'calculation_code','EXCEL_ROUND_AVERAGE_2X100','calculation_version',1,'gap_pp',hi-lo,'limit_pp',tolerance,'within_tolerance',(hi-lo)<=tolerance,
 'tolerance_status',case when tolerance is null then 'RULE_NOT_AVAILABLE' when hi-lo<=tolerance then 'WITHIN_SOURCE_TOLERANCE' else 'EXCEEDS_SOURCE_TOLERANCE' end,
 'authorizes_lot_release',false);
end;
$$;
create function plantlab_api.submit_vigour(p_run_id uuid,p_observed_at timestamptz,p_replicates jsonb,p_observation_note text,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare item uuid; scope record; run plantlab_lab.test_runs; c plantlab_lab.vigour_run_contexts; payload jsonb; response jsonb; summary jsonb; r jsonb; idx int:=0; parameter uuid;
begin
 select request_item_id into item from plantlab_lab.test_runs where id=p_run_id;
 select * into scope from plantlab_lab.lock_vigour_item(item,'LAB_ANALYST');
 select * into strict run from plantlab_lab.test_runs where id=p_run_id for update;
 if run.performed_by is distinct from auth.uid() then raise exception 'Assigned analyst required' using errcode='42501'; end if;
 payload:=jsonb_build_object('run_id',p_run_id,'observed_at',p_observed_at,'replicates',p_replicates,'observation_note',btrim(p_observation_note));
 response:=plantlab_lab.replay_vigour_action(p_action_id,'SUBMIT',item,payload);
 if response is not null then return response; end if;
 if run.status<>'IN_PROGRESS' then raise exception 'Run not in progress' using errcode='55000'; end if;
 select * into strict c from plantlab_lab.vigour_run_contexts where test_run_id=run.id;
 if p_observed_at is null or not isfinite(p_observed_at) or p_observed_at<c.actual_started_at or p_observed_at>now() or coalesce(length(btrim(p_observation_note)),0) not between 3 and 1000 then raise exception 'Actual final time and observation note required' using errcode='22023'; end if;
 summary:=plantlab_lab.calculate_vigour_counts(p_replicates,scope.test_type_id,scope.method_id)||jsonb_build_object('observed_at',p_observed_at,'observation_note',btrim(p_observation_note),'physical_protocol_verified',false);
 for r in select value from jsonb_array_elements(p_replicates) loop
  idx:=idx+1;
  perform plantlab_lab.save_test_run_observation(run.id,'FINAL',idx,p_observed_at,(r->>'normal')::int,(r->>'abnormal')::int,(r->>'dead')::int);
 end loop;
 select id into strict parameter from plantlab_lab.parameters where parameter_code='VIGOUR_PERCENT';
 insert into plantlab_lab.result_values(test_run_id,parameter_id,numeric_value,unit_code,recorded_by) values(run.id,parameter,(summary->>'vigour_percent')::numeric,'PERCENT',auth.uid());
 perform plantlab_lab.record_test_run_event(run.id,'OBSERVED_FINAL',p_observed_at,null,summary,'VIGOUR_FINAL:'||run.id);
 update plantlab_lab.test_runs set completed_at=p_observed_at where id=run.id;
 perform plantlab_lab.advance_test_run(run.id,'SUBMITTED');
 perform plantlab_lab.record_test_run_event(run.id,'SUBMITTED');
 select * into run from plantlab_lab.advance_test_run(run.id,'IN_REVIEW');
 update plantlab_lab.test_assignments set status='COMPLETED' where id=run.assignment_id;
 update plantlab_lab.test_cycles set status='COMPLETED',updated_by=auth.uid() where id=run.test_cycle_id;
 response:=jsonb_build_object('run_id',run.id,'run_code',run.test_code,'status',run.status,'vigour_percent',summary->'vigour_percent');
 insert into plantlab_lab.vigour_actions values(p_action_id,auth.uid(),'SUBMIT',item,payload,response,now());
 return response;
end;
$$;
create function plantlab_api.review_vigour(p_run_id uuid,p_decision text,p_reason text,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare item uuid; scope record; run plantlab_lab.test_runs; summary jsonb; payload jsonb; response jsonb; d plantlab_lab.result_decisions; choice text:=upper(btrim(p_decision)); reason text:=btrim(p_reason);
begin
 select request_item_id into item from plantlab_lab.test_runs where id=p_run_id;
 select * into scope from plantlab_lab.lock_vigour_item(item,'LAB_QA_APPROVER');
 select * into strict run from plantlab_lab.test_runs where id=p_run_id for update;
 if run.performed_by is null or run.performed_by=auth.uid() then raise exception 'Independent QA required' using errcode='42501'; end if;
 payload:=jsonb_build_object('run_id',p_run_id,'decision',choice,'reason',reason);
 response:=plantlab_lab.replay_vigour_action(p_action_id,'REVIEW',item,payload);
 if response is not null then return response; end if;
 if choice is null or choice not in ('APPROVE','RETEST') or coalesce(length(reason),0) not between 3 and 1000 then raise exception 'APPROVE/RETEST and review reason required' using errcode='22023'; end if;
 if run.status<>'IN_REVIEW' then raise exception 'Run not ready for review' using errcode='55000'; end if;
 select metadata into summary from plantlab_lab.test_run_events where test_run_id=run.id and event_type='OBSERVED_FINAL' and idempotency_key='VIGOUR_FINAL:'||run.id;
 if not found or (choice='APPROVE' and summary->'within_tolerance' is distinct from 'true'::jsonb) then raise exception 'Approval blocked: missing/exceeded source tolerance; review or retest required' using errcode='23514'; end if;
 select * into d from plantlab_lab.decide_test_run(run.id,choice,reason,jsonb_build_object('review_scope','ANALYTICAL_RESULT_NOT_LOT_RELEASE','protocol_checked_by_reviewer',true));
 response:=jsonb_build_object('run_id',run.id,'run_code',run.test_code,'status',d.resulting_status);
 insert into plantlab_lab.vigour_actions values(p_action_id,auth.uid(),'REVIEW',item,payload,response,now());
 return response;
end;
$$;

create function plantlab_api.list_vigour_runs(p_request_ids uuid[],p_module text)
returns table(request_id uuid,item_id uuid,method_code text,method_name text,item_status text,run_id uuid,run_code text,status text,attempt_no int,actual_started_at timestamptz,conditions_note text,summary jsonb,decision_reason text,prior_attempts jsonb,is_assigned_analyst boolean)
language sql stable security definer set search_path='' as $$
 select q.id,i.id,m.method_code,m.method_name,i.status,run.id,run.test_code,run.status,run.attempt_no,
 case when upper(p_module)='LAB' or run.status='APPROVED' then c.actual_started_at end,
 case when upper(p_module)='LAB' or run.status='APPROVED' then c.conditions_note end,
 case when upper(p_module)='LAB' or run.status='APPROVED' then e.metadata end,
 case when upper(p_module)='LAB' or run.status='APPROVED' then d.reason end,
 case when upper(p_module)='LAB' then (select coalesce(jsonb_agg(jsonb_build_object('run_code',old.test_code,'attempt_no',old.attempt_no,'status',old.status,'summary',oe.metadata) order by old.attempt_no),'[]') from plantlab_lab.test_runs old left join plantlab_lab.test_run_events oe on oe.test_run_id=old.id and oe.idempotency_key='VIGOUR_FINAL:'||old.id where old.request_item_id=i.id and old.id<>run.id) else '[]'::jsonb end,
 coalesce(upper(p_module)='LAB' and run.performed_by=auth.uid(),false)
 from plantlab_lab.requests q join plantlab_core.lots l on l.id=q.lot_id
 join plantlab_lab.request_items i on i.request_id=q.id and i.is_active
 join plantlab_lab.vigour_calculation_contracts calc on calc.method_id=i.requested_method_id
 join plantlab_lab.methods m on m.id=calc.method_id
 left join lateral(select r.* from plantlab_lab.test_runs r where r.request_item_id=i.id order by r.attempt_no desc limit 1) run on true
 left join plantlab_lab.vigour_run_contexts c on c.test_run_id=run.id
 left join plantlab_lab.test_run_events e on e.test_run_id=run.id and e.idempotency_key='VIGOUR_FINAL:'||run.id
 left join lateral(select rd.reason from plantlab_lab.result_decisions rd where rd.test_run_id=run.id order by rd.id desc limit 1) d on true
 where q.id=any(p_request_ids[1:50]) and q.source_module='PLANT' and auth.uid() is not null and
 case upper(btrim(p_module)) when 'LAB' then plantlab_platform.has_permission('LAB','result.read',q.target_lab_site_id,l.company_id)
 when 'PLANT' then plantlab_platform.has_permission('PLANT','request.read',q.request_site_id,l.company_id) else false end
 order by q.id,m.method_code;
$$;

revoke all on function plantlab_lab.lock_vigour_item(uuid,text),plantlab_lab.replay_vigour_action(uuid,text,uuid,jsonb),plantlab_lab.calculate_vigour_counts(jsonb,uuid,uuid) from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_api.get_vigour_workflow_options(),plantlab_api.submit_vigour_request(uuid,uuid,text[],uuid,text),plantlab_api.start_vigour(uuid,timestamptz,text,uuid),plantlab_api.submit_vigour(uuid,timestamptz,jsonb,text,uuid),plantlab_api.review_vigour(uuid,text,text,uuid),plantlab_api.list_vigour_runs(uuid[],text) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_vigour_workflow_options(),plantlab_api.submit_vigour_request(uuid,uuid,text[],uuid,text),plantlab_api.start_vigour(uuid,timestamptz,text,uuid),plantlab_api.submit_vigour(uuid,timestamptz,jsonb,text,uuid),plantlab_api.review_vigour(uuid,text,text,uuid),plantlab_api.list_vigour_runs(uuid[],text) to authenticated;
notify pgrst,'reload schema';
commit;
