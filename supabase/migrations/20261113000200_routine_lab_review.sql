-- Prospective routine results. No production observations, identities, roles,
-- old results or tolerances are seeded/rewritten by this migration.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create table plantlab_lab.routine_calculation_contracts (
 method_id uuid primary key references plantlab_lab.methods(id),
 version int not null check(version=1),
 calculation_code text not null check(calculation_code in ('ROUTINE_ROUND_MEAN_2X100_V1','RET_RADICLE_4X100_V1')),
 replicate_count int not null check(replicate_count in(2,4)),
 seeds_per_replicate int not null check(seeds_per_replicate=100),
 source_reference text not null,source_sha256 text not null,
 effective_from timestamptz not null default now()
);
insert into plantlab_lab.routine_calculation_contracts
select m.id,1,case when m.method_code='RET_16C_72H' then 'RET_RADICLE_4X100_V1' else 'ROUTINE_ROUND_MEAN_2X100_V1' end,
 case when m.method_code='RET_16C_72H' then 4 else 2 end,100,
 case when m.method_code='SAND_25C' then 'Owner: calculate as Excel; KC Lab Germ&Vigor AQ4=ROUND(AVERAGE(AF4:AF11),0), paired 50-seed subreps; prospective routine uses owner-confirmed2x100, not historical4x100. Final counts cumulative, never first+final. Old request calculations unchanged.'
 when m.method_code='RET_16C_72H' then 'Confirmed RET contract11Nov:4x100,radicle>=2mm,72h from16C,4-Reps tolerance; existing calculator reused.'
 else 'Confirmed Vigor contract11Nov:2x100,ROUND(AVERAGE(replicate normal sums),0). Preserve five final categories from ALL Form; final denominator100 per replicate.' end,
 case when m.method_code='SAND_25C' then '5595f8bb17b2763a11f6139572bfb595c37e4ed4529904014277268e3d2306b8' else 'f32f9ee5c29c8c96144be99d5717033052cf4a1ebc688458195e794ee3b1bb31' end,now()
from plantlab_lab.confirmed_method_contracts c join plantlab_lab.methods m on m.id=c.method_id
where m.is_active and (m.method_code='SAND_25C' or exists(select from plantlab_lab.vigour_calculation_contracts v where v.method_id=m.id));

create table plantlab_lab.routine_submissions (
 test_run_id uuid primary key references plantlab_lab.test_runs(id),
 draft_id uuid not null unique references plantlab_lab.routine_drafts(id),
 draft_revision int not null check(draft_revision>0),
 contract_method_id uuid not null references plantlab_lab.routine_calculation_contracts(method_id),
 draft_snapshot jsonb not null, submitted_by uuid not null references plantlab_platform.identities(id),
 submitted_at timestamptz not null default now()
);
create table plantlab_lab.routine_count_observations (
 test_run_id uuid not null references plantlab_lab.routine_submissions(test_run_id),
 subrep_no int not null check(subrep_no between 1 and 4),
 first_normal int check(first_normal between 0 and 50),
 final_normal int not null check(final_normal between 0 and 50),
 abnormal int not null check(abnormal between 0 and 50),
 fresh int not null check(fresh between 0 and 50),
 hard int not null check(hard between 0 and 50),
 dead int not null check(dead between 0 and 50),
 observed_at timestamptz not null,recorded_by uuid not null references plantlab_platform.identities(id),
 primary key(test_run_id,subrep_no),check(final_normal+abnormal+fresh+hard+dead=50)
);
create table plantlab_lab.routine_retest_drafts (
 draft_id uuid primary key references plantlab_lab.routine_drafts(id),
 previous_run_id uuid not null unique references plantlab_lab.routine_submissions(test_run_id),
 created_at timestamptz not null default now()
);
create table plantlab_lab.routine_workflow_actions (
 actor_id uuid not null references plantlab_platform.identities(id),action_id uuid not null,
 command text not null,payload jsonb not null,response jsonb not null,
 recorded_at timestamptz not null default now(),primary key(actor_id,action_id)
);
alter table plantlab_lab.routine_calculation_contracts enable row level security;
alter table plantlab_lab.routine_submissions enable row level security;
alter table plantlab_lab.routine_count_observations enable row level security;
alter table plantlab_lab.routine_retest_drafts enable row level security;
alter table plantlab_lab.routine_workflow_actions enable row level security;
revoke all on plantlab_lab.routine_calculation_contracts,plantlab_lab.routine_submissions,plantlab_lab.routine_count_observations,plantlab_lab.routine_retest_drafts,plantlab_lab.routine_workflow_actions from PUBLIC,anon,authenticated,service_role;
create trigger routine_contracts_immutable before update or delete on plantlab_lab.routine_calculation_contracts for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger routine_submissions_immutable before update or delete on plantlab_lab.routine_submissions for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger routine_counts_immutable before update or delete on plantlab_lab.routine_count_observations for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger routine_retest_drafts_immutable before update or delete on plantlab_lab.routine_retest_drafts for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger routine_workflow_actions_immutable before update or delete on plantlab_lab.routine_workflow_actions for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_lab.freeze_submitted_routine_draft()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select from plantlab_lab.routine_submissions where draft_id=old.id) then
 raise exception 'Submitted routine draft is frozen; use a QA-authorized retest' using errcode='55000'; end if;
 return case when tg_op='DELETE' then old else new end;
end;
$$;
create trigger routine_draft_submission_freeze before update or delete on plantlab_lab.routine_drafts
 for each row execute function plantlab_lab.freeze_submitted_routine_draft();

create function plantlab_lab.guard_routine_count_input()
returns trigger language plpgsql security definer set search_path='' as $$
declare content jsonb;expected jsonb;
begin
 select s.draft_snapshot into content from plantlab_lab.routine_submissions s join plantlab_lab.test_runs r on r.id=s.test_run_id
 where r.id=new.test_run_id and r.status='IN_PROGRESS' and r.performed_by=auth.uid() and r.method_id=s.contract_method_id;
 if not found then raise exception 'Assigned open routine run required' using errcode='42501'; end if;
 expected:=content->'observations'->(new.subrep_no-1);
 if new.observed_at is distinct from (content->>'final_at')::timestamptz or
 jsonb_build_object('first_normal',new.first_normal,'final_normal',new.final_normal,'abnormal',new.abnormal,'fresh',new.fresh,'hard',new.hard,'dead',new.dead) is distinct from expected then
 raise exception 'Routine observations must match sealed draft' using errcode='23514'; end if;
 return new;
end;
$$;
create trigger routine_count_input before insert on plantlab_lab.routine_count_observations for each row execute function plantlab_lab.guard_routine_count_input();

create function plantlab_lab.calculate_routine_observations(p_method uuid,p_content jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare c plantlab_lab.routine_calculation_contracts; t uuid; method_code text; content jsonb; r jsonb; a jsonb; b jsonb; reps jsonb:='[]'; first_value int; total_normal int:=0; normal_value int; lo int:=100; hi int:=0; raw_percent numeric; percent_value numeric; tolerance numeric; k text; x int;
begin
 select * into strict c from plantlab_lab.routine_calculation_contracts where method_id=p_method;
 select m.method_code,tt.id into strict method_code,t from plantlab_lab.methods m join plantlab_lab.method_test_types mt on mt.method_id=m.id join plantlab_lab.test_types tt on tt.id=mt.test_type_id where m.id=p_method and tt.test_code=case when m.method_code='SAND_25C' then 'GERMINATION' else 'VIGOUR' end;
 content:=plantlab_lab.normalize_routine_draft(method_code,p_content);
 if (content->>'replicate_count')::int<>c.replicate_count then raise exception 'Routine contract requires confirmed replicate count' using errcode='22023'; end if;
 if method_code='RET_16C_72H' then
 for r in select value from jsonb_array_elements(content->'observations') loop
 if r->'radicle_at_least_2mm'='null'::jsonb then raise exception 'All four actual RET counts required; blank is not zero' using errcode='22023'; end if;
 reps:=reps||jsonb_build_array(jsonb_build_object('tested',100,'radicle_at_least_2mm',r->'radicle_at_least_2mm'));
 end loop;
 return plantlab_lab.calculate_ret_observations(reps,t,p_method)||jsonb_build_object('routine_contract_version',c.version,'source_reference',c.source_reference);
 end if;
 for r in select value from jsonb_array_elements(content->'observations') loop
 foreach k in array array['final_normal','abnormal','fresh','hard','dead'] loop
 if r->k='null'::jsonb then raise exception 'All five final categories must be explicitly recorded; blank is not zero' using errcode='22023'; end if;
 end loop;
 if (r->>'final_normal')::int+(r->>'abnormal')::int+(r->>'fresh')::int+(r->>'hard')::int+(r->>'dead')::int<>50 then raise exception 'Each final subreplicate must total50' using errcode='22023'; end if;
 end loop;
 for x in 0..1 loop
 a:=content->'observations'->(x*2);b:=content->'observations'->(x*2+1);
 normal_value:=(a->>'final_normal')::int+(b->>'final_normal')::int;
 first_value:=case when a->'first_normal'<>'null'::jsonb and b->'first_normal'<>'null'::jsonb then (a->>'first_normal')::int+(b->>'first_normal')::int end;
 reps:=reps||jsonb_build_array(jsonb_build_object('normal',normal_value,'abnormal',(a->>'abnormal')::int+(b->>'abnormal')::int,'fresh',(a->>'fresh')::int+(b->>'fresh')::int,'hard',(a->>'hard')::int+(b->>'hard')::int,'dead',(a->>'dead')::int+(b->>'dead')::int,'first_normal',first_value));
 total_normal:=total_normal+normal_value;lo:=least(lo,normal_value);hi:=greatest(hi,normal_value);
 end loop;
 raw_percent:=total_normal/2.0;percent_value:=round(raw_percent,0);
 tolerance:=plantlab_lab.get_tolerance_limit(2,percent_value,t,p_method);
 return jsonb_build_object('replicates',reps,'total_tested',200,'unrounded_percent',raw_percent,
 case when method_code='SAND_25C' then 'germination_percent' else 'vigour_percent' end,percent_value,
 'calculation_code',c.calculation_code,'calculation_version',c.version,'routine_contract_version',c.version,'source_reference',c.source_reference,
 'gap_pp',hi-lo,'limit_pp',tolerance,'within_tolerance',(hi-lo)<=tolerance,
 'tolerance_status',case when tolerance is null then 'RULE_NOT_AVAILABLE' when hi-lo<=tolerance then 'WITHIN_SOURCE_TOLERANCE' else 'EXCEEDS_SOURCE_TOLERANCE' end,
 'authorizes_lot_release',false,'first_count_added_to_final',false,'final_categories',jsonb_build_array('normal','abnormal','fresh','hard','dead'));
end;
$$;

create function plantlab_lab.routine_draft_readiness(p_draft_id uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare d plantlab_lab.routine_drafts; code text; summary jsonb; blockers jsonb:='[]'; warnings jsonb:='[]'; parent plantlab_lab.test_runs; parent_content jsonb; decision_time timestamptz; started timestamptz; finished timestamptz;
begin
 select * into strict d from plantlab_lab.routine_drafts where id=p_draft_id;
 select method_code into strict code from plantlab_lab.methods where id=d.method_id;
 if exists(select from plantlab_lab.routine_submissions where draft_id=d.id) then blockers:=blockers||'[{"code":"SUBMITTED","message":"Revisi ini sudah dikirim dan dikunci."}]'; end if;
 if nullif(d.content->>'sample_reference','') is null then blockers:=blockers||'[{"code":"SAMPLE_REFERENCE","message":"Isi referensi atau label sampel yang benar."}]'; end if;
 if coalesce(length(d.content->>'note'),0)<3 then blockers:=blockers||'[{"code":"CONDITIONS","message":"Catat kondisi atau alat yang digunakan saat pengujian."}]'; end if;
 if d.content->>'received_at' is null or d.content->>'started_at' is null or d.content->>'final_at' is null then blockers:=blockers||'[{"code":"ACTUAL_TIMES","message":"Lengkapi waktu nyata sampel tersedia, mulai uji, dan pengamatan final."}]';
 else
 started:=(d.content->>'started_at')::timestamptz;finished:=(d.content->>'final_at')::timestamptz;
 if code='RET_16C_72H' and finished<started+interval'72hours' then blockers:=blockers||'[{"code":"RET_72H","message":"Pengamatan RET harus minimal72jam sejak ditempatkan pada16°C."}]'; end if;
 end if;
 begin summary:=plantlab_lab.calculate_routine_observations(d.method_id,d.content);
 exception when invalid_parameter_value then blockers:=blockers||'[{"code":"COUNTS","message":"Lengkapi seluruh hitungan. Tiap a/b harus50benih; RET4x100. Kosong bukan nol. Germinasi/Vigor biasa memerlukan2x100."}]'; end;
 if summary->'within_tolerance'='false'::jsonb then warnings:=warnings||'["Selisih di luar toleransi. QA tidak dapat menyetujui, tetapi dapat meminta uji ulang."]';
 elsif summary->'within_tolerance'='null'::jsonb then warnings:=warnings||'["Aturan toleransi tidak tersedia untuk nilai ini; approval QA akan ditahan."]'; end if;
 if exists(select from jsonb_array_elements(d.content->'observations') o where o->>'first_normal' is not null and (o->>'first_normal')::int>(o->>'final_normal')::int) then warnings:=warnings||'["Ada first count melebihi final count. Periksa klasifikasi dan jelaskan pada catatan untuk QA."]'; end if;
 select r.* into parent from plantlab_lab.routine_retest_drafts rt join plantlab_lab.test_runs r on r.id=rt.previous_run_id where rt.draft_id=d.id;
 if found then
 select s.draft_snapshot into strict parent_content from plantlab_lab.routine_submissions s where s.test_run_id=parent.id;
 select decided_at into decision_time from plantlab_lab.result_decisions where test_run_id=parent.id and decision='RETEST' order by id desc limit 1;
 if parent.status<>'RETEST' or decision_time is null or started<date_trunc('minute',decision_time) then blockers:=blockers||'[{"code":"RETEST_CLOCK","message":"Uji ulang memerlukan keputusan QA dan waktu mulai sesudah keputusan tersebut."}]'; end if;
 if started<coalesce(parent.completed_at,parent.started_at) then blockers:=blockers||'[{"code":"RETEST_PRIOR_FINAL","message":"Uji ulang tidak boleh mendahului pengamatan akhir percobaan sebelumnya."}]'; end if;
 if d.content->'sample_reference' is distinct from parent_content->'sample_reference' or d.content->'received_at' is distinct from parent_content->'received_at' then blockers:=blockers||'[{"code":"RETEST_SAMPLE","message":"Uji ulang ini memakai sampel yang sama; referensi dan waktu penerimaan awal harus tetap."}]'; end if;
 elsif exists(select from plantlab_lab.request_items i join plantlab_lab.requests q on q.id=i.request_id join plantlab_lab.test_types t on t.id=i.test_type_id
 where q.lot_id=d.lot_id and q.status not in('APPROVED','REJECTED','CLOSED','CANCELLED') and i.is_active
 and (i.requested_method_id=d.method_id or (code='SAND_25C' and t.test_code='GERMINATION' and i.requested_method_id is null))) then
 blockers:=blockers||'[{"code":"ACTIVE_WORK","message":"Ada pekerjaan aktif untuk lot dan metode ini. Periksa pekerjaan yang ada; uji ulang harus mengikuti keputusan QA."}]';
 end if;
 return jsonb_build_object('draft_id',d.id,'revision',d.revision,'ready',jsonb_array_length(blockers)=0,'blockers',blockers,'warnings',warnings,'summary',summary,'is_retest',parent.id is not null);
end;
$$;

create function plantlab_api.check_routine_lab_draft(p_draft_id uuid,p_expected_revision int)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d plantlab_lab.routine_drafts;
begin
 select * into d from plantlab_lab.routine_drafts where id=p_draft_id;
 if not found or not plantlab_lab.can_use_routine_lab(d.lab_site_id) then raise exception 'Assigned Lab role required' using errcode='42501'; end if;
 if d.revision is distinct from p_expected_revision then raise exception 'Reload latest draft revision' using errcode='40001'; end if;
 return plantlab_lab.routine_draft_readiness(d.id);
end;
$$;

-- Explicit receiving shortcut only for authenticated routine work with an actual
-- Lab sample receipt. Do not permit Plant to skip its custody workflow.
insert into plantlab_platform.status_transitions(module_code,entity_type,from_status,to_status,requires_reason)
values('LAB','REQUEST','DRAFT','RECEIVED',false);
alter table plantlab_core.samples drop constraint samples_type_ck;
alter table plantlab_core.samples add constraint samples_type_ck check(sample_type in('PROCESS','GROWER','LAB_REQUEST','GOT','COMPLAINT','GUARD','MARKET','RETAINED','LAB_ROUTINE'));

create or replace function plantlab_lab.enforce_request_transition_actor()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_company_id bigint;v_plant_handoff boolean:=false;
begin
 select l.company_id into v_company_id from plantlab_core.lots l where l.id=new.lot_id;
 if v_company_id is null then select coalesce(target_site.company_id,request_site.company_id) into v_company_id from plantlab_master.sites target_site left join plantlab_master.sites request_site on request_site.id=new.request_site_id where target_site.id=new.target_lab_site_id; end if;
 if old.status='DRAFT' and new.status='RECEIVED' and not coalesce((
 old.source_module='MANUAL' and new.source_module=old.source_module and old.source_entity='LAB_ROUTINE' and new.source_entity=old.source_entity
 and new.lot_id=old.lot_id and new.target_lab_site_id=old.target_lab_site_id and new.source_record_key=old.source_record_key
 and plantlab_platform.has_exact_scoped_role('LAB','LAB_ANALYST',new.target_lab_site_id,v_company_id)
 and exists(select from plantlab_lab.routine_drafts d join plantlab_lab.request_samples rs on rs.request_id=new.id and rs.is_primary
 join plantlab_core.samples s on s.id=rs.sample_id and s.source_module='LAB' and s.sample_type='LAB_ROUTINE' and s.lot_id=d.lot_id and s.status='RECEIVED'
 join plantlab_lab.sample_receipts receipt on receipt.request_sample_id=rs.id and receipt.decision='ACCEPT'
 where d.id::text=new.source_record_key and d.created_by=auth.uid() and d.lab_site_id=new.target_lab_site_id and d.lot_id=new.lot_id
 and receipt.source_received_at=(d.content->>'received_at')::timestamptz)),false) then
 raise exception 'Only verified routine Lab intake may use DRAFT to RECEIVED' using errcode='42501'; end if;
 if old.source_module='PLANT' and new.source_module=old.source_module and new.lot_id=old.lot_id and new.request_site_id=old.request_site_id and new.target_lab_site_id=old.target_lab_site_id
 and (old.status,new.status) in (('ACCEPTED','PREPARED'),('PREPARED','SENT')) and plantlab_platform.has_permission('PLANT','dispatch.write',old.request_site_id,v_company_id) then
 v_plant_handoff:=exists(select from plantlab_lab.request_samples rs join plantlab_core.samples s on s.id=rs.sample_id and s.lot_id=old.lot_id join plantlab_plant.sample_dispatches d on d.lab_request_id=rs.request_id and d.sample_id=s.id where rs.request_id=old.id and rs.is_primary and s.status=new.status and d.status=new.status and d.source_site_id=old.request_site_id and d.target_lab_site_id=old.target_lab_site_id);
 end if;
 if old.status<>'DRAFT' and not v_plant_handoff and not plantlab_platform.has_permission('LAB','request.write',new.target_lab_site_id,v_company_id) then raise exception 'Only assigned site may advance Lab work' using errcode='42501'; end if;
 if old.status='IN_REVIEW' and new.status in('APPROVED','REJECTED','RETEST') then
 if not plantlab_platform.has_permission('LAB','result.approve',new.target_lab_site_id,v_company_id) then raise exception 'result.approve required' using errcode='42501'; end if;
 if new.status='APPROVED' and exists(select from plantlab_lab.request_items ri where ri.request_id=new.id and ri.is_active and ri.status<>'APPROVED') then raise exception 'All active items must be approved first' using errcode='23514'; end if;
 end if;
 return new;
end;
$$;

-- Original Plant-request guards stay in the ELSE branch. Routine counts have a
-- dedicated immutable five-category table, not a lossy three-category projection.
create or replace function plantlab_lab.guard_confirmed_germination_contract()
returns trigger language plpgsql security definer set search_path='' as $$
declare c plantlab_lab.confirmed_method_contracts;s plantlab_lab.routine_submissions;summary jsonb;
begin
 if new.event_type<>'OBSERVED_FINAL' then return new; end if;
 select * into s from plantlab_lab.routine_submissions where test_run_id=new.test_run_id;
 if found then
 summary:=plantlab_lab.calculate_routine_observations(s.contract_method_id,s.draft_snapshot);
 if new.metadata->'replicates' is distinct from summary->'replicates' then raise exception 'Routine counts differ from sealed draft snapshot' using errcode='23514'; end if;
 new.metadata:=new.metadata||summary||jsonb_build_object('routine_draft_id',s.draft_id,'routine_draft_revision',s.draft_revision,'routine_contract_version',1);
 return new;
 end if;
 select contract.* into c from plantlab_lab.test_runs run join plantlab_lab.methods m on m.id=run.method_id and m.method_code='SAND_25C' join plantlab_lab.confirmed_method_contracts contract on contract.method_id=m.id where run.id=new.test_run_id and run.created_at>=contract.effective_from order by contract.contract_version desc limit 1;
 if found then perform plantlab_lab.validate_confirmed_germination_counts(new.metadata->'replicates');new.metadata:=new.metadata||jsonb_build_object('input_contract',jsonb_build_object('contract_id',c.id,'contract_version',c.contract_version,'replicate_count',2,'seeds_per_replicate',100)); end if;
 return new;
end;
$$;

create or replace function plantlab_lab.validate_test_run_workflow()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_missing_required int;v_item_status text;v_request_status text;v_requires_observations boolean;
begin
 if old.status='IN_REVIEW' and new.status in('APPROVED','REJECTED','RETEST') and current_setting('app.result_decision_context',true) is distinct from 'on' then raise exception 'Final Test Run status requires result_decisions' using errcode='42501'; end if;
 if new.status='IN_PROGRESS' and old.status is distinct from new.status then
 select ri.status,r.status into v_item_status,v_request_status from plantlab_lab.request_items ri join plantlab_lab.requests r on r.id=ri.request_id where ri.id=new.request_item_id;
 if v_item_status not in('READY','TESTING') or v_request_status not in('RECEIVED','TESTING') then raise exception 'Received/ready work required' using errcode='23514'; end if;
 new.started_at:=coalesce(new.started_at,now());new.performed_by:=coalesce(new.performed_by,auth.uid());
 end if;
 if new.status='SUBMITTED' and old.status is distinct from new.status then
 select ri.status into v_item_status from plantlab_lab.request_items ri where ri.id=new.request_item_id;
 if v_item_status<>'TESTING' then raise exception 'Item must be TESTING' using errcode='23514'; end if;
 select count(*)::int into v_missing_required from plantlab_lab.request_items ri join plantlab_lab.test_type_parameters ttp on ttp.test_type_id=ri.test_type_id and ttp.is_required left join plantlab_lab.result_values rv on rv.test_run_id=new.id and rv.parameter_id=ttp.parameter_id where ri.id=new.request_item_id and rv.id is null;
 if v_missing_required>0 then raise exception 'Required results missing' using errcode='23514'; end if;
 select coalesce(mtt.requires_replicate_observations,false) into v_requires_observations from plantlab_lab.method_test_types mtt where mtt.method_id=new.method_id and mtt.test_type_id=(select test_type_id from plantlab_lab.request_items where id=new.request_item_id);
 if coalesce(v_requires_observations,false) then
 if exists(select from plantlab_lab.methods where id=new.method_id and method_code='RET_16C_72H') then
 if not exists(select from plantlab_lab.ret_run_protocols where test_run_id=new.id and method_id=new.method_id) or (select count(*) from plantlab_lab.ret_radicle_observations where test_run_id=new.id and tested=100)<>4 then raise exception 'Four dedicated RET observations/protocol required' using errcode='23514'; end if;
 elsif exists(select from plantlab_lab.routine_submissions where test_run_id=new.id) then
 if (select count(*) from plantlab_lab.routine_count_observations where test_run_id=new.id)<>4 then raise exception 'Four actual routine subreplicates required' using errcode='23514'; end if;
 elsif not exists(select from plantlab_lab.test_run_observations where test_run_id=new.id and observation_phase='FINAL') then raise exception 'Final observations missing' using errcode='23514'; end if;
 if not exists(select from plantlab_lab.test_run_events where test_run_id=new.id and event_type='OBSERVED_FINAL') then raise exception 'Final event missing' using errcode='23514'; end if;
 end if;
 new.completed_at:=coalesce(new.completed_at,now());new.submitted_at:=coalesce(new.submitted_at,now());
 end if;
 return new;
end;
$$;

create function plantlab_lab.replay_routine_workflow(p_command text,p_action uuid,p_payload jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare a plantlab_lab.routine_workflow_actions;
begin
 if p_action is null then raise exception 'Action ID required' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('ROUTINE_WORKFLOW:'||auth.uid()||':'||p_action,0));
 select * into a from plantlab_lab.routine_workflow_actions where actor_id=auth.uid() and action_id=p_action;
 if found then
 if a.command<>p_command or a.payload is distinct from p_payload then raise exception 'Action ID reused with different details' using errcode='23505'; end if;
 return a.response;
 end if;
 return null;
end;
$$;

create function plantlab_api.submit_routine_lab_draft(p_draft_id uuid,p_expected_revision int,p_actual_work_confirmed boolean,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d plantlab_lab.routine_drafts;check_result jsonb;summary jsonb;payload jsonb;response jsonb;lot plantlab_core.lots;method plantlab_lab.methods;parent plantlab_lab.test_runs;run plantlab_lab.test_runs;q plantlab_lab.requests;cycle plantlab_lab.test_cycles;item uuid;sample uuid;rs uuid;receipt uuid;assignment uuid;test_type uuid;parameter uuid;started timestamptz;finished timestamptz;incoming timestamptz;reason text;row jsonb;idx int:=0;value numeric;
begin
 select * into d from plantlab_lab.routine_drafts where id=p_draft_id;
 if not found or d.created_by is distinct from auth.uid() or not plantlab_lab.can_use_routine_lab(d.lab_site_id,true) then raise exception 'Original assigned analyst required' using errcode='42501'; end if;
 payload:=jsonb_build_object('draft_id',p_draft_id,'expected_revision',p_expected_revision,'actual_work_confirmed',p_actual_work_confirmed);
 response:=plantlab_lab.replay_routine_workflow('SUBMIT',p_action_id,payload);if response is not null then return response; end if;
 if p_actual_work_confirmed is distinct from true then raise exception 'Confirm actual sample and observations, not practice data' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('ROUTINE_DRAFT:'||p_draft_id,0));
 select * into strict d from plantlab_lab.routine_drafts where id=p_draft_id for update;
 if d.revision is distinct from p_expected_revision then raise exception 'Reload latest saved revision' using errcode='40001'; end if;
 -- Serialize two drafts for the same lot/method before the active-work check.
 perform pg_advisory_xact_lock(hashtextextended('ROUTINE_LOT_METHOD:'||d.lot_id||':'||d.method_id,0));
 check_result:=plantlab_lab.routine_draft_readiness(d.id);
 if check_result->'ready' is distinct from 'true'::jsonb then raise exception 'Complete/check saved draft first' using errcode='22023'; end if;
 summary:=check_result->'summary';started:=(d.content->>'started_at')::timestamptz;finished:=(d.content->>'final_at')::timestamptz;incoming:=(d.content->>'received_at')::timestamptz;
 select * into strict lot from plantlab_core.lots where id=d.lot_id;
 select * into strict method from plantlab_lab.methods where id=d.method_id and is_active;
 select id into strict test_type from plantlab_lab.test_types where test_code=case when method.method_code='SAND_25C' then 'GERMINATION' else 'VIGOUR' end and is_active;
 select r.* into parent from plantlab_lab.routine_retest_drafts rt join plantlab_lab.test_runs r on r.id=rt.previous_run_id where rt.draft_id=d.id for update of r;
 if parent.id is null then
 insert into plantlab_lab.requests(source_module,source_entity,source_record_key,lot_id,product_id,request_site_id,target_lab_site_id,requested_by,created_by,idempotency_key)
 values('MANUAL','LAB_ROUTINE',d.id::text,lot.id,lot.product_id,d.lab_site_id,d.lab_site_id,auth.uid(),auth.uid(),'ROUTINE:'||d.id) returning * into q;
 insert into plantlab_lab.request_items(request_id,test_type_id,requested_method_id,created_by) values(q.id,test_type,method.id,auth.uid()) returning id into item;
 update plantlab_lab.request_items set status='REQUESTED',updated_by=auth.uid() where id=item;
 insert into plantlab_core.samples(lot_id,sample_type,source_module,source_site_id,sample_condition,metadata,created_by)
 values(lot.id,'LAB_ROUTINE','LAB',d.lab_site_id,d.content->>'note',jsonb_build_object('origin','LAB_ROUTINE','sample_reference',d.content->>'sample_reference','actual_available_at',incoming),auth.uid()) returning id into sample;
 insert into plantlab_lab.request_samples(request_id,sample_id,purpose,is_primary,linked_by) values(q.id,sample,'LAB_ROUTINE',true,auth.uid()) returning id into rs;
 select id into receipt from plantlab_lab.record_sample_receipt_v2(rs,'ACCEPT',null,null,d.content->>'note',null,d.content->>'sample_reference',incoming);
 update plantlab_lab.requests set status='RECEIVED',updated_by=auth.uid() where id=q.id;
 else
 item:=parent.request_item_id;
 select requests.* into strict q from plantlab_lab.requests requests join plantlab_lab.request_items i on i.request_id=requests.id where i.id=item;
 sample:=parent.sample_id;
 select sr.id into strict receipt from plantlab_lab.sample_receipts sr join plantlab_lab.request_samples link on link.id=sr.request_sample_id where link.request_id=q.id and link.sample_id=sample and link.is_primary and sr.decision='ACCEPT';
 select rd.reason into strict reason from plantlab_lab.result_decisions rd where rd.test_run_id=parent.id and rd.decision='RETEST' order by rd.id desc limit 1;
 perform set_config('app.status_reason',reason,true);
 update plantlab_lab.request_items set status='TESTING',status_reason=reason,updated_by=auth.uid() where id=item and status='RETEST';
 update plantlab_lab.requests set status='TESTING',status_reason=reason,updated_by=auth.uid() where id=q.id and status='RETEST';
 end if;
 if parent.id is null then update plantlab_lab.request_items set status='READY',updated_by=auth.uid() where id=item; end if;
 select * into cycle from plantlab_lab.create_test_cycle(q.id,sample,case when parent.id is null then 'INITIAL' else 'RETEST' end,parent.test_cycle_id,receipt,case when method.method_code='SAND_25C' then 'GERMINATION' else 'VIGOUR' end,reason,'ROUTINE:'||d.id,jsonb_build_object('routine_draft_id',d.id));
 update plantlab_lab.test_cycles set status='ACTIVE',started_at=started,updated_by=auth.uid() where id=cycle.id;
 insert into plantlab_lab.test_assignments(request_item_id,sample_id,analyst_id,method_id,assigned_by) values(item,sample,auth.uid(),method.id,auth.uid()) returning id into assignment;
 update plantlab_lab.test_assignments set status='ACCEPTED',accepted_at=now() where id=assignment;
 update plantlab_lab.test_assignments set status='IN_PROGRESS' where id=assignment;
 insert into plantlab_lab.test_runs(assignment_id,request_item_id,sample_id,method_id,test_cycle_id,attempt_no,retest_of_id,started_at,created_by)
 values(assignment,item,sample,method.id,cycle.id,coalesce(parent.attempt_no,0)+1,parent.id,started,auth.uid()) returning * into run;
 insert into plantlab_lab.routine_submissions values(run.id,d.id,d.revision,method.id,d.content,auth.uid(),now());
 if method.method_code<>'SAND_25C' then insert into plantlab_lab.vigour_run_contexts(test_run_id,calculation_method_id,actual_started_at,conditions_note,created_by) values(run.id,method.id,started,d.content->>'note',auth.uid()); end if;
 perform plantlab_lab.advance_test_run(run.id,'IN_PROGRESS');
 perform plantlab_lab.record_test_run_event(run.id,'PLANTED',started,null,jsonb_build_object('origin','LAB_ROUTINE','conditions_note',d.content->>'note'),'ROUTINE_START:'||run.id);
 for row in select x from jsonb_array_elements(d.content->'observations') x loop
 idx:=idx+1;
 if method.method_code='RET_16C_72H' then insert into plantlab_lab.ret_radicle_observations(test_run_id,replicate_no,tested,radicle_at_least_2mm,observed_at,recorded_by) values(run.id,idx,100,(row->>'radicle_at_least_2mm')::int,finished,auth.uid());
 else insert into plantlab_lab.routine_count_observations values(run.id,idx,(row->>'first_normal')::int,(row->>'final_normal')::int,(row->>'abnormal')::int,(row->>'fresh')::int,(row->>'hard')::int,(row->>'dead')::int,finished,auth.uid()); end if;
 end loop;
 select id into strict parameter from plantlab_lab.parameters where parameter_code=case when method.method_code='SAND_25C' then 'GERMINATION_PERCENT' else 'VIGOUR_PERCENT' end;
 value:=coalesce((summary->>'germination_percent')::numeric,(summary->>'vigour_percent')::numeric);
 insert into plantlab_lab.result_values(test_run_id,parameter_id,numeric_value,unit_code,recorded_by) values(run.id,parameter,value,'PERCENT',auth.uid());
 summary:=summary||jsonb_build_object('observed_at',finished,'observation_note',d.content->>'note','physical_protocol_verified',false,'origin','LAB_ROUTINE');
 if method.method_code='RET_16C_72H' then summary:=summary||jsonb_build_object('duration_start_event','PLACED_AT_16C','minimum_duration_hours',72,'elapsed_hours',extract(epoch from(finished-started))/3600.0,'elapsed_requirement_met',finished>=started+interval'72hours','protocol_snapshot',(select to_jsonb(p)-'created_at' from plantlab_lab.ret_run_protocols p where p.test_run_id=run.id)); end if;
 perform plantlab_lab.record_test_run_event(run.id,'OBSERVED_FINAL',finished,null,summary,'ROUTINE_FINAL:'||run.id);
 update plantlab_lab.test_runs set completed_at=finished where id=run.id;
 perform plantlab_lab.advance_test_run(run.id,'SUBMITTED');perform plantlab_lab.record_test_run_event(run.id,'SUBMITTED');
 select * into run from plantlab_lab.advance_test_run(run.id,'IN_REVIEW');
 update plantlab_lab.test_assignments set status='COMPLETED' where id=assignment;
 update plantlab_lab.test_cycles set status='COMPLETED',completed_at=finished,updated_by=auth.uid() where id=cycle.id;
 response:=jsonb_build_object('draft_id',d.id,'run_id',run.id,'run_code',run.test_code,'status',run.status,'attempt_no',run.attempt_no);
 insert into plantlab_lab.routine_workflow_actions values(auth.uid(),p_action_id,'SUBMIT',payload,response,now());
 return response;
end;
$$;

-- Enforce the same review boundary even if an older command reaches the row.
create function plantlab_lab.guard_routine_result_decision()
returns trigger language plpgsql security definer set search_path='' as $$
declare d plantlab_lab.routine_drafts;r plantlab_lab.test_runs;summary jsonb;
begin
 select draft.* into d from plantlab_lab.routine_submissions s join plantlab_lab.routine_drafts draft on draft.id=s.draft_id where s.test_run_id=new.test_run_id;
 if not found then return new;end if;
 select * into strict r from plantlab_lab.test_runs where id=new.test_run_id;
 if not plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',d.lab_site_id,(select company_id from plantlab_core.lots where id=d.lot_id))
 or new.reviewer_id is distinct from auth.uid() or r.performed_by is null or r.performed_by=auth.uid() then raise exception 'Independent assigned routine QA required' using errcode='42501';end if;
 if new.decision not in('APPROVE','RETEST') or coalesce(length(btrim(new.reason)),0) not between 3 and 1000
 or new.metadata->>'origin' is distinct from 'LAB_ROUTINE' or new.metadata->'protocol_checked_by_reviewer' is distinct from 'true'::jsonb then raise exception 'Use explicit routine QA review with reason and protocol confirmation' using errcode='23514';end if;
 select metadata into strict summary from plantlab_lab.test_run_events where test_run_id=r.id and idempotency_key='ROUTINE_FINAL:'||r.id;
 if new.decision='APPROVE' and summary->'within_tolerance' is distinct from 'true'::jsonb then raise exception 'Routine tolerance unavailable/exceeded' using errcode='23514';end if;
 return new;
end;
$$;
create trigger routine_result_decision_guard before insert on plantlab_lab.result_decisions for each row execute function plantlab_lab.guard_routine_result_decision();
revoke all on function plantlab_lab.guard_routine_result_decision() from PUBLIC,anon,authenticated,service_role;

create function plantlab_api.review_routine_lab_result(p_run_id uuid,p_decision text,p_reason text,p_protocol_checked boolean,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d plantlab_lab.routine_drafts;run plantlab_lab.test_runs;summary jsonb;decision plantlab_lab.result_decisions;payload jsonb;response jsonb;choice text:=upper(btrim(p_decision));reason text:=btrim(p_reason);
begin
 select draft.* into d from plantlab_lab.routine_submissions s join plantlab_lab.routine_drafts draft on draft.id=s.draft_id where s.test_run_id=p_run_id;
 if not found or not plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',d.lab_site_id,(select company_id from plantlab_core.lots where id=d.lot_id)) then raise exception 'Assigned QA required' using errcode='42501'; end if;
 payload:=jsonb_build_object('run_id',p_run_id,'decision',choice,'reason',reason,'protocol_checked',p_protocol_checked);
 response:=plantlab_lab.replay_routine_workflow('REVIEW',p_action_id,payload);if response is not null then return response; end if;
 select * into strict run from plantlab_lab.test_runs where id=p_run_id for update;
 if run.performed_by is null or run.performed_by=auth.uid() then raise exception 'Independent QA required' using errcode='42501'; end if;
 if run.status<>'IN_REVIEW' then raise exception 'Run not awaiting QA' using errcode='55000'; end if;
 if choice is null or choice not in('APPROVE','RETEST') or coalesce(length(reason),0) not between 3 and 1000 or p_protocol_checked is distinct from true then raise exception 'Decision, reason and explicit review confirmation required' using errcode='22023'; end if;
 select metadata into strict summary from plantlab_lab.test_run_events where test_run_id=run.id and idempotency_key='ROUTINE_FINAL:'||run.id;
 if choice='APPROVE' and summary->'within_tolerance' is distinct from 'true'::jsonb then raise exception 'Missing/exceeded tolerance blocks approval' using errcode='23514'; end if;
 select * into decision from plantlab_lab.decide_test_run(run.id,choice,reason,jsonb_build_object('origin','LAB_ROUTINE','review_scope','ANALYTICAL_RESULT_NOT_LOT_RELEASE','protocol_checked_by_reviewer',true));
 response:=jsonb_build_object('run_id',run.id,'status',decision.resulting_status,'run_code',run.test_code);
 insert into plantlab_lab.routine_workflow_actions values(auth.uid(),p_action_id,'REVIEW',payload,response,now());
 return response;
end;
$$;

create function plantlab_api.create_routine_retest_draft(p_run_id uuid,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare old_draft plantlab_lab.routine_drafts;new_draft plantlab_lab.routine_drafts;run plantlab_lab.test_runs;payload jsonb;response jsonb;content jsonb;observations jsonb:='[]';r jsonb;k text;blank_row jsonb;
begin
 select d.* into old_draft from plantlab_lab.routine_submissions s join plantlab_lab.routine_drafts d on d.id=s.draft_id where s.test_run_id=p_run_id;
 if not found or not plantlab_lab.can_use_routine_lab(old_draft.lab_site_id,true) then raise exception 'Assigned Analyst required' using errcode='42501'; end if;
 payload:=jsonb_build_object('run_id',p_run_id);
 response:=plantlab_lab.replay_routine_workflow('RETEST_DRAFT',p_action_id,payload);if response is not null then return response; end if;
 select * into strict run from plantlab_lab.test_runs where id=p_run_id for update;
 if run.status<>'RETEST' or not exists(select from plantlab_lab.result_decisions where test_run_id=p_run_id and decision='RETEST') then raise exception 'QA-authorized retest required' using errcode='55000'; end if;
 select d.* into new_draft from plantlab_lab.routine_retest_drafts rt join plantlab_lab.routine_drafts d on d.id=rt.draft_id where rt.previous_run_id=p_run_id;
 if found then
 if new_draft.created_by<>auth.uid() then raise exception 'Retest already assigned to another Analyst' using errcode='42501'; end if;
 else
 for r in select value from jsonb_array_elements(old_draft.content->'observations') loop
 blank_row:='{}';for k in select jsonb_object_keys(r) loop blank_row:=blank_row||jsonb_build_object(k,null);end loop;
 observations:=observations||jsonb_build_array(blank_row);
 end loop;
 content:=old_draft.content||jsonb_build_object('started_at',null,'final_at',null,'note',null,'observations',observations);
 insert into plantlab_lab.routine_drafts(id,lab_site_id,lot_id,method_id,created_by,revision,content) values(gen_random_uuid(),old_draft.lab_site_id,old_draft.lot_id,old_draft.method_id,auth.uid(),1,content) returning * into new_draft;
 insert into plantlab_lab.routine_retest_drafts values(new_draft.id,p_run_id,now());
 insert into plantlab_lab.routine_draft_revisions values(new_draft.id,1,auth.uid(),gen_random_uuid(),jsonb_build_object('origin','QA_RETEST','previous_run_id',p_run_id),jsonb_build_object('draft_id',new_draft.id,'revision',1,'status','DRAFT'),now());
 end if;
 response:=jsonb_build_object('draft_id',new_draft.id,'revision',new_draft.revision,'status','DRAFT');
 insert into plantlab_lab.routine_workflow_actions values(auth.uid(),p_action_id,'RETEST_DRAFT',payload,response,now());return response;
end;
$$;

-- Keep legacy request queues focused on actual Plant/other existing requests;
-- routine work is presented in its own workspace, not counted as Plant requests.
create or replace function plantlab_api.list_lab_requests(p_module text,p_limit int default 50,p_offset int default 0)
returns table(request_id uuid,request_code text,lot_id uuid,lot_code text,product_id bigint,request_site_id uuid,target_lab_site_id uuid,test_codes text[],status text,priority text,requested_at timestamptz,due_at timestamptz,sampling_instruction text)
language sql stable security invoker set search_path='' as $$
 select r.id,r.request_code,r.lot_id,l.lot_code,r.product_id,r.request_site_id,r.target_lab_site_id,
 array(select distinct tt.test_code from plantlab_lab.request_items ri join plantlab_lab.test_types tt on tt.id=ri.test_type_id where ri.request_id=r.id and ri.is_active order by tt.test_code),r.status,r.priority,r.requested_at,r.due_at,r.sampling_instruction
 from plantlab_lab.requests r left join plantlab_core.lots l on l.id=r.lot_id join plantlab_master.sites target_site on target_site.id=r.target_lab_site_id left join plantlab_master.sites request_site on request_site.id=r.request_site_id
 where auth.uid() is not null and r.source_entity is distinct from 'LAB_ROUTINE' and case upper(btrim(p_module))
 when 'LAB' then plantlab_platform.has_permission('LAB','request.read',r.target_lab_site_id,coalesce(l.company_id,target_site.company_id,request_site.company_id))
 when 'PLANT' then r.source_module='PLANT' and r.request_site_id is not null and r.status<>'DRAFT' and plantlab_platform.has_permission('PLANT','request.read',r.request_site_id,coalesce(l.company_id,target_site.company_id,request_site.company_id)) else false end
 order by coalesce(r.requested_at,r.created_at) desc,r.id desc limit least(greatest(coalesce(p_limit,50),0),100) offset greatest(coalesce(p_offset,0),0);
$$;

create function plantlab_lab.routine_workflow_details(p_draft uuid)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('run_id',r.id,'run_code',r.test_code,'status',r.status,'attempt_no',r.attempt_no,'parent_run_id',r.retest_of_id,
 'summary',e.metadata,'analyst_id',r.performed_by,'reviewer_id',decision.reviewer_id,'review_reason',decision.reason,'reviewed_at',decision.decided_at,
 'can_review',r.status='IN_REVIEW' and r.performed_by is distinct from auth.uid() and plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',d.lab_site_id,l.company_id),
 'can_retest',r.status='RETEST' and plantlab_lab.can_use_routine_lab(d.lab_site_id,true) and not exists(select from plantlab_lab.routine_retest_drafts where previous_run_id=r.id))
 from plantlab_lab.routine_submissions s join plantlab_lab.routine_drafts d on d.id=s.draft_id join plantlab_core.lots l on l.id=d.lot_id join plantlab_lab.test_runs r on r.id=s.test_run_id
 left join plantlab_lab.test_run_events e on e.test_run_id=r.id and e.idempotency_key='ROUTINE_FINAL:'||r.id
 left join lateral(select reviewer_id,reason,decided_at from plantlab_lab.result_decisions where test_run_id=r.id order by id desc limit 1) decision on true where s.draft_id=p_draft;
$$;
create or replace function plantlab_api.list_routine_lab_drafts(p_lab_site_id uuid,p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not plantlab_lab.can_use_routine_lab(p_lab_site_id) then raise exception 'Assigned Lab role required' using errcode='42501'; end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid offset' using errcode='22023'; end if;
 with records as materialized(select d.id,d.revision,coalesce(w.workflow->>'status',d.status) as status,d.lot_id,l.lot_code,l.stage_code,p.name as hybrid,m.method_code,m.method_name,d.content,d.created_by,d.updated_at,
 (d.created_by=auth.uid() and plantlab_lab.can_use_routine_lab(d.lab_site_id,true) and w.workflow is null) as can_edit,w.workflow,
 rt.previous_run_id as retest_of_run_id
 from plantlab_lab.routine_drafts d join plantlab_core.lots l on l.id=d.lot_id join plantlab_master.products p on p.id=l.product_id join plantlab_lab.methods m on m.id=d.method_id left join lateral(select plantlab_lab.routine_workflow_details(d.id) as workflow) w on true left join plantlab_lab.routine_retest_drafts rt on rt.draft_id=d.id where d.lab_site_id=p_lab_site_id),page as(select * from records order by updated_at desc,id limit 50 offset p_offset)
 select jsonb_build_object('drafts',coalesce((select jsonb_agg(to_jsonb(page) order by updated_at desc,id) from page),'[]'::jsonb),'total',(select count(*) from records),'offset',p_offset,'has_more',(select count(*)>p_offset+50 from records)) into result;return result;
end;
$$;

create function plantlab_api.list_approved_routine_lab_results(p_module text,p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or upper(btrim(p_module)) not in('PLANT','LAB') then raise exception 'Assigned application role required' using errcode='42501'; end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid offset' using errcode='22023'; end if;
 with records as materialized(select d.id,d.revision,r.status,d.lot_id,l.lot_code,l.stage_code,p.name as hybrid,m.method_code,m.method_name,s.draft_snapshot as content,false as can_edit,r.updated_at,
 plantlab_lab.routine_workflow_details(d.id) as workflow
 from plantlab_lab.routine_submissions s join plantlab_lab.routine_drafts d on d.id=s.draft_id join plantlab_core.lots l on l.id=d.lot_id join plantlab_master.products p on p.id=l.product_id join plantlab_lab.methods m on m.id=d.method_id join plantlab_lab.test_runs r on r.id=s.test_run_id
 where r.status='APPROVED' and case upper(btrim(p_module)) when 'PLANT' then plantlab_platform.has_permission('PLANT','result.read',l.plant_site_id,l.company_id) else plantlab_lab.can_use_routine_lab(d.lab_site_id) end),
 page as(select * from records order by (content->>'final_at')::timestamptz desc,id limit 50 offset p_offset)
 select jsonb_build_object('results',coalesce((select jsonb_agg(to_jsonb(page) order by (content->>'final_at')::timestamptz desc,id) from page),'[]'::jsonb),'total',(select count(*) from records),'offset',p_offset,'has_more',(select count(*)>p_offset+50 from records)) into result;
 return result;
end;
$$;

create function plantlab_api.get_routine_lab_record(p_draft_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d plantlab_lab.routine_drafts;result jsonb;
begin
 select * into d from plantlab_lab.routine_drafts where id=p_draft_id;
 if not found or not plantlab_lab.can_use_routine_lab(d.lab_site_id) then raise exception 'Assigned Lab role required' using errcode='42501'; end if;
 select to_jsonb(record) into result from(select d.id,d.revision,coalesce(w.workflow->>'status',d.status) as status,d.lab_site_id,d.lot_id,l.lot_code,l.stage_code,p.name as hybrid,m.method_code,m.method_name,d.content,d.created_by,d.updated_at,
 (d.created_by=auth.uid() and plantlab_lab.can_use_routine_lab(d.lab_site_id,true) and w.workflow is null) as can_edit,w.workflow,rt.previous_run_id as retest_of_run_id
 from plantlab_core.lots l join plantlab_master.products p on p.id=l.product_id join plantlab_lab.methods m on m.id=d.method_id left join lateral(select plantlab_lab.routine_workflow_details(d.id) as workflow) w on true left join plantlab_lab.routine_retest_drafts rt on rt.draft_id=d.id where l.id=d.lot_id) record;
 return result;
end;
$$;

revoke all on function plantlab_lab.freeze_submitted_routine_draft(),plantlab_lab.guard_routine_count_input(),plantlab_lab.calculate_routine_observations(uuid,jsonb),plantlab_lab.routine_draft_readiness(uuid),plantlab_lab.replay_routine_workflow(text,uuid,jsonb),plantlab_lab.routine_workflow_details(uuid) from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_api.check_routine_lab_draft(uuid,int),plantlab_api.submit_routine_lab_draft(uuid,int,boolean,uuid),plantlab_api.review_routine_lab_result(uuid,text,text,boolean,uuid),plantlab_api.create_routine_retest_draft(uuid,uuid),plantlab_api.list_approved_routine_lab_results(text,int),plantlab_api.get_routine_lab_record(uuid) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.check_routine_lab_draft(uuid,int),plantlab_api.submit_routine_lab_draft(uuid,int,boolean,uuid),plantlab_api.review_routine_lab_result(uuid,text,text,boolean,uuid),plantlab_api.create_routine_retest_draft(uuid,uuid),plantlab_api.list_approved_routine_lab_results(text,int),plantlab_api.get_routine_lab_record(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
