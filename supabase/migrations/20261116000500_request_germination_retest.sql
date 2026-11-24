-- Controlled request Germination retest; preserve every earlier run/result/decision.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';

create function plantlab_lab.require_current_germination_attempt(p_request_id uuid,p_run_code text,p_role text)
returns void language plpgsql set search_path='' as $$
declare scope record;code text;
begin
 select * into scope from plantlab_lab.lock_germination_preview(p_request_id,p_role);
 select r.test_code into code from plantlab_lab.test_runs r join plantlab_lab.methods m on m.id=r.method_id and m.method_code='SAND_25C'
 where r.request_item_id=scope.item_id and r.sample_id=scope.sample_id order by r.attempt_no desc limit 1;
 if code is null or code is distinct from p_run_code then raise exception 'Current Germination attempt changed; reload before saving' using errcode='40001';end if;
end;
$$;

-- Reuse the installed, tested calculation/review body, binding writes to an exact
-- current run rather than attempt1. Fail closed if the expected source differs.
do $$declare body text;needle text;guard text;name text;role_name text;signature text;
begin
 select prosrc into strict body from pg_proc where oid='plantlab_api.submit_germination(uuid,jsonb)'::regprocedure;
 needle:='and tr.attempt_no = 1 and m.method_code = ''SAND_25C''';
 if strpos(body,needle)=0 then raise exception 'Unexpected submit_germination source';end if;
 body:=replace(body,needle,'and tr.test_code = p_run_code and m.method_code = ''SAND_25C''');
 needle:='select * into v_scope from plantlab_lab.lock_germination_preview(p_request_id, ''LAB_ANALYST'');';
 if strpos(body,needle)=0 then raise exception 'Unexpected submit scope';end if;
 body:=replace(body,needle,needle||E'\n  perform plantlab_lab.require_current_germination_attempt(p_request_id,p_run_code,''LAB_ANALYST'');');
 execute 'create function plantlab_api.submit_germination_attempt(p_request_id uuid,p_run_code text,p_replicates jsonb) returns jsonb language plpgsql security definer set search_path='''' as '||quote_literal(body);

 select prosrc into strict body from pg_proc where oid='plantlab_api.review_germination(uuid,text,text)'::regprocedure;
 needle:='and tr.attempt_no = 1;';
 if strpos(body,needle)=0 then raise exception 'Unexpected review_germination source';end if;
 body:=replace(body,needle,'and tr.test_code = p_run_code;');
 needle:='select * into v_scope from plantlab_lab.lock_germination_preview(p_request_id, ''LAB_QA_APPROVER'');';
 if strpos(body,needle)=0 then raise exception 'Unexpected review scope';end if;
 body:=replace(body,needle,needle||E'\n  perform plantlab_lab.require_current_germination_attempt(p_request_id,p_run_code,''LAB_QA_APPROVER'');');
 execute 'create function plantlab_api.review_germination_attempt(p_request_id uuid,p_run_code text,p_decision text,p_reason text default null) returns jsonb language plpgsql security definer set search_path='''' as '||quote_literal(body);

 -- Old installed clients remain valid for first attempts. After a retest exists,
 -- fail clearly instead of silently replaying the first run against a new screen.
 for name,role_name,signature in select * from(values
  ('start_germination','LAB_ANALYST','plantlab_api.start_germination(uuid)'),
  ('submit_germination','LAB_ANALYST','plantlab_api.submit_germination(uuid,jsonb)'),
  ('review_germination','LAB_QA_APPROVER','plantlab_api.review_germination(uuid,text,text)'))x(n,r,s) loop
  select prosrc into strict body from pg_proc where oid=signature::regprocedure;
  needle:='select * into v_scope from plantlab_lab.lock_germination_preview(p_request_id, '''||role_name||''');';
  if strpos(body,needle)=0 then raise exception 'Unexpected legacy scope: %',name;end if;
  guard:=E'\n  if exists(select from plantlab_lab.test_runs r where r.request_item_id=v_scope.item_id and r.sample_id=v_scope.sample_id and r.attempt_no>1) then raise exception ''Update Lab application and reload the current Germination attempt'' using errcode=''55000'';end if;';
  execute replace(pg_get_functiondef(signature::regprocedure),body,replace(body,needle,needle||guard));
 end loop;
end $$;

create function plantlab_api.start_germination_retest(p_request_id uuid,p_prior_run_code text,p_sample_available boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare scope record;prior plantlab_lab.test_runs;latest plantlab_lab.test_runs;child plantlab_lab.test_runs;
 decision plantlab_lab.result_decisions;cycle plantlab_lab.test_cycles;assignment uuid;run plantlab_lab.test_runs;
begin
 select * into scope from plantlab_lab.lock_germination_preview(p_request_id,'LAB_ANALYST');
 if p_sample_available is distinct from true then raise exception 'Confirm the same physical sample is available before starting retest' using errcode='22023';end if;
 select r.* into prior from plantlab_lab.test_runs r join plantlab_lab.methods m on m.id=r.method_id and m.method_code='SAND_25C'
 where r.request_item_id=scope.item_id and r.sample_id=scope.sample_id and r.test_code=p_prior_run_code;
 if not found then raise exception 'Prior Germination attempt outside request scope' using errcode='42501';end if;
 select * into child from plantlab_lab.test_runs where request_item_id=scope.item_id and sample_id=scope.sample_id and retest_of_id=prior.id order by attempt_no limit 1;
 if found then
  if child.performed_by is distinct from auth.uid() then raise exception 'Retest already assigned to another analyst' using errcode='42501';end if;
  return jsonb_build_object('run_code',child.test_code,'status',child.status,'attempt_no',child.attempt_no,'replayed',true);
 end if;
 select * into latest from plantlab_lab.test_runs where request_item_id=scope.item_id and sample_id=scope.sample_id order by attempt_no desc limit 1;
 if latest.id is distinct from prior.id then raise exception 'Current attempt changed; reload' using errcode='40001';end if;
 select * into decision from plantlab_lab.result_decisions where test_run_id=prior.id order by id desc limit 1;
 if prior.status<>'RETEST' or scope.request_state<>'RETEST' or scope.item_state<>'RETEST'
  or decision.decision is distinct from 'RETEST' or decision.resulting_status is distinct from 'RETEST'
  or nullif(btrim(decision.reason),'') is null or prior.performed_by is null or decision.reviewer_id=prior.performed_by then
  raise exception 'Latest independent QA retest decision and reason required' using errcode='55000';end if;
 if now()<decision.decided_at or now()<prior.completed_at then raise exception 'Retest must begin after QA decision; retry with a new action' using errcode='22023';end if;
 if not exists(select from plantlab_lab.methods m where m.id=prior.method_id and m.is_active) then raise exception 'Saved method is no longer active; coordinator review required' using errcode='55000';end if;
 perform set_config('app.status_reason',decision.reason,true);
 update plantlab_lab.request_items set status='TESTING',status_reason=decision.reason,updated_by=auth.uid() where id=scope.item_id;
 update plantlab_lab.requests set status='TESTING',status_reason=decision.reason,updated_by=auth.uid() where id=p_request_id;
 select * into cycle from plantlab_lab.create_test_cycle(p_request_id,scope.sample_id,'RETEST',prior.test_cycle_id,scope.receipt_id,'GERMINATION',decision.reason,'GERMINATION_RETEST:'||prior.id,jsonb_build_object('prior_run_id',prior.id,'qa_decision_id',decision.id));
 update plantlab_lab.test_cycles set status='ACTIVE',updated_by=auth.uid() where id=cycle.id;
 insert into plantlab_lab.test_assignments(request_item_id,sample_id,analyst_id,method_id,assigned_by)
 values(scope.item_id,scope.sample_id,auth.uid(),prior.method_id,auth.uid()) returning id into assignment;
 update plantlab_lab.test_assignments set status='ACCEPTED',accepted_at=now() where id=assignment;
 update plantlab_lab.test_assignments set status='IN_PROGRESS' where id=assignment;
 insert into plantlab_lab.test_runs(assignment_id,request_item_id,sample_id,method_id,test_cycle_id,attempt_no,retest_of_id,created_by)
 values(assignment,scope.item_id,scope.sample_id,prior.method_id,cycle.id,prior.attempt_no+1,prior.id,auth.uid()) returning * into run;
 select * into run from plantlab_lab.advance_test_run(run.id,'IN_PROGRESS');
 perform plantlab_lab.record_test_run_event(run.id,'OTHER',now(),null,jsonb_build_object('meaning','RETEST_RECORDING_STARTED','time_basis','APPLICATION_EVENT_TIME','sample_available_confirmed',true,'prior_run_id',prior.id,'qa_decision_id',decision.id),'GERMINATION_RETEST_START:'||run.id);
 return jsonb_build_object('run_code',run.test_code,'status',run.status,'attempt_no',run.attempt_no,'replayed',false);
end;
$$;

create function plantlab_api.list_germination_runs_v2(p_request_ids uuid[],p_module text)
returns table(request_id uuid,run_code text,status text,summary jsonb,decision text,decision_reason text,run_id uuid,attempt_no int,is_assigned_analyst boolean,prior_attempts jsonb)
language sql stable security definer set search_path='' as $$
 select q.id,r.test_code,r.status,e.metadata,d.decision,d.reason,r.id,r.attempt_no,
  coalesce(upper(btrim(p_module))='LAB' and r.performed_by=auth.uid(),false),
  case when upper(btrim(p_module))='LAB' then (select coalesce(jsonb_agg(jsonb_build_object('run_code',old.test_code,'attempt_no',old.attempt_no,'status',old.status,'summary',oe.metadata,'decision_reason',od.reason) order by old.attempt_no),'[]'::jsonb)
   from plantlab_lab.test_runs old left join plantlab_lab.test_run_events oe on oe.test_run_id=old.id and oe.idempotency_key='GERMINATION_FINAL:'||old.id
   left join lateral(select reason from plantlab_lab.result_decisions where test_run_id=old.id order by id desc limit 1)od on true
   where old.request_item_id=i.id and old.sample_id=rs.sample_id and old.id<>r.id) else '[]'::jsonb end
 from plantlab_lab.requests q join plantlab_core.lots l on l.id=q.lot_id
 join plantlab_master.sites lab on lab.id=q.target_lab_site_id and lab.is_active and lab.site_type='LAB' and lab.company_id=l.company_id
 join plantlab_lab.request_items i on i.request_id=q.id and i.is_active
 join plantlab_lab.test_types tt on tt.id=i.test_type_id and tt.test_code='GERMINATION'
 join plantlab_lab.request_samples rs on rs.request_id=q.id and rs.is_primary
 join lateral(select tr.* from plantlab_lab.test_runs tr join plantlab_lab.methods m on m.id=tr.method_id and m.method_code='SAND_25C'
  where tr.request_item_id=i.id and tr.sample_id=rs.sample_id order by tr.attempt_no desc limit 1)r on true
 left join plantlab_lab.test_run_events e on e.test_run_id=r.id and e.idempotency_key='GERMINATION_FINAL:'||r.id
 left join lateral(select rd.decision,rd.reason from plantlab_lab.result_decisions rd where rd.test_run_id=r.id order by rd.id desc limit 1)d on true
 where q.id=any(p_request_ids[1:50]) and q.source_module='PLANT' and auth.uid() is not null
 and case upper(btrim(p_module)) when 'LAB' then plantlab_platform.has_permission('LAB','result.read',q.target_lab_site_id,l.company_id)
 when 'PLANT' then r.status='APPROVED' and plantlab_platform.has_permission('PLANT','result.read',q.request_site_id,l.company_id) else false end;
$$;
-- Preserve the old read signature so already-installed Plant clients see the
-- latest approved attempt, never a rejected/unfinished first attempt as final.
create or replace function plantlab_api.list_germination_runs(p_request_ids uuid[],p_module text)
returns table(request_id uuid,run_code text,status text,summary jsonb,decision text,decision_reason text)
language sql stable security definer set search_path='' as $$
 select r.request_id,r.run_code,r.status,r.summary,r.decision,r.decision_reason from plantlab_api.list_germination_runs_v2(p_request_ids,p_module)r;
$$;
revoke all on function plantlab_lab.require_current_germination_attempt(uuid,text,text) from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_api.start_germination_retest(uuid,text,boolean),plantlab_api.submit_germination_attempt(uuid,text,jsonb),plantlab_api.review_germination_attempt(uuid,text,text,text),plantlab_api.list_germination_runs_v2(uuid[],text) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.start_germination_retest(uuid,text,boolean),plantlab_api.submit_germination_attempt(uuid,text,jsonb),plantlab_api.review_germination_attempt(uuid,text,text,text),plantlab_api.list_germination_runs_v2(uuid[],text) to authenticated;
notify pgrst,'reload schema';
commit;
