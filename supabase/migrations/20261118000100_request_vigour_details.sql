-- Prospective ordinary Vigor request capture. Old runs/results are not backfilled.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';

create table plantlab_lab.request_vigour_details (
 run_id uuid primary key references plantlab_lab.test_runs(id),revision int not null check(revision>0),
 content jsonb not null,created_by uuid not null references plantlab_platform.identities(id),
 submitted_revision int,submitted_at timestamptz,updated_at timestamptz not null default now(),
 check((submitted_revision is null and submitted_at is null) or (submitted_revision=revision and submitted_at is not null))
);
create table plantlab_lab.request_vigour_revisions (
 run_id uuid not null references plantlab_lab.request_vigour_details(run_id),revision int not null,
 content jsonb not null,actor_id uuid not null references plantlab_platform.identities(id),
 recorded_at timestamptz not null default now(),primary key(run_id,revision)
);
create table plantlab_lab.request_vigour_counts (
 run_id uuid not null references plantlab_lab.request_vigour_details(run_id),replicate_no int not null check(replicate_no in(1,2)),
 first_normal int check(first_normal between 0 and 100),normal int not null check(normal between 0 and 100),
 abnormal int not null check(abnormal between 0 and 100),fresh int not null check(fresh between 0 and 100),
 hard int not null check(hard between 0 and 100),dead int not null check(dead between 0 and 100),
 abnormal_kind text,remarks text,observed_at timestamptz not null,
 primary key(run_id,replicate_no),check(normal+abnormal+fresh+hard+dead=100)
);
create table plantlab_lab.request_vigour_reviews (
 run_id uuid primary key references plantlab_lab.request_vigour_details(run_id),
 detail_revision int not null,reviewer_id uuid not null references plantlab_platform.identities(id),
 reviewer_name text not null check(length(btrim(reviewer_name)) between 1 and 120),
 recorded_at timestamptz not null default now()
);
create table plantlab_lab.request_vigour_actions (
 actor_id uuid not null references plantlab_platform.identities(id),action_id uuid not null,
 payload jsonb not null,response jsonb not null,recorded_at timestamptz not null default now(),primary key(actor_id,action_id)
);
do $$declare n text;begin
 foreach n in array array['request_vigour_details','request_vigour_revisions','request_vigour_counts','request_vigour_reviews','request_vigour_actions'] loop
  execute format('alter table plantlab_lab.%I enable row level security',n);
  execute format('revoke all on plantlab_lab.%I from PUBLIC,anon,authenticated,service_role',n);
  if n<>'request_vigour_details' then execute format('create trigger %I before update or delete on plantlab_lab.%I for each row execute function plantlab_lab.guard_uac_reference_history()',n||'_immutable',n);end if;
 end loop;
end$$;

create function plantlab_lab.normalize_request_vigour_detail(p_content jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare c jsonb:='{"version":1}';rows jsonb:='[]';row jsonb;k text;v jsonb;one jsonb;t timestamptz;
 available timestamptz;planted timestamptz;first_at timestamptz;finished timestamptz;total int;
begin
 if jsonb_typeof(p_content) is distinct from 'object' or p_content->'version' is distinct from '1'::jsonb or octet_length(p_content::text)>16000
  or exists(select from jsonb_object_keys(p_content)key_name where key_name not in('version','available_at','planted_at','first_count_at','final_at','crop_species','analyst_name','temperature_text','note','observations')) then
  raise exception 'Request Vigor detail version1 required' using errcode='22023';end if;
 foreach k in array array['crop_species','analyst_name','temperature_text','note'] loop
  v:=coalesce(p_content->k,'null');
  if v<>'null'::jsonb and (jsonb_typeof(v)<>'string' or length(p_content->>k)>case when k='note' then 1000 else 120 end) then raise exception 'Invalid detail text' using errcode='22023';end if;
  c:=c||jsonb_build_object(k,nullif(btrim(p_content->>k),''));
 end loop;
 foreach k in array array['available_at','planted_at','first_count_at','final_at'] loop
  v:=coalesce(p_content->k,'null');t:=null;
  if v<>'null'::jsonb then
   if jsonb_typeof(v)<>'string' or (p_content->>k)!~'(Z|[+-][0-9]{2}:[0-9]{2})$' then raise exception 'Actual timestamp with timezone required' using errcode='22023';end if;
   t:=(p_content->>k)::timestamptz;if not isfinite(t) or t>now() then raise exception 'Actual time cannot be future/infinite' using errcode='22023';end if;
  end if;
  if k='available_at' then available:=t;elsif k='planted_at' then planted:=t;elsif k='first_count_at' then first_at:=t;else finished:=t;end if;
  c:=c||jsonb_build_object(k,t);
 end loop;
 if planted<available or first_at<planted or finished<planted or finished<first_at then raise exception 'Physical testing times out of order' using errcode='22023';end if;
 if jsonb_typeof(p_content->'observations') is distinct from 'array' or jsonb_array_length(p_content->'observations')<>2 then raise exception 'Exactly2 source replicates of100; never fabricate50-seed subreplicates' using errcode='22023';end if;
 for row in select value from jsonb_array_elements(p_content->'observations') loop
  if jsonb_typeof(row)<>'object' or exists(select from jsonb_object_keys(row)key_name where key_name not in('first_normal','normal','abnormal','fresh','hard','dead','abnormal_kind','remarks')) then raise exception 'Invalid observation fields' using errcode='22023';end if;
  one:='{}';
  foreach k in array array['first_normal','normal','abnormal','fresh','hard','dead'] loop
   v:=coalesce(row->k,'null');
   if v<>'null'::jsonb and (jsonb_typeof(v)<>'number' or v::text!~'^[0-9]{1,3}$' or (v::text)::int>100) then raise exception 'Counts are integers0to100; unknown is null' using errcode='22023';end if;
   one:=one||jsonb_build_object(k,v);
  end loop;
  total:=coalesce((one->>'normal')::int,0)+coalesce((one->>'abnormal')::int,0)+coalesce((one->>'fresh')::int,0)+coalesce((one->>'hard')::int,0)+coalesce((one->>'dead')::int,0);
  if total>100 then raise exception 'Final categories exceed100 seeds' using errcode='22023';end if;
  foreach k in array array['abnormal_kind','remarks'] loop
   v:=coalesce(row->k,'null');if v<>'null'::jsonb and (jsonb_typeof(v)<>'string' or length(row->>k)>500) then raise exception 'Invalid observation notes' using errcode='22023';end if;
   one:=one||jsonb_build_object(k,nullif(btrim(row->>k),''));
  end loop;
  rows:=rows||jsonb_build_array(one);
 end loop;
 return c||jsonb_build_object('observations',rows);
end$$;

create function plantlab_lab.request_vigour_readiness(p_run uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare d plantlab_lab.request_vigour_details;r plantlab_lab.test_runs;c jsonb;row jsonb;k text;reasons jsonb:='[]';warnings jsonb:='[]';has_first boolean;decision_at timestamptz;
begin
 select * into d from plantlab_lab.request_vigour_details where run_id=p_run;
 if not found then return jsonb_build_object('ready',false,'blockers',jsonb_build_array('Simpan rincian pengamatan dahulu.'),'warnings','[]'::jsonb);end if;
 c:=d.content;select * into strict r from plantlab_lab.test_runs where id=p_run;
 foreach k in array array['available_at','planted_at','final_at','crop_species','analyst_name','temperature_text'] loop
  if c->>k is null then reasons:=reasons||jsonb_build_array('Lengkapi '||case k when 'available_at' then 'waktu sampel tersedia' when 'planted_at' then 'waktu tanam' when 'final_at' then 'waktu pengamatan final' when 'crop_species' then 'tanaman/spesies' when 'analyst_name' then 'nama Analis' else 'suhu uji aktual' end||' sesuai pekerjaan nyata.');end if;
 end loop;
 has_first:=exists(select from jsonb_array_elements(c->'observations')o where o->>'first_normal' is not null) or c->>'first_count_at' is not null;
 if has_first and c->>'first_count_at' is null then reasons:=reasons||jsonb_build_array('Tanggal pengamatan first count belum diisi.');end if;
 for row in select value from jsonb_array_elements(c->'observations') loop
  if exists(select from unnest(array['normal','abnormal','fresh','hard','dead'])field_key where row->>field_key is null)
   or coalesce((row->>'normal')::int,0)+coalesce((row->>'abnormal')::int,0)+coalesce((row->>'fresh')::int,0)+coalesce((row->>'hard')::int,0)+coalesce((row->>'dead')::int,0)<>100 then
   reasons:=reasons||jsonb_build_array('Lengkapi5 kategori final; total tiap ulangan harus100. Kosong bukan nol.');end if;
  if (row->>'abnormal')::int>0 and row->>'abnormal_kind' is null then reasons:=reasons||jsonb_build_array('Isi jenis abnormal yang ditemukan.');end if;
  if has_first and row->>'first_normal' is null then reasons:=reasons||jsonb_build_array('Lengkapi first count kedua ulangan atau kosongkan seluruhnya jika tidak dilakukan.');end if;
  if (row->>'first_normal')::int>(row->>'normal')::int then warnings:=warnings||jsonb_build_array('First count melebihi normal final. Periksa dan jelaskan perubahan klasifikasi untuk QA.');end if;
 end loop;
 if coalesce(length(btrim(c->>'note')),0)<3 then reasons:=reasons||jsonb_build_array('Isi catatan kondisi, alat dan pengamatan minimal3 karakter.');end if;
 if (c->>'available_at')::timestamptz < date_trunc('minute',(select coalesce(receipt.source_received_at,receipt.received_at) from plantlab_lab.test_cycles cycle join plantlab_lab.sample_receipts receipt on receipt.id=cycle.incoming_receipt_id where cycle.id=r.test_cycle_id))
 or (c->>'available_at')::timestamptz > (select actual_started_at from plantlab_lab.vigour_run_contexts where test_run_id=r.id)
 or (c->>'planted_at')::timestamptz < (select actual_started_at from plantlab_lab.vigour_run_contexts where test_run_id=r.id) then
 reasons:=reasons||jsonb_build_array('Waktu sampel tersedia harus sesudah penerimaan dan sebelum mulai perlakuan; tanam tidak sebelum mulai perlakuan Vigor.');end if;
 if r.retest_of_id is not null then
  select decided_at into decision_at from plantlab_lab.result_decisions where test_run_id=r.retest_of_id order by id desc limit 1;
  if date_trunc('minute',(c->>'planted_at')::timestamptz)<date_trunc('minute',decision_at) then reasons:=reasons||jsonb_build_array('Tanam uji ulang tidak boleh sebelum keputusan QA.');end if;
 end if;
 return jsonb_build_object('ready',jsonb_array_length(reasons)=0,'blockers',reasons,'warnings',warnings);
end$$;

create function plantlab_lab.guard_request_vigour_detail()
returns trigger language plpgsql set search_path='' as $$
begin
 if old.submitted_revision is not null then raise exception 'Submitted request observations are immutable; create authorized retest' using errcode='55000';end if;
 return case when tg_op='DELETE' then old else new end;
end$$;
create trigger request_vigour_detail_freeze before update or delete on plantlab_lab.request_vigour_details for each row execute function plantlab_lab.guard_request_vigour_detail();

create function plantlab_lab.guard_request_vigour_counts()
returns trigger language plpgsql set search_path='' as $$
declare d plantlab_lab.request_vigour_details;row jsonb;
begin
 select d0.* into d from plantlab_lab.request_vigour_details d0 join plantlab_lab.test_runs r on r.id=d0.run_id
 where r.id=new.run_id and r.status='IN_PROGRESS' and r.performed_by=auth.uid() and d0.submitted_revision=d0.revision;
 if not found then raise exception 'Sealed assigned detail required' using errcode='42501';end if;
 row:=d.content->'observations'->(new.replicate_no-1);
 if (to_jsonb(new)-'run_id'-'replicate_no'-'observed_at') is distinct from row or new.observed_at is distinct from (d.content->>'final_at')::timestamptz then
  raise exception 'Counts must match sealed detail' using errcode='23514';end if;
 return new;
end$$;
create trigger request_vigour_count_input before insert on plantlab_lab.request_vigour_counts for each row execute function plantlab_lab.guard_request_vigour_counts();

create function plantlab_api.get_request_vigour_detail(p_request_id uuid,p_run_code text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r plantlab_lab.test_runs;d plantlab_lab.request_vigour_details;q plantlab_lab.requests;l plantlab_core.lots;current_run uuid;rev plantlab_lab.request_vigour_reviews;
begin
 select run.* into r from plantlab_lab.test_runs run join plantlab_lab.request_items i on i.id=run.request_item_id
 join plantlab_lab.requests req on req.id=i.request_id and req.source_module='PLANT' join plantlab_core.lots lot on lot.id=req.lot_id
 join plantlab_master.sites s on s.id=req.target_lab_site_id and s.is_active and s.site_type='LAB' and s.company_id=lot.company_id
 join plantlab_lab.methods m on m.id=run.method_id and m.method_code in('AAT_42C_72H_RH90','COLD_TEST_5C_24H','SCT_10C7D_25C5D','AAT_EXT_42C_96H_RH90')
 where req.id=p_request_id and run.test_code=p_run_code and auth.uid() is not null
 and plantlab_platform.has_permission('LAB','result.read',s.id,s.company_id);
 if not found then raise exception 'Vigor run outside Lab scope' using errcode='42501';end if;
 select * into strict q from plantlab_lab.requests where id=p_request_id;select * into strict l from plantlab_core.lots where id=q.lot_id;
 select id into current_run from plantlab_lab.test_runs where request_item_id=r.request_item_id and sample_id=r.sample_id order by attempt_no desc limit 1;
 select * into d from plantlab_lab.request_vigour_details where run_id=r.id;
 select * into rev from plantlab_lab.request_vigour_reviews where run_id=r.id;
 return jsonb_build_object('version',1,'run_id',r.id,'run_code',r.test_code,'request_id',q.id,'revision',coalesce(d.revision,0),'status',r.status,
  'request_code',q.request_code,'lot_code',l.lot_code,'lab_name',(select site_name from plantlab_master.sites where id=q.target_lab_site_id),
  'sample_reference',(select coalesce(nullif(btrim(metadata->>'sample_reference'),''),sample_code) from plantlab_core.samples where id=r.sample_id),
  'content',d.content,'submitted_revision',d.submitted_revision,'has_detail',d.run_id is not null,
  'can_edit',r.id=current_run and r.status='IN_PROGRESS' and r.performed_by=auth.uid() and d.submitted_revision is null
    and plantlab_platform.has_exact_scoped_role('LAB','LAB_ANALYST',q.target_lab_site_id,l.company_id),
  'can_review',r.id=current_run and r.status='IN_REVIEW' and d.submitted_revision is not null and r.performed_by<>auth.uid()
    and plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',q.target_lab_site_id,l.company_id),
  'reviewer_name',rev.reviewer_name,'readiness',plantlab_lab.request_vigour_readiness(r.id),
  'authorizes_lot_release',false,'method_code',(select method_code from plantlab_lab.methods where id=r.method_id),
  'treatment_started_at',(select actual_started_at from plantlab_lab.vigour_run_contexts where test_run_id=r.id),
  'time_basis',case when d.run_id is null then 'APPLICATION_EVENT_TIME' else 'ANALYST_ACTUAL_INPUT' end);
end$$;

create function plantlab_lab.replay_request_vigour_action(p_action uuid,p_payload jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare a plantlab_lab.request_vigour_actions;
begin
 if p_action is null then raise exception 'Action required' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('REQUEST_VIGOUR_ACTION:'||auth.uid()||':'||p_action,0));
 select * into a from plantlab_lab.request_vigour_actions where actor_id=auth.uid() and action_id=p_action;
 if found then if a.payload is distinct from p_payload then raise exception 'Changed action payload' using errcode='23505';end if;return a.response;end if;
 return null;
end$$;


-- Only current ordinary Vigor runs from received Plant requests. RET/routine excluded.
create function plantlab_lab.lock_request_vigour_detail(p_request_id uuid,p_run_code text,p_role text)
returns table(item_id uuid,sample_id uuid) language plpgsql set search_path='' as $$
declare r plantlab_lab.test_runs;scope record;
begin
 select run.* into r from plantlab_lab.test_runs run join plantlab_lab.request_items i on i.id=run.request_item_id
 join plantlab_lab.methods m on m.id=run.method_id and m.method_code in('AAT_42C_72H_RH90','COLD_TEST_5C_24H','SCT_10C7D_25C5D','AAT_EXT_42C_96H_RH90')
 where i.request_id=p_request_id and run.test_code=p_run_code;
 if not found then raise exception 'Ordinary Vigor request run required; RET stays separate' using errcode='42501';end if;
 select * into scope from plantlab_lab.lock_vigour_item(r.request_item_id,p_role);
 if scope.request_id<>p_request_id or scope.sample_id<>r.sample_id then raise exception 'Sample/request mismatch' using errcode='42501';end if;
 if exists(select from plantlab_lab.test_runs newer where newer.request_item_id=r.request_item_id and newer.sample_id=r.sample_id and newer.attempt_no>r.attempt_no) then
 raise exception 'Newer attempt exists; reload' using errcode='PT409';end if;
 return query select r.request_item_id,r.sample_id;
end$$;

create function plantlab_api.save_request_vigour_detail(p_request_id uuid,p_run_code text,p_expected_revision int,p_action_id uuid,p_content jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare scope record;r plantlab_lab.test_runs;d plantlab_lab.request_vigour_details;c jsonb;payload jsonb;response jsonb;
begin
 select * into scope from plantlab_lab.lock_request_vigour_detail(p_request_id,p_run_code,'LAB_ANALYST');
 select * into strict r from plantlab_lab.test_runs where test_code=p_run_code and request_item_id=scope.item_id for update;
 if r.performed_by is distinct from auth.uid() then raise exception 'Assigned analyst required' using errcode='42501';end if;
 if p_expected_revision is null or p_expected_revision<0 then raise exception 'Expected revision required' using errcode='22023';end if;
 c:=plantlab_lab.normalize_request_vigour_detail(p_content);
 payload:=jsonb_build_object('operation','SAVE','request_id',p_request_id,'run_code',p_run_code,'revision',p_expected_revision,'content',c);
 response:=plantlab_lab.replay_request_vigour_action(p_action_id,payload);if response is not null then return response;end if;
 if r.status<>'IN_PROGRESS' then raise exception 'Open Vigor run required' using errcode='55000';end if;
 select * into d from plantlab_lab.request_vigour_details where run_id=r.id for update;
 if coalesce(d.revision,0)<>p_expected_revision then raise exception 'Detail revision changed; reload' using errcode='PT409';end if;
 if d.run_id is null then insert into plantlab_lab.request_vigour_details(run_id,revision,content,created_by)values(r.id,1,c,auth.uid()) returning * into d;
 else update plantlab_lab.request_vigour_details set revision=revision+1,content=c,updated_at=now() where run_id=r.id returning * into d;end if;
 insert into plantlab_lab.request_vigour_revisions(run_id,revision,content,actor_id)values(r.id,d.revision,c,auth.uid());
 response:=jsonb_build_object('run_code',r.test_code,'revision',d.revision,'status',r.status);
 insert into plantlab_lab.request_vigour_actions(actor_id,action_id,payload,response)values(auth.uid(),p_action_id,payload,response);
 return response;
end$$;


-- Same Excel formula/tolerance as the existing ordinary method; never project fresh/hard into dead.
create function plantlab_lab.calculate_request_vigour_detail(p_replicates jsonb,p_test_type uuid,p_method uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare row jsonb;norm int;total int:=0;lo int:=100;hi int:=0;raw numeric;rounded numeric;tol numeric;
begin
 if jsonb_array_length(p_replicates)<>2 then raise exception 'Two source100 replicates required' using errcode='22023';end if;
 for row in select value from jsonb_array_elements(p_replicates) loop
  if exists(select from unnest(array['normal','abnormal','fresh','hard','dead'])k where row->>k is null)
  or (row->>'normal')::int+(row->>'abnormal')::int+(row->>'fresh')::int+(row->>'hard')::int+(row->>'dead')::int<>100 then
  raise exception 'Five complete categories total100 required' using errcode='22023';end if;
  norm:=(row->>'normal')::int;total:=total+norm;lo:=least(lo,norm);hi:=greatest(hi,norm);
 end loop;
 raw:=total/2.0;rounded:=round(raw,0);tol:=plantlab_lab.get_tolerance_limit(2,rounded,p_test_type,p_method);
 return jsonb_build_object('replicates',p_replicates,'total_tested',200,'unrounded_percent',raw,'vigour_percent',rounded,
 'calculation_code','EXCEL_ROUND_AVERAGE_2X100','calculation_version',1,'gap_pp',hi-lo,'limit_pp',tol,'within_tolerance',(hi-lo)<=tol,
 'tolerance_status',case when tol is null then 'RULE_NOT_AVAILABLE' when hi-lo<=tol then 'WITHIN_SOURCE_TOLERANCE' else 'EXCEEDS_SOURCE_TOLERANCE' end,'authorizes_lot_release',false);
end$$;

-- Derive narrow private cores from the installed functions with guarded replacements.
-- No replacement of the old calculator (also used by routine tests) or RET branch.
do $migration$
declare body text;needle text;replacement text;definition text;
begin
 select prosrc into strict body from pg_proc where oid='plantlab_api.submit_vigour(uuid,timestamptz,jsonb,text,uuid)'::regprocedure;
 needle:='plantlab_lab.calculate_vigour_counts(p_replicates,scope.test_type_id,scope.method_id)';
 if strpos(body,needle)=0 then raise exception 'Unexpected ordinary Vigor calculator call';end if;
 body:=replace(body,needle,'plantlab_lab.calculate_request_vigour_detail(p_replicates,scope.test_type_id,scope.method_id)');
 needle:=$old$perform plantlab_lab.save_test_run_observation(run.id,'FINAL',idx,p_observed_at,(r->>'normal')::int,(r->>'abnormal')::int,(r->>'dead')::int);$old$;
 if strpos(body,needle)=0 then raise exception 'Unexpected Vigor observation writer';end if;
 body:=replace(body,needle,$new$insert into plantlab_lab.request_vigour_counts(run_id,replicate_no,first_normal,normal,abnormal,fresh,hard,dead,abnormal_kind,remarks,observed_at)
 values(run.id,idx,(r->>'first_normal')::int,(r->>'normal')::int,(r->>'abnormal')::int,(r->>'fresh')::int,(r->>'hard')::int,(r->>'dead')::int,r->>'abnormal_kind',r->>'remarks',p_observed_at);$new$);
 needle:=$old$select id into strict parameter from plantlab_lab.parameters where parameter_code='VIGOUR_PERCENT';$old$;
 if strpos(body,needle)=0 then raise exception 'Unexpected Vigor parameter lookup';end if;
 body:=replace(body,needle,$new$select summary||jsonb_build_object('request_detail_version',1,'request_detail_revision',d.revision,
 'actual_times',d.content-'observations','treatment_started_at',c.actual_started_at,'first_count_added_to_final',false)
 into summary from plantlab_lab.request_vigour_details d where d.run_id=run.id and d.submitted_revision=d.revision;
 if summary is null then raise exception 'Sealed Vigor detail required' using errcode='55000';end if;
 $new$||needle);
 execute 'create function plantlab_lab.submit_request_vigour_core(p_run_id uuid,p_observed_at timestamptz,p_replicates jsonb,p_observation_note text,p_action_id uuid) returns jsonb language plpgsql set search_path='''' as '||quote_literal(body);
 select prosrc into strict body from pg_proc where oid='plantlab_api.review_vigour(uuid,text,text,uuid)'::regprocedure;
 execute 'create function plantlab_lab.review_request_vigour_core(p_run_id uuid,p_decision text,p_reason text,p_action_id uuid) returns jsonb language plpgsql set search_path='''' as '||quote_literal(body);
 definition:=pg_get_functiondef('plantlab_lab.validate_test_run_workflow()'::regprocedure);
 needle:=$old$elsif not exists(select from plantlab_lab.test_run_observations where test_run_id=new.id and observation_phase='FINAL')$old$;
 if strpos(definition,needle)=0 then raise exception 'Unexpected workflow observation guard';end if;
 execute replace(definition,needle,$new$elsif exists(select from plantlab_lab.request_vigour_details where run_id=new.id and submitted_revision=revision) then
 if (select count(*) from plantlab_lab.request_vigour_counts where run_id=new.id)<>2 then raise exception 'Two sealed Vigor source100 observations required' using errcode='23514';end if;
 $new$||needle);
end$migration$;

create function plantlab_lab.guard_request_vigour_final()
returns trigger language plpgsql set search_path='' as $$
declare d plantlab_lab.request_vigour_details;
begin
 if new.event_type<>'OBSERVED_FINAL' then return new;end if;
 select * into d from plantlab_lab.request_vigour_details where run_id=new.test_run_id;
 if not found then return new;end if;
 if d.submitted_revision is distinct from d.revision or not (plantlab_lab.request_vigour_readiness(d.run_id)->>'ready')::boolean
 or new.metadata->>'request_detail_revision' is distinct from d.revision::text
 or new.metadata->'replicates' is distinct from (select jsonb_agg(to_jsonb(o)-'run_id'-'replicate_no'-'observed_at' order by replicate_no) from plantlab_lab.request_vigour_counts o where o.run_id=d.run_id)
 or new.metadata->'actual_times' is distinct from d.content-'observations'
 or new.event_at is distinct from (d.content->>'final_at')::timestamptz then
 raise exception 'Vigor event must match sealed physical observations' using errcode='23514';end if;
 return new;
end$$;
create trigger request_vigour_final_input before insert on plantlab_lab.test_run_events for each row execute function plantlab_lab.guard_request_vigour_final();

create function plantlab_api.submit_request_vigour_detail(p_request_id uuid,p_run_code text,p_expected_revision int,p_action_id uuid,p_confirmed boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare scope record;r plantlab_lab.test_runs;d plantlab_lab.request_vigour_details;payload jsonb;response jsonb;
begin
 select * into scope from plantlab_lab.lock_request_vigour_detail(p_request_id,p_run_code,'LAB_ANALYST');
 select * into strict r from plantlab_lab.test_runs where test_code=p_run_code and request_item_id=scope.item_id for update;
 if r.performed_by is distinct from auth.uid() then raise exception 'Assigned analyst required' using errcode='42501';end if;
 if p_confirmed is distinct from true or p_expected_revision is null or p_expected_revision<1 then raise exception 'Confirm actual saved observations first' using errcode='22023';end if;
 payload:=jsonb_build_object('operation','SUBMIT','request_id',p_request_id,'run_code',p_run_code,'revision',p_expected_revision,'confirmed',p_confirmed);
 response:=plantlab_lab.replay_request_vigour_action(p_action_id,payload);if response is not null then return response;end if;
 select * into d from plantlab_lab.request_vigour_details where run_id=r.id for update;
 if d.revision is distinct from p_expected_revision then raise exception 'Detail revision changed' using errcode='PT409';end if;
 if r.status<>'IN_PROGRESS' or d.submitted_revision is not null then raise exception 'Open saved detail required' using errcode='55000';end if;
 if not (plantlab_lab.request_vigour_readiness(r.id)->>'ready')::boolean then raise exception 'Complete actual headers, times and five categories first' using errcode='22023';end if;
 perform plantlab_lab.normalize_request_vigour_detail(d.content);
 update plantlab_lab.request_vigour_details set submitted_revision=revision,submitted_at=now(),updated_at=now() where run_id=r.id;
 response:=plantlab_lab.submit_request_vigour_core(r.id,(d.content->>'final_at')::timestamptz,d.content->'observations',d.content->>'note',p_action_id)||jsonb_build_object('revision',d.revision);
 insert into plantlab_lab.request_vigour_actions(actor_id,action_id,payload,response)values(auth.uid(),p_action_id,payload,response);
 return response;
end$$;

create function plantlab_api.review_request_vigour_detail(p_request_id uuid,p_run_code text,p_expected_revision int,p_action_id uuid,p_decision text,p_reviewer_name text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare scope record;r plantlab_lab.test_runs;d plantlab_lab.request_vigour_details;name text:=nullif(btrim(p_reviewer_name),'');payload jsonb;response jsonb;
begin
 select * into scope from plantlab_lab.lock_request_vigour_detail(p_request_id,p_run_code,'LAB_QA_APPROVER');
 select * into strict r from plantlab_lab.test_runs where test_code=p_run_code and request_item_id=scope.item_id for update;
 if r.performed_by is null or r.performed_by=auth.uid() then raise exception 'Independent QA required' using errcode='42501';end if;
 if name is null or length(name)>120 then raise exception 'Actual QA reviewer name required' using errcode='22023';end if;
 payload:=jsonb_build_object('operation','REVIEW','request_id',p_request_id,'run_code',p_run_code,'revision',p_expected_revision,'decision',upper(btrim(p_decision)),'name',name,'reason',nullif(btrim(p_reason),''));
 response:=plantlab_lab.replay_request_vigour_action(p_action_id,payload);if response is not null then return response;end if;
 select * into d from plantlab_lab.request_vigour_details where run_id=r.id;
 if d.submitted_revision is null or d.submitted_revision is distinct from p_expected_revision then raise exception 'Submitted detail revision changed' using errcode='PT409';end if;
 if exists(select from plantlab_lab.request_vigour_reviews where run_id=r.id) then raise exception 'Already reviewed; reload' using errcode='55000';end if;
 response:=plantlab_lab.review_request_vigour_core(r.id,p_decision,p_reason,p_action_id)||jsonb_build_object('revision',d.revision);
 insert into plantlab_lab.request_vigour_reviews(run_id,detail_revision,reviewer_id,reviewer_name)values(r.id,d.revision,auth.uid(),name);
 insert into plantlab_lab.request_vigour_actions(actor_id,action_id,payload,response)values(auth.uid(),p_action_id,payload,response);
 return response;
end$$;

-- Refuse lossy old writers ONLY after a rich ordinary Vigor draft exists.
do $$declare signature text;definition text;needle text;begin
 foreach signature in array array['plantlab_api.submit_vigour(uuid,timestamptz,jsonb,text,uuid)','plantlab_api.review_vigour(uuid,text,text,uuid)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  needle:='select * into strict run from plantlab_lab.test_runs where id=p_run_id for update;';
  if strpos(definition,needle)=0 then raise exception 'Unexpected old Vigor writer';end if;
  execute replace(definition,needle,needle||E'\n if exists(select from plantlab_lab.request_vigour_details where run_id=run.id) then raise exception ''Update Lab and use full saved Vigor observations'' using errcode=''55000'';end if;');
 end loop;
 -- Preserve the previous v2 reader, including all Germination and legacy checks.
 select prosrc into strict definition from pg_proc where oid='plantlab_api.get_request_seedling_form_export_v2(text,text,int)'::regprocedure;
 execute 'create function plantlab_lab.request_seedling_snapshot_before_vigour(p_run_code text,p_expected_status text,p_expected_revision int default null) returns jsonb language plpgsql stable set search_path='''' as '||quote_literal(definition);
 definition:=pg_get_functiondef('plantlab_api.get_request_seedling_form_export(text,text)'::regprocedure);
 needle:=$old$if run.status<>p_expected_status then raise exception 'Run status changed; reload before download' using errcode='PT409';end if;$old$;
 if strpos(definition,needle)=0 then raise exception 'Unexpected old form status guard';end if;
 execute replace(definition,needle,needle||E'\n if exists(select from plantlab_lab.request_vigour_details where run_id=run.id) then raise exception ''Use full saved Vigor form reader'' using errcode=''55000'';end if;');
end$$;

create or replace function plantlab_api.get_request_seedling_form_export_v2(p_run_code text,p_expected_status text,p_expected_revision int default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare base jsonb;d plantlab_lab.request_vigour_details;review plantlab_lab.request_vigour_reviews;observations jsonb;approved boolean;
begin
 -- First scope/status validation is always performed by the existing Lab-only reader.
 base:=plantlab_lab.request_seedling_snapshot_before_vigour(p_run_code,p_expected_status,null);
 select * into d from plantlab_lab.request_vigour_details where run_id=(base->>'id')::uuid;
 if not found then return plantlab_lab.request_seedling_snapshot_before_vigour(p_run_code,p_expected_status,p_expected_revision);end if;
 if p_expected_revision is not null and p_expected_revision is distinct from d.revision then raise exception 'Vigor detail revision changed; reload' using errcode='PT409';end if;
 select * into review from plantlab_lab.request_vigour_reviews where run_id=d.run_id;
 select jsonb_agg(o.value||jsonb_build_object('replicate_no',o.ordinality,'tested',case
 when not exists(select from unnest(array['normal','abnormal','fresh','hard','dead'])key_name where o.value->>key_name is null)
 and (o.value->>'normal')::int+(o.value->>'abnormal')::int+(o.value->>'fresh')::int+(o.value->>'hard')::int+(o.value->>'dead')::int=100 then 100 else null end) order by o.ordinality)
 into observations from jsonb_array_elements(d.content->'observations')with ordinality o(value,ordinality);
 approved:=coalesce((base->>'qa_approval_verified')::boolean and review.reviewer_id=(base->>'reviewer_id')::uuid and review.detail_revision=d.submitted_revision,false);
 return base||jsonb_build_object('request_form_version',2,'revision',d.revision,'detail_submitted',d.submitted_revision is not null,
 'qa_approval_verified',approved,'export_status',case when base->>'status'='APPROVED' and not approved then 'APPROVAL_INCOMPLETE' else base->>'status' end,
 'available_at',d.content->'available_at','source_time_basis','ANALYST_ACTUAL_INPUT',
 'treatment_started_at',base->'started_at','started_at',d.content->'planted_at','observed_at',d.content->'final_at','first_count_at',d.content->'first_count_at',
 'recorded_started_at',null,'recorded_final_at',null,
 'crop_species',d.content->'crop_species','analyst_name',d.content->'analyst_name','temperature_text',d.content->'temperature_text',
 'reviewer_name',case when review.reviewer_id=(base->>'reviewer_id')::uuid then review.reviewer_name else null end,
 'conditions_note',d.content->'note','observation_note',null,'observations',observations,'updated_at',d.updated_at);
end$$;

do $$declare f regprocedure;begin
 for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='plantlab_lab' and (p.proname like '%request_vigour%' or p.proname='request_seedling_snapshot_before_vigour') loop
 execute format('revoke all on function %s from PUBLIC,anon,authenticated,service_role',f);
 end loop;
end$$;
revoke all on function plantlab_api.get_request_vigour_detail(uuid,text),plantlab_api.save_request_vigour_detail(uuid,text,int,uuid,jsonb),
 plantlab_api.submit_request_vigour_detail(uuid,text,int,uuid,boolean),plantlab_api.review_request_vigour_detail(uuid,text,int,uuid,text,text,text) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_request_vigour_detail(uuid,text),plantlab_api.save_request_vigour_detail(uuid,text,int,uuid,jsonb),
 plantlab_api.submit_request_vigour_detail(uuid,text,int,uuid,boolean),plantlab_api.review_request_vigour_detail(uuid,text,int,uuid,text,text,text) to authenticated;
notify pgrst,'reload schema';
commit;

