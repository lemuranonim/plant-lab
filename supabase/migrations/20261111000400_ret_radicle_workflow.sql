-- Owner-confirmed RET, prospective only. Keep old APKs on four-method RPCs.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';
alter table plantlab_lab.vigour_calculation_contracts drop constraint vigour_calculation_contracts_calculation_code_check;
alter table plantlab_lab.vigour_calculation_contracts add constraint vigour_calculation_contracts_calculation_code_check
 check(calculation_code in ('EXCEL_ROUND_AVERAGE_2X100','RET_RADICLE_4X100_V1'));
create table plantlab_lab.ret_tolerance_confirmations (
 method_id uuid not null references plantlab_lab.methods(id),version int not null check(version>0),
 tolerance_replicates int not null check(tolerance_replicates=4),
 source_reference text not null,source_sha256 text not null,source_note text not null,
 effective_from timestamptz not null default now(),primary key(method_id,version)
);
insert into plantlab_lab.ret_tolerance_confirmations
select id,1,4,'Germ/Vigor03.11.2026 / TOLERATED DIFF!D3:E100',
 'f32f9ee5c29c8c96144be99d5717033052cf4a1ebc688458195e794ee3b1bb31',
 'Owner11Nov2026 confirms RET uses same replicate tolerance logic;4x100 uses4-Reps table. Missing0/1/100 endpoints remain unavailable.',now()
from plantlab_lab.methods where method_code='RET_16C_72H' and version=1;
insert into plantlab_lab.vigour_calculation_contracts
select m.id,c.id,1,'RET_RADICLE_4X100_V1','RET radicle>=2mm count/400*100. Exact percent retained; integer-rounded percent for existing4-Reps lookup only.',
 'f32f9ee5c29c8c96144be99d5717033052cf4a1ebc688458195e794ee3b1bb31',now()
from plantlab_lab.methods m join plantlab_lab.confirmed_method_contracts c on c.method_id=m.id
where m.method_code='RET_16C_72H' and m.version=1;
create table plantlab_lab.ret_run_protocols (
 test_run_id uuid primary key references plantlab_lab.vigour_run_contexts(test_run_id),
 method_id uuid not null,protocol_version int not null,tolerance_version int not null,
 minimum_radicle_mm numeric not null check(minimum_radicle_mm=2),
 duration_hours int not null check(duration_hours=72),temperature_celsius numeric not null check(temperature_celsius=16),
 tolerance_replicates int not null check(tolerance_replicates=4),
 created_at timestamptz not null default now(),
 foreign key(method_id,protocol_version) references plantlab_lab.ret_protocol_confirmations(method_id,version),
 foreign key(method_id,tolerance_version) references plantlab_lab.ret_tolerance_confirmations(method_id,version)
);
create table plantlab_lab.ret_radicle_observations (
 test_run_id uuid not null references plantlab_lab.ret_run_protocols(test_run_id),
 replicate_no int not null check(replicate_no between 1 and 4),
 tested int not null check(tested=100),radicle_at_least_2mm int not null check(radicle_at_least_2mm between 0 and 100),
 observed_at timestamptz not null,recorded_by uuid not null references plantlab_platform.identities(id),
 recorded_at timestamptz not null default now(),primary key(test_run_id,replicate_no)
);
alter table plantlab_lab.ret_tolerance_confirmations enable row level security;
alter table plantlab_lab.ret_run_protocols enable row level security;
alter table plantlab_lab.ret_radicle_observations enable row level security;
revoke all on plantlab_lab.ret_tolerance_confirmations,plantlab_lab.ret_run_protocols,plantlab_lab.ret_radicle_observations from PUBLIC,anon,authenticated,service_role;
create trigger ret_tolerance_immutable before update or delete on plantlab_lab.ret_tolerance_confirmations for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger ret_run_protocols_immutable before update or delete on plantlab_lab.ret_run_protocols for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger ret_observations_immutable before update or delete on plantlab_lab.ret_radicle_observations for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_lab.snapshot_ret_run_protocol()
returns trigger language plpgsql security definer set search_path='' as $$
declare p plantlab_lab.ret_protocol_confirmations; t plantlab_lab.ret_tolerance_confirmations;
begin
 if not exists(select from plantlab_lab.vigour_calculation_contracts c where c.method_id=new.calculation_method_id and c.calculation_code='RET_RADICLE_4X100_V1') then return new; end if;
 select * into strict p from plantlab_lab.ret_protocol_confirmations where method_id=new.calculation_method_id order by version desc limit 1;
 select * into strict t from plantlab_lab.ret_tolerance_confirmations where method_id=new.calculation_method_id order by version desc limit 1;
 insert into plantlab_lab.ret_run_protocols(test_run_id,method_id,protocol_version,tolerance_version,minimum_radicle_mm,duration_hours,temperature_celsius,tolerance_replicates)
 values(new.test_run_id,new.calculation_method_id,p.version,t.version,p.minimum_radicle_mm,p.duration_hours,p.temperature_celsius,t.tolerance_replicates);
 return new;
end;
$$;
create trigger ret_protocol_snapshot after insert on plantlab_lab.vigour_run_contexts for each row execute function plantlab_lab.snapshot_ret_run_protocol();
create function plantlab_lab.guard_ret_observation_input()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not exists(select from plantlab_lab.test_runs r join plantlab_lab.ret_run_protocols p on p.test_run_id=r.id and p.method_id=r.method_id
 join plantlab_lab.vigour_run_contexts c on c.test_run_id=r.id
 where r.id=new.test_run_id and r.status='IN_PROGRESS' and r.performed_by=auth.uid()
 and new.observed_at>=c.actual_started_at+make_interval(hours=>p.duration_hours) and new.observed_at<=now()) then
 raise exception 'RET observations require assigned analyst,open run and at least72hours since placement16C' using errcode='23514'; end if;
 return new;
end;
$$;
create trigger ret_observation_input before insert on plantlab_lab.ret_radicle_observations for each row execute function plantlab_lab.guard_ret_observation_input();
create function plantlab_lab.calculate_ret_observations(p_replicates jsonb,p_test_type uuid,p_method uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare r jsonb; eligible int; sum_eligible int:=0; lo int:=100; hi int:=0; percent_value numeric; tolerance numeric;
begin
 if jsonb_typeof(p_replicates) is distinct from 'array' then raise exception 'RET requires4replicates of100seeds' using errcode='22023'; end if;
 if jsonb_array_length(p_replicates)<>4 then raise exception 'RET requires4replicates of100seeds' using errcode='22023'; end if;
 for r in select value from jsonb_array_elements(p_replicates) loop
  if jsonb_typeof(r) is distinct from 'object' or jsonb_typeof(r->'tested') is distinct from 'number' or r->>'tested'<>'100'
  or jsonb_typeof(r->'radicle_at_least_2mm') is distinct from 'number' or coalesce(r->>'radicle_at_least_2mm','') !~ '^[0-9]{1,3}$'
  or exists(select from jsonb_object_keys(r) k where k not in ('tested','radicle_at_least_2mm')) then
   raise exception 'RET needs tested100 and integer radicle_at_least_2mm; never normal/abnormal/dead' using errcode='22023'; end if;
  eligible:=(r->>'radicle_at_least_2mm')::int;
  if eligible>100 then raise exception 'RET eligible count exceeds100' using errcode='22023'; end if;
  sum_eligible:=sum_eligible+eligible;lo:=least(lo,eligible);hi:=greatest(hi,eligible);
 end loop;
 percent_value:=round(sum_eligible/4.0,2);
 tolerance:=plantlab_lab.get_tolerance_limit(4,percent_value,p_test_type,p_method);
 return jsonb_build_object('replicates',p_replicates,'observation_kind','RADICLE_AT_LEAST_2MM','replicate_count',4,
 'total_tested',400,'total_radicle_at_least_2mm',sum_eligible,'minimum_radicle_mm',2,'ret_percent',percent_value,
 'vigour_percent',percent_value,'unrounded_percent',percent_value,'tolerance_lookup_percent',round(percent_value,0),
 'calculation_code','RET_RADICLE_4X100_V1','calculation_version',1,'tolerance_replicates',4,'gap_pp',hi-lo,'limit_pp',tolerance,
 'within_tolerance',(hi-lo)<=tolerance,'tolerance_status',case when tolerance is null then 'RULE_NOT_AVAILABLE' when hi-lo<=tolerance then 'WITHIN_SOURCE_TOLERANCE' else 'EXCEEDS_SOURCE_TOLERANCE' end,
 'authorizes_lot_release',false);
end;
$$;

create or replace function plantlab_api.submit_vigour_request(p_lot_id uuid,p_target_lab_site_id uuid,p_method_codes text[],p_submission_id uuid,p_sampling_instruction text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare lot plantlab_core.lots; q plantlab_lab.requests; codes text[]; previous_codes text[]; instruction text:=nullif(btrim(p_sampling_instruction),''); key text; method record; test_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_submission_id is null or coalesce(array_length(p_method_codes,1),0) not between 1 and 5 or array_ndims(p_method_codes)<>1 or length(instruction)>500 then raise exception 'Select1..5 unique enabled methods and a submission ID' using errcode='22023'; end if;
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

create or replace function plantlab_api.start_vigour(p_item_id uuid,p_started_at timestamptz,p_conditions_note text,p_action_id uuid)
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
 perform plantlab_lab.record_test_run_event(run.id,'PLANTED',p_started_at,null,jsonb_build_object('conditions_note',btrim(p_conditions_note),'source','ANALYST_ACTUAL_INPUT','duration_start_event',case when exists(select from plantlab_lab.ret_run_protocols where test_run_id=run.id) then 'PLACED_AT_16C' else 'PLANTED' end),'VIGOUR_START:'||run.id);
 response:=jsonb_build_object('run_id',run.id,'run_code',run.test_code,'status',run.status,'attempt_no',run.attempt_no);
 insert into plantlab_lab.vigour_actions values(p_action_id,auth.uid(),'START',p_item_id,payload,response,now());
 return response;
end;
$$;

create or replace function plantlab_api.submit_vigour(p_run_id uuid,p_observed_at timestamptz,p_replicates jsonb,p_observation_note text,p_action_id uuid)
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
 if exists(select from plantlab_lab.ret_run_protocols where test_run_id=run.id) then
  if p_observed_at<c.actual_started_at+interval'72hours' then raise exception 'RET final observation is earlier than72hours after placement16C' using errcode='22023'; end if;
  summary:=plantlab_lab.calculate_ret_observations(p_replicates,scope.test_type_id,scope.method_id)
   ||jsonb_build_object('observed_at',p_observed_at,'observation_note',btrim(p_observation_note),'physical_protocol_verified',false,
    'duration_start_event','PLACED_AT_16C','minimum_duration_hours',72,'elapsed_hours',extract(epoch from(p_observed_at-c.actual_started_at))/3600.0,'elapsed_requirement_met',true,
    'protocol_snapshot',(select to_jsonb(p)-'created_at' from plantlab_lab.ret_run_protocols p where p.test_run_id=run.id));
  for r in select value from jsonb_array_elements(p_replicates) loop
   idx:=idx+1;
   insert into plantlab_lab.ret_radicle_observations(test_run_id,replicate_no,tested,radicle_at_least_2mm,observed_at,recorded_by)
   values(run.id,idx,100,(r->>'radicle_at_least_2mm')::int,p_observed_at,auth.uid());
  end loop;
 else
 summary:=plantlab_lab.calculate_vigour_counts(p_replicates,scope.test_type_id,scope.method_id)||jsonb_build_object('observed_at',p_observed_at,'observation_note',btrim(p_observation_note),'physical_protocol_verified',false);
 for r in select value from jsonb_array_elements(p_replicates) loop
  idx:=idx+1;
  perform plantlab_lab.save_test_run_observation(run.id,'FINAL',idx,p_observed_at,(r->>'normal')::int,(r->>'abnormal')::int,(r->>'dead')::int);
 end loop;
 end if;
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

create or replace function plantlab_lab.validate_test_run_workflow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_missing_required integer;
  v_item_status text;
  v_request_status text;
  v_requires_observations boolean;
begin
  if old.status = 'IN_REVIEW'
    and new.status in ('APPROVED', 'REJECTED', 'RETEST')
    and current_setting('app.result_decision_context', true) is distinct from 'on' then
    raise exception 'Final Test Run status can only be set through plantlab_lab.result_decisions'
      using errcode = '42501';
  end if;

  if new.status = 'IN_PROGRESS' and old.status is distinct from new.status then
    select ri.status, r.status
      into v_item_status, v_request_status
    from plantlab_lab.request_items ri
    join plantlab_lab.requests r on r.id = ri.request_id
    where ri.id = new.request_item_id;

    if v_item_status not in ('READY', 'TESTING')
      or v_request_status not in ('RECEIVED', 'TESTING') then
      raise exception 'Lab Request and item must be received/ready before testing starts'
        using errcode = '23514';
    end if;

    new.started_at := coalesce(new.started_at, now());
    new.performed_by := coalesce(new.performed_by, auth.uid());
  end if;

  if new.status = 'SUBMITTED' and old.status is distinct from new.status then
    select ri.status into v_item_status
    from plantlab_lab.request_items ri
    where ri.id = new.request_item_id;

    if v_item_status <> 'TESTING' then
      raise exception 'Lab Request item must be TESTING before a Test Run is submitted'
        using errcode = '23514';
    end if;

    select count(*)::integer
      into v_missing_required
    from plantlab_lab.request_items ri
    join plantlab_lab.test_type_parameters ttp
      on ttp.test_type_id = ri.test_type_id and ttp.is_required
    left join plantlab_lab.result_values rv
      on rv.test_run_id = new.id and rv.parameter_id = ttp.parameter_id
    where ri.id = new.request_item_id
      and rv.id is null;

    if v_missing_required > 0 then
      raise exception 'Cannot submit Test Run: % required result parameter(s) are missing',
        v_missing_required using errcode = '23514';
    end if;

    select coalesce(mtt.requires_replicate_observations, false)
      into v_requires_observations
    from plantlab_lab.method_test_types mtt
    where mtt.method_id = new.method_id
      and mtt.test_type_id = (
        select ri.test_type_id
        from plantlab_lab.request_items ri
        where ri.id = new.request_item_id
      );

    if coalesce(v_requires_observations, false) then
      if exists(select from plantlab_lab.methods m where m.id=new.method_id and m.method_code='RET_16C_72H') then
        if not exists(select from plantlab_lab.ret_run_protocols p where p.test_run_id=new.id and p.method_id=new.method_id)
          or (select count(*) from plantlab_lab.ret_radicle_observations o where o.test_run_id=new.id and o.tested=100)<>4 then
          raise exception 'RET requires four dedicated radicle observations and protocol snapshot' using errcode='23514';
        end if;
      else
      if not exists (
        select 1
        from plantlab_lab.test_run_observations tro
        where tro.test_run_id = new.id
          and tro.observation_phase = 'FINAL'
      ) then
        raise exception 'Cannot submit Test Run: final replicate observations are missing'
          using errcode = '23514';
      end if;
      end if;

      if not exists (
        select 1
        from plantlab_lab.test_run_events tre
        where tre.test_run_id = new.id
          and tre.event_type = 'OBSERVED_FINAL'
      ) then
        raise exception 'Cannot submit Test Run: OBSERVED_FINAL event is missing'
          using errcode = '23514';
      end if;
    end if;

    new.completed_at := coalesce(new.completed_at, now());
    new.submitted_at := coalesce(new.submitted_at, now());
  end if;

  return new;
end;
$$;

create or replace function plantlab_api.list_vigour_runs_v2(p_request_ids uuid[],p_module text)
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

create or replace function plantlab_api.list_vigour_runs(p_request_ids uuid[],p_module text)
returns table(request_id uuid,item_id uuid,method_code text,method_name text,item_status text,run_id uuid,run_code text,status text,attempt_no int,actual_started_at timestamptz,conditions_note text,summary jsonb,decision_reason text,prior_attempts jsonb,is_assigned_analyst boolean)
language sql stable security definer set search_path='' as $$
 select * from plantlab_api.list_vigour_runs_v2(p_request_ids,p_module) where method_code<>'RET_16C_72H';
$$;

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
 from plantlab_lab.confirmed_method_contracts c join plantlab_lab.methods m on m.id=c.method_id left join plantlab_lab.vigour_calculation_contracts calc on calc.method_id=m.id and calc.calculation_code='EXCEL_ROUND_AVERAGE_2X100'),
 'lot_registration',jsonb_build_object('creation_event','FIRST_BIN_ENTRY','owner','PLANT_OFFICER','coding_authority','QA_PRODUCT_SPECIFICATION','coding_format_status','PENDING_OFFICIAL_PRODUCT_SPEC','automatic_code_generation_enabled',false),
 'workflow_note','Four count-based Vigor methods enabled using source Excel rounding/tolerance. RET is available through v2 capability/read RPCs; legacy clients retain four-method forms. Actual times/conditions are entered by analyst and checked by independent QA; no automatic protocol certification or lot release.');
end;
$$;

create or replace function plantlab_api.get_vigour_workflow_options()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform plantlab_lab.require_contract_reader();
 return jsonb_build_object('version',2,'client_contract','LEGACY_FOUR_METHODS','methods',(select jsonb_agg(jsonb_build_object('method_code',m.method_code,'method_name',m.method_name,'replicate_count',2,'seeds_per_replicate',100,'procedure_summary',m.procedure_summary) order by m.method_code)
 from plantlab_lab.vigour_calculation_contracts c join plantlab_lab.methods m on m.id=c.method_id where m.is_active and c.calculation_code='EXCEL_ROUND_AVERAGE_2X100'),
 'ret_enabled',false,'ret_protocol',(select to_jsonb(p) from plantlab_lab.ret_protocol_confirmations p order by p.version desc limit 1),
 'ret_pending','Update to RET-capable client using get_vigour_workflow_options_v2; legacy forms are not radicle forms.','authorizes_lot_release',false);
end;
$$;
create function plantlab_api.get_vigour_workflow_options_v2()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform plantlab_lab.require_contract_reader();
 return jsonb_build_object('version',3,'client_contract','RADICLE_RET_V2','methods',(select jsonb_agg(jsonb_build_object(
 'method_code',m.method_code,'method_name',m.method_name,'replicate_count',i.replicate_count,'seeds_per_replicate',i.seeds_per_replicate,
 'observation_kind',i.observation_kind,'procedure_summary',m.procedure_summary) order by m.method_code)
 from plantlab_lab.vigour_calculation_contracts c join plantlab_lab.methods m on m.id=c.method_id join plantlab_lab.confirmed_method_contracts i on i.id=c.input_contract_id where m.is_active),
 'ret_enabled',true,'ret_protocol',(select to_jsonb(p) from plantlab_lab.ret_protocol_confirmations p order by p.version desc limit 1),
 'ret_tolerance',(select to_jsonb(t) from plantlab_lab.ret_tolerance_confirmations t order by t.version desc limit 1),
 'calculation_note','RET radicle count/400*100 retained precisely;4-Reps lookup rounds percent to integer. Other methods keep Excel ROUND(AVERAGE(2x100),0). Missing tolerance blocks approval.','authorizes_lot_release',false);
end;
$$;

revoke all on function plantlab_lab.snapshot_ret_run_protocol(),plantlab_lab.guard_ret_observation_input(),plantlab_lab.calculate_ret_observations(jsonb,uuid,uuid) from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_api.get_vigour_workflow_options_v2(),plantlab_api.list_vigour_runs_v2(uuid[],text) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_vigour_workflow_options_v2(),plantlab_api.list_vigour_runs_v2(uuid[],text) to authenticated;
notify pgrst,'reload schema';
commit;
