-- Prospective safety guards and owner RET timing confirmation. No data rewrites.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';
create table plantlab_lab.ret_protocol_confirmations (
 method_id uuid not null references plantlab_lab.methods(id),version int not null check(version>0),
 duration_hours int not null check(duration_hours=72),temperature_celsius numeric not null check(temperature_celsius=16),
 duration_start_event text not null check(duration_start_event='PLACED_AT_16C'),
 replicate_count int not null check(replicate_count=4),seeds_per_replicate int not null check(seeds_per_replicate=100),
 minimum_radicle_mm numeric not null check(minimum_radicle_mm=2),source_note text not null,
 effective_from timestamptz not null default now(),primary key(method_id,version)
);
insert into plantlab_lab.ret_protocol_confirmations(method_id,version,duration_hours,temperature_celsius,duration_start_event,replicate_count,seeds_per_replicate,minimum_radicle_mm,source_note)
select id,1,72,16,'PLACED_AT_16C',4,100,2,'Owner explicit confirmation11Nov2026:3days start when seeds placed at16C. RET tolerance applicability not yet confirmed; no operational activation or lot release.'
from plantlab_lab.methods where method_code='RET_16C_72H' and version=1;
alter table plantlab_lab.ret_protocol_confirmations enable row level security;
revoke all on plantlab_lab.ret_protocol_confirmations from PUBLIC,anon,authenticated,service_role;
create trigger ret_protocol_confirmations_immutable before update or delete on plantlab_lab.ret_protocol_confirmations for each row execute function plantlab_lab.guard_uac_reference_history();

create or replace function plantlab_api.get_vigour_workflow_options()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform plantlab_lab.require_contract_reader();
 return jsonb_build_object('version',2,'methods',(select jsonb_agg(jsonb_build_object('method_code',m.method_code,'method_name',m.method_name,'replicate_count',2,'seeds_per_replicate',100,'procedure_summary',m.procedure_summary) order by m.method_code)
 from plantlab_lab.vigour_calculation_contracts c join plantlab_lab.methods m on m.id=c.method_id where m.is_active),
 'ret_enabled',false,'ret_protocol',(select to_jsonb(p) from plantlab_lab.ret_protocol_confirmations p order by p.version desc limit 1),
 'ret_pending','RET tolerance applicability/SOP confirmation remains pending.72hours starts at placement16C; radicle counts are not normal Germination counts.',
 'calculation_note','ROUND(AVERAGE(normal per100-seed replicate),0). Raw counts and unrounded percent retained. Missing tolerance blocks approval; no invented0/1/100 endpoints.',
 'authorizes_lot_release',false);
end;
$$;

create or replace function plantlab_lab.lock_vigour_item(p_item uuid,p_role text)
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
 where i.id=p_item and i.is_active and q.status not in ('CANCELLED','CLOSED','REJECTED') and i.status not in ('CANCELLED','REJECTED')
 and plantlab_platform.has_exact_scoped_role('LAB',p_role,q.target_lab_site_id,l.company_id)
 for update of q,i;
 if not found then raise exception 'Received, open Vigor item and scoped Lab role required' using errcode='42501'; end if;
end;
$$;
create function plantlab_lab.assert_vigour_retest_clock(p_run uuid,p_started_at timestamptz)
returns void language plpgsql stable set search_path='' as $$
declare parent uuid; decision_at timestamptz;
begin
 select retest_of_id into parent from plantlab_lab.test_runs where id=p_run;
 if parent is null then return; end if;
 select decided_at into decision_at from plantlab_lab.result_decisions where test_run_id=parent and decision='RETEST' order by id desc limit 1;
 if decision_at is null or p_started_at<date_trunc('minute',decision_at) then raise exception 'Retest actual start cannot precede QA retest decision (minute precision)' using errcode='22023'; end if;
end;
$$;
create function plantlab_lab.guard_vigour_retest_clock()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform plantlab_lab.assert_vigour_retest_clock(new.test_run_id,new.actual_started_at);
 return new;
end;
$$;
create trigger vigour_retest_clock before insert on plantlab_lab.vigour_run_contexts for each row execute function plantlab_lab.guard_vigour_retest_clock();
revoke all on function plantlab_lab.assert_vigour_retest_clock(uuid,timestamptz),plantlab_lab.guard_vigour_retest_clock() from PUBLIC,anon,authenticated,service_role;
notify pgrst,'reload schema';
commit;
