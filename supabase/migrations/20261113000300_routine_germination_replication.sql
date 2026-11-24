-- Owner13Nov: routine Germination offers2x100 and4x100; default remains2.
-- Additive contract. Do not rewrite existing observations/results/contracts.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create table plantlab_lab.routine_replication_contracts (
 id uuid primary key default gen_random_uuid(),
 method_id uuid not null references plantlab_lab.routine_calculation_contracts(method_id),
 version int not null check(version=1),
 replicate_count int not null check(replicate_count=4),
 seeds_per_replicate int not null check(seeds_per_replicate=100),
 calculation_code text not null check(calculation_code='ROUTINE_ROUND_MEAN_4X100_V1'),
 source_reference text not null,source_sha256 text not null,
 effective_from timestamptz not null default now(),unique(method_id,replicate_count,version)
);
insert into plantlab_lab.routine_replication_contracts(method_id,version,replicate_count,seeds_per_replicate,calculation_code,source_reference,source_sha256)
select id,1,4,100,'ROUTINE_ROUND_MEAN_4X100_V1',
 'Owner13Nov2026:provide2x100and4x100 routine Germination. KC Lab Germ&Vigor:paired50-seed subreps,ROUND(mean four Normal totals),4-Reps tolerance. First count not added to cumulative final.',
 '5595f8bb17b2763a11f6139572bfb595c37e4ed4529904014277268e3d2306b8'
from plantlab_lab.methods where method_code='SAND_25C' and is_active;
alter table plantlab_lab.routine_replication_contracts enable row level security;
revoke all on plantlab_lab.routine_replication_contracts from PUBLIC,anon,authenticated,service_role;
create trigger routine_replication_contract_immutable before update or delete on plantlab_lab.routine_replication_contracts for each row execute function plantlab_lab.guard_uac_reference_history();
alter table plantlab_lab.routine_submissions add column replication_contract_id uuid references plantlab_lab.routine_replication_contracts(id);
alter table plantlab_lab.routine_count_observations drop constraint routine_count_observations_subrep_no_check;
alter table plantlab_lab.routine_count_observations add constraint routine_count_observations_subrep_no_check check(subrep_no between 1 and 8);

create function plantlab_lab.seal_routine_replication_contract()
returns trigger language plpgsql security definer set search_path='' as $$
declare code text;
begin
 select method_code into strict code from plantlab_lab.methods where id=new.contract_method_id;
 if code='SAND_25C' and new.draft_snapshot->>'replicate_count'='4' then
 select id into strict new.replication_contract_id from plantlab_lab.routine_replication_contracts where method_id=new.contract_method_id and replicate_count=4 and version=1;
 elsif new.replication_contract_id is not null then raise exception 'Replication contract does not match observations' using errcode='23514';end if;
 return new;
end;
$$;
create trigger routine_submission_replication_contract before insert on plantlab_lab.routine_submissions for each row execute function plantlab_lab.seal_routine_replication_contract();

-- Same convention as saved lot/method: choose before first save, then retain it.
create function plantlab_lab.guard_routine_replication_choice()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.content->'replicate_count' is distinct from old.content->'replicate_count' then raise exception 'Saved replicate count locked; retain original design' using errcode='22023';end if;
 return new;
end;
$$;
create trigger routine_replication_choice before update on plantlab_lab.routine_drafts for each row execute function plantlab_lab.guard_routine_replication_choice();

-- Preserve the exact old2x100/RET implementation and delegate unchanged cases.
alter function plantlab_lab.calculate_routine_observations(uuid,jsonb) rename to calculate_routine_observations_v1;
create function plantlab_lab.calculate_routine_observations(p_method uuid,p_content jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare contract plantlab_lab.routine_replication_contracts;t uuid;content jsonb;r jsonb;a jsonb;b jsonb;reps jsonb:='[]';first_value int;total_normal int:=0;normal_value int;lo int:=100;hi int:=0;raw_percent numeric;percent_value numeric;tolerance numeric;k text;x int;
begin
 if not exists(select from plantlab_lab.methods where id=p_method and method_code='SAND_25C') or p_content->>'replicate_count' is distinct from '4' then return plantlab_lab.calculate_routine_observations_v1(p_method,p_content);end if;
 select * into strict contract from plantlab_lab.routine_replication_contracts where method_id=p_method and replicate_count=4 and version=1;
 content:=plantlab_lab.normalize_routine_draft('SAND_25C',p_content);
 select id into strict t from plantlab_lab.test_types where test_code='GERMINATION';
 for r in select value from jsonb_array_elements(content->'observations') loop
 foreach k in array array['final_normal','abnormal','fresh','hard','dead'] loop
 if r->k='null'::jsonb then raise exception 'All five final categories required; unknown is not zero' using errcode='22023';end if;
 end loop;
 if (r->>'final_normal')::int+(r->>'abnormal')::int+(r->>'fresh')::int+(r->>'hard')::int+(r->>'dead')::int<>50 then raise exception 'Every final a/b must total50' using errcode='22023';end if;
 end loop;
 for x in 0..3 loop
 a:=content->'observations'->(x*2);b:=content->'observations'->(x*2+1);
 normal_value:=(a->>'final_normal')::int+(b->>'final_normal')::int;
 first_value:=case when a->'first_normal'<>'null'::jsonb and b->'first_normal'<>'null'::jsonb then (a->>'first_normal')::int+(b->>'first_normal')::int end;
 reps:=reps||jsonb_build_array(jsonb_build_object('normal',normal_value,'abnormal',(a->>'abnormal')::int+(b->>'abnormal')::int,'fresh',(a->>'fresh')::int+(b->>'fresh')::int,'hard',(a->>'hard')::int+(b->>'hard')::int,'dead',(a->>'dead')::int+(b->>'dead')::int,'first_normal',first_value));
 total_normal:=total_normal+normal_value;lo:=least(lo,normal_value);hi:=greatest(hi,normal_value);
 end loop;
 raw_percent:=total_normal/4.0;percent_value:=round(raw_percent,0);tolerance:=plantlab_lab.get_tolerance_limit(4,percent_value,t,p_method);
 return jsonb_build_object('replicates',reps,'replicate_count',4,'seeds_per_replicate',100,'total_tested',400,'unrounded_percent',raw_percent,'germination_percent',percent_value,
 'calculation_code',contract.calculation_code,'calculation_version',contract.version,'routine_contract_version',1,'replication_contract_id',contract.id,'source_reference',contract.source_reference,
 'gap_pp',hi-lo,'limit_pp',tolerance,'within_tolerance',(hi-lo)<=tolerance,'tolerance_replicates',4,
 'tolerance_status',case when tolerance is null then 'RULE_NOT_AVAILABLE' when hi-lo<=tolerance then 'WITHIN_SOURCE_TOLERANCE' else 'EXCEEDS_SOURCE_TOLERANCE' end,
 'authorizes_lot_release',false,'first_count_added_to_final',false,'final_categories',jsonb_build_array('normal','abnormal','fresh','hard','dead'));
end;
$$;

alter function plantlab_lab.routine_draft_readiness(uuid) rename to routine_draft_readiness_v1;
create function plantlab_lab.routine_draft_readiness(p_draft_id uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare result jsonb;
begin
 result:=plantlab_lab.routine_draft_readiness_v1(p_draft_id);
 result:=jsonb_set(result,'{blockers}',coalesce((select jsonb_agg(case when b->>'code'='COUNTS' then b||jsonb_build_object('message','Lengkapi semua hitungan sesuai pilihan: Germinasi2x100 atau4x100, Vigor biasa2x100, RET4x100. Tiap a/b50benih. Kosong bukan nol.') else b end) from jsonb_array_elements(result->'blockers') b),'[]'::jsonb));
 return result;
end;
$$;

create or replace function plantlab_lab.validate_test_run_workflow()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_missing_required int;v_item_status text;v_request_status text;v_requires_observations boolean;expected int;
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
 select (draft_snapshot->>'replicate_count')::int*2 into strict expected from plantlab_lab.routine_submissions where test_run_id=new.id;
 if (select count(*) from plantlab_lab.routine_count_observations where test_run_id=new.id)<>expected then raise exception 'Actual routine a/b count must match sealed replication design' using errcode='23514'; end if;
 elsif not exists(select from plantlab_lab.test_run_observations where test_run_id=new.id and observation_phase='FINAL') then raise exception 'Final observations missing' using errcode='23514'; end if;
 if not exists(select from plantlab_lab.test_run_events where test_run_id=new.id and event_type='OBSERVED_FINAL') then raise exception 'Final event missing' using errcode='23514'; end if;
 end if;
 new.completed_at:=coalesce(new.completed_at,now());new.submitted_at:=coalesce(new.submitted_at,now());
 end if;
 return new;
end;
$$;

-- Compatible JSON extension: old clients keep the default2; new ones offer2/4.
alter function plantlab_api.get_routine_lab_options(uuid,text,int) set schema plantlab_lab;
alter function plantlab_lab.get_routine_lab_options(uuid,text,int) rename to get_routine_lab_options_v1;
revoke all on function plantlab_lab.get_routine_lab_options_v1(uuid,text,int) from PUBLIC,anon,authenticated,service_role;
create function plantlab_api.get_routine_lab_options(p_lab_site_id uuid default null,p_search text default '',p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 result:=plantlab_lab.get_routine_lab_options_v1(p_lab_site_id,p_search,p_offset);
 return result||jsonb_build_object('version',2,'draft_only',false,'methods',(select jsonb_agg(m||jsonb_build_object('replicate_counts',case when m->>'method_code'='SAND_25C' then '[2,4]'::jsonb else jsonb_build_array((m->>'replicate_count')::int) end) order by m->>'method_code') from jsonb_array_elements(result->'methods') m));
end;
$$;
revoke all on function plantlab_lab.seal_routine_replication_contract(),plantlab_lab.guard_routine_replication_choice(),plantlab_lab.calculate_routine_observations(uuid,jsonb),plantlab_lab.routine_draft_readiness(uuid) from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_api.get_routine_lab_options(uuid,text,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_routine_lab_options(uuid,text,int) to authenticated;
notify pgrst,'reload schema';
commit;
