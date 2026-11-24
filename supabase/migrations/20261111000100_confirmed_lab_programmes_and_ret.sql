-- Owner confirmation 11 Nov 2026. Append new scoped references and contracts;
-- do not reinterpret old observations, provision PI, create lots or release them.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create table plantlab_lab.programme_quality_references (
 id uuid primary key default gen_random_uuid(),
 crop_kind text not null check(crop_kind in ('FC','SWC')),
 programme_code text not null check(programme_code in ('COMMERCIAL','PARENT_SEED')),
 test_code text not null references plantlab_lab.test_types(test_code),
 version integer not null check(version>0), minimum_percent numeric not null check(minimum_percent between 0 and 100),
 unit_code text not null default 'PERCENT' check(unit_code='PERCENT'),
 business_confirmation_status text not null default 'USER_CONFIRMED' check(business_confirmation_status='USER_CONFIRMED'),
 source_note text not null, effective_from timestamptz not null default now(),
 unique(crop_kind,programme_code,test_code,version)
);
insert into plantlab_lab.programme_quality_references(crop_kind,programme_code,test_code,version,minimum_percent,source_note)
select crop,programme,test,3,minimum,
 'Owner confirmation 2026-11-11: FC/SWC Commercial Germination90 Vigour80; FC/SWC Parent Seed Germination90 Vigour70. Crop and programme are independent. Not controlled SOP/regulatory certification or lot release.'
from (values('FC'),('SWC')) crops(crop)
cross join(values('COMMERCIAL','GERMINATION',90),('COMMERCIAL','VIGOUR',80),
 ('PARENT_SEED','GERMINATION',90),('PARENT_SEED','VIGOUR',70)) rules(programme,test,minimum);

-- Future registrations/reconciliation may explicitly populate this through a
-- separately reviewed command. No classifications are guessed or inserted now.
create table plantlab_master.lot_quality_classifications (
 lot_id uuid not null references plantlab_core.lots(id), version integer not null check(version>0),
 crop_kind text not null check(crop_kind in ('FC','SWC')),
 programme_code text not null check(programme_code in ('COMMERCIAL','PARENT_SEED')),
 source_reference text not null check(length(btrim(source_reference)) between 3 and 500),
 confirmed_by uuid not null references plantlab_platform.identities(id),
 effective_from timestamptz not null default now(), primary key(lot_id,version)
);

-- The old method code contains 48H: keep its meaning/history intact and create
-- a new correctly named method, rather than putting 72h under a 48H identifier.
insert into plantlab_lab.methods(method_code,method_name,version,procedure_summary,procedure_metadata,effective_from,is_active)
values('RET_16C_72H','Radicle Emergence Test (3 days, radicle >=2 mm)',1,
 'RET owner correction 2026-11-11: 3 days, 4 replicates of 100 seeds, minimum radicle 2 mm. Existing16C baseline retained; controlled SOP/start-time event still required.',
 '{"temperature_celsius":16,"duration_days":3,"duration_hours_equivalent":72,"minimum_radicle_mm":2,"replicate_count":4,"seeds_per_replicate":100,"confirmation_date":"2026-11-11","duration_start_event":"PENDING_CONFIRMATION","supersedes_method_code":"RET_16C_48H"}',current_date,true);
insert into plantlab_lab.method_test_types(method_id,test_type_id,is_default,requires_replicate_observations)
select m.id,t.id,false,true from plantlab_lab.methods m cross join plantlab_lab.test_types t
where m.method_code='RET_16C_72H' and m.version=1 and t.test_code='VIGOUR';

create table plantlab_lab.confirmed_method_contracts (
 id uuid primary key default gen_random_uuid(), method_id uuid not null references plantlab_lab.methods(id),
 contract_version integer not null check(contract_version>0),
 replicate_count integer not null check(replicate_count in (2,4)),
 seeds_per_replicate integer not null check(seeds_per_replicate=100),
 observation_kind text not null check(observation_kind in ('RADICLE_AT_LEAST_2MM','EXCEL_METHOD_OBSERVATIONS','GERMINATION_COUNTS')),
 minimum_radicle_mm numeric, duration_days numeric,
 calculation_status text not null check(calculation_status in ('RET_COUNT_PREVIEW_ONLY','EXCEL_FORMULA_TRACE_REQUIRED','NORMAL_OVER_TESTED_PERCENT')),
 source_note text not null, effective_from timestamptz not null default now(),
 unique(method_id,contract_version)
);
insert into plantlab_lab.confirmed_method_contracts(method_id,contract_version,replicate_count,seeds_per_replicate,
 observation_kind,minimum_radicle_mm,duration_days,calculation_status,source_note)
select m.id,1,case when m.method_code='RET_16C_72H' then 4 else 2 end,100,
 case when m.method_code='RET_16C_72H' then 'RADICLE_AT_LEAST_2MM' when m.method_code='SAND_25C' then 'GERMINATION_COUNTS' else 'EXCEL_METHOD_OBSERVATIONS' end,
 case when m.method_code='RET_16C_72H' then 2 end,case when m.method_code='RET_16C_72H' then 3 end,
 case when m.method_code='RET_16C_72H' then 'RET_COUNT_PREVIEW_ONLY' when m.method_code='SAND_25C' then 'NORMAL_OVER_TESTED_PERCENT' else 'EXCEL_FORMULA_TRACE_REQUIRED' end,
 'Owner confirmation 2026-11-11. RET4x100,2mm,3days; Germination and other Vigour2x100. Historical observations unchanged. Other Vigour calculation requires source Excel trace. Not an operational result or official SOP.'
from plantlab_lab.methods m where m.version=1 and m.method_code in
 ('SAND_25C','COLD_TEST_5C_24H','AAT_42C_72H_RH90','SCT_10C7D_25C5D','RET_16C_72H','AAT_EXT_42C_96H_RH90');

alter table plantlab_lab.programme_quality_references enable row level security;
alter table plantlab_lab.confirmed_method_contracts enable row level security;
alter table plantlab_master.lot_quality_classifications enable row level security;
revoke all on plantlab_lab.programme_quality_references,plantlab_lab.confirmed_method_contracts,
 plantlab_master.lot_quality_classifications from PUBLIC,anon,authenticated,service_role;
create trigger programme_quality_references_immutable before update or delete on plantlab_lab.programme_quality_references
 for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger confirmed_method_contracts_immutable before update or delete on plantlab_lab.confirmed_method_contracts
 for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger lot_quality_classifications_immutable before update or delete on plantlab_master.lot_quality_classifications
 for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_lab.require_contract_reader()
returns void language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (plantlab_platform.has_module_permission('PLANT','test.read') or
 plantlab_platform.has_module_permission('LAB','request.read')) then raise exception 'Active Plant/Lab assignment required' using errcode='42501'; end if;
end;
$$;
create function plantlab_lab.evaluate_programme_reference(p_crop text,p_programme text,p_test text,p_value numeric,p_as_of timestamptz default now())
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('rule_id',r.id,'crop_category_code',r.crop_kind,'crop_kind',r.crop_kind,
 'programme_code',r.programme_code,'test_code',r.test_code,'version',r.version,'minimum_percent',r.minimum_percent,
 'unit_code',r.unit_code,'validation_status','PENDING_CONTROLLED_SOP','business_confirmation_status',r.business_confirmation_status,
 'effective_from',r.effective_from,'source_note',r.source_note,'assessed_value',p_value,
 'assessment',case when p_value is null then 'NO_RESULT' when p_value::text in ('NaN','Infinity','-Infinity') or p_value<0 or p_value>100 then 'INVALID_PERCENT'
 when p_value>=r.minimum_percent then 'MEETS_PROVISIONAL_REFERENCE' else 'BELOW_PROVISIONAL_REFERENCE' end,
 'is_official_specification',false,'authorizes_lot_release',false)
 from plantlab_lab.programme_quality_references r where r.crop_kind=upper(btrim(p_crop)) and r.programme_code=upper(btrim(p_programme))
 and r.test_code=upper(btrim(p_test)) and r.effective_from<=p_as_of order by version desc limit 1;
$$;
create function plantlab_api.get_confirmed_lab_contracts()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform plantlab_lab.require_contract_reader();
 return jsonb_build_object('confirmed_on','2026-11-11','schema_version',1,
 'rules',(select jsonb_agg(plantlab_lab.evaluate_programme_reference(r.crop_kind,r.programme_code,r.test_code,null,now()) order by r.programme_code,r.crop_kind,r.test_code)
 from plantlab_lab.programme_quality_references r where r.version=3),
 'methods',(select jsonb_agg(jsonb_build_object('contract_id',c.id,'contract_version',c.contract_version,
 'method_code',m.method_code,'method_name',m.method_name,'method_version',m.version,
 'replicate_count',c.replicate_count,'seeds_per_replicate',c.seeds_per_replicate,'total_seeds',c.replicate_count*c.seeds_per_replicate,
 'observation_kind',c.observation_kind,'minimum_radicle_mm',c.minimum_radicle_mm,'duration_days',c.duration_days,
 'calculation_status',c.calculation_status,'operational_workflow_enabled',m.method_code='SAND_25C','standard_reference',m.standard_reference)
 order by m.method_code) from plantlab_lab.confirmed_method_contracts c join plantlab_lab.methods m on m.id=c.method_id),
 'lot_registration',jsonb_build_object('creation_event','FIRST_BIN_ENTRY','owner','PLANT_OFFICER','coding_authority','QA_PRODUCT_SPECIFICATION',
 'coding_format_status','PENDING_OFFICIAL_PRODUCT_SPEC','automatic_code_generation_enabled',false),
 'workflow_note','Confirmed input/reference contract only. Vigor request/result workflow, physical start-time definition and controlled SOP remain separate. No accounts or operational transactions created.');
end;
$$;
create function plantlab_api.preview_ret_counts(p_replicates jsonb,p_crop text,p_programme text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare row_value jsonb; total_count int:=0; eligible int; fraction numeric; normalized jsonb:='[]';
begin
 perform plantlab_lab.require_contract_reader();
 if jsonb_typeof(p_replicates) is distinct from 'array' or jsonb_array_length(p_replicates)<>4 then
 raise exception 'RET requires four replicates of 100 seeds' using errcode='22023'; end if;
 for row_value in select value from jsonb_array_elements(p_replicates) loop
 if jsonb_typeof(row_value) is distinct from 'object' or jsonb_typeof(row_value->'tested') is distinct from 'number'
 or row_value->>'tested'<>'100' or jsonb_typeof(row_value->'radicle_at_least_2mm') is distinct from 'number'
 or (row_value->>'radicle_at_least_2mm') !~ '^[0-9]{1,3}$'
 or exists(select from jsonb_object_keys(row_value) k where k not in ('tested','radicle_at_least_2mm')) then
 raise exception 'Each RET row needs tested100 and integer radicle_at_least_2mm count' using errcode='22023'; end if;
 eligible:=(row_value->>'radicle_at_least_2mm')::int;
 if eligible>100 then raise exception 'Eligible count exceeds 100 tested seeds' using errcode='22023'; end if;
 total_count:=total_count+eligible; normalized:=normalized||jsonb_build_array(row_value);
 end loop;
 if upper(btrim(p_crop)) not in ('FC','SWC') or p_crop is null then raise exception 'Confirmed FC/SWC crop required' using errcode='22023'; end if;
 if upper(btrim(p_programme)) not in ('COMMERCIAL','PARENT_SEED','UNKNOWN') or p_programme is null then raise exception 'Invalid programme' using errcode='22023'; end if;
 fraction:=round(100.0*total_count/400,2);
 return jsonb_build_object('method_code','RET_16C_72H','minimum_radicle_mm',2,'duration_days',3,'replicate_count',4,'total_tested',400,
 'total_radicle_at_least_2mm',total_count,'ret_percent',fraction,'replicates',normalized,
 'quality_reference',plantlab_lab.evaluate_programme_reference(p_crop,p_programme,'VIGOUR',fraction,now()),
 'scope_status',case when upper(btrim(p_programme))='UNKNOWN' then 'PENDING_CLASSIFICATION' else 'CALLER_DECLARATION_NOT_LOT_CLASSIFICATION' end,
 'persisted',false,'physical_duration_verified',false,'tolerance_assessed',false,'authorizes_lot_release',false);
end;
$$;

create function plantlab_lab.programme_reference_for_lot(p_lot_id uuid,p_test text,p_value numeric)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare lot plantlab_core.lots; classification plantlab_master.lot_quality_classifications; snapshot jsonb; ps_snapshot jsonb;
begin
 select * into lot from plantlab_core.lots where id=p_lot_id;
 if not found then return null; end if;
 select * into classification from plantlab_master.lot_quality_classifications where lot_id=p_lot_id and effective_from<=now() order by version desc limit 1;
 if found then
   if lot.crop_category_code in ('FC','SWC') and lot.crop_category_code<>classification.crop_kind then return null; end if;
   return plantlab_lab.evaluate_programme_reference(classification.crop_kind,classification.programme_code,p_test,p_value,now());
 elsif lot.crop_category_code in ('FC','SWC') and p_test='GERMINATION' then
   snapshot:=plantlab_lab.evaluate_programme_reference(lot.crop_category_code,'COMMERCIAL',p_test,p_value,now());
   ps_snapshot:=plantlab_lab.evaluate_programme_reference(lot.crop_category_code,'PARENT_SEED',p_test,p_value,now());
   if snapshot is null or ps_snapshot is null or snapshot->'minimum_percent' is distinct from ps_snapshot->'minimum_percent' then return null; end if;
   return (snapshot-'rule_id')||jsonb_build_object('programme_code','UNRESOLVED_EQUAL_LIMITS',
    'source_note','Germination90 is identical in both confirmed FC/SWC programmes. Lot programme remains unresolved; no master classification was created.');
 end if;
 return null;
end;
$$;

-- Applies only to runs CREATED after this immutable contract. Historical runs
-- and idempotent retries retain their original observations and sample sizes.
create function plantlab_lab.validate_confirmed_germination_counts(p_replicates jsonb)
returns void language plpgsql immutable set search_path='' as $$
declare r jsonb;
begin
 if jsonb_typeof(p_replicates) is distinct from 'array' then raise exception 'Germination requires2x100 seeds' using errcode='22023'; end if;
 if jsonb_array_length(p_replicates)<>2 then raise exception 'Germination requires2x100 seeds' using errcode='22023'; end if;
 for r in select value from jsonb_array_elements(p_replicates) loop
  if jsonb_typeof(r) is distinct from 'object' or
   coalesce(r->>'normal','') !~ '^[0-9]{1,3}$' or coalesce(r->>'abnormal','') !~ '^[0-9]{1,3}$' or coalesce(r->>'dead','') !~ '^[0-9]{1,3}$' then
   raise exception 'Integer Germination counts required' using errcode='22023'; end if;
  if (r->>'normal')::int+(r->>'abnormal')::int+(r->>'dead')::int<>100 then
   raise exception 'Each Germination replicate must total100 seeds' using errcode='22023'; end if;
 end loop;
end;
$$;
create function plantlab_lab.guard_confirmed_germination_contract()
returns trigger language plpgsql security definer set search_path='' as $$
declare c plantlab_lab.confirmed_method_contracts;
begin
 if new.event_type<>'OBSERVED_FINAL' then return new; end if;
 select contract.* into c from plantlab_lab.test_runs run
 join plantlab_lab.methods m on m.id=run.method_id and m.method_code='SAND_25C'
 join plantlab_lab.confirmed_method_contracts contract on contract.method_id=m.id
 where run.id=new.test_run_id and run.created_at>=contract.effective_from order by contract.contract_version desc limit 1;
 if found then
  perform plantlab_lab.validate_confirmed_germination_counts(new.metadata->'replicates');
  new.metadata:=new.metadata||jsonb_build_object('input_contract',jsonb_build_object('contract_id',c.id,'contract_version',c.contract_version,'replicate_count',2,'seeds_per_replicate',100));
 end if;
 return new;
end;
$$;
create trigger e_confirmed_germination_contract before insert on plantlab_lab.test_run_events
 for each row execute function plantlab_lab.guard_confirmed_germination_contract();

-- New final events must not silently use commercial80 on an unclassified lot.
-- The legacy trigger/getter/rules remain untouched for old installed clients.
create function plantlab_lab.snapshot_programme_reference()
returns trigger language plpgsql security definer set search_path='' as $$
declare x record; snapshot jsonb;
begin
 if new.event_type<>'OBSERVED_FINAL' then return new; end if;
 select l.id as lot_id,l.crop_category_code,t.test_code,r.numeric_value into x
 from plantlab_lab.test_runs run join plantlab_lab.request_items i on i.id=run.request_item_id
 join plantlab_lab.requests q on q.id=i.request_id join plantlab_core.lots l on l.id=q.lot_id
 join plantlab_lab.test_types t on t.id=i.test_type_id
 join plantlab_lab.parameters p on p.parameter_code=case t.test_code when 'GERMINATION' then 'GERMINATION_PERCENT' when 'VIGOUR' then 'VIGOUR_PERCENT' end
 join plantlab_lab.result_values r on r.test_run_id=run.id and r.parameter_id=p.id where run.id=new.test_run_id;
 if not found then return new; end if;
 new.metadata:=new.metadata-'uac_quality_reference';
 snapshot:=plantlab_lab.programme_reference_for_lot(x.lot_id,x.test_code,x.numeric_value);
 if snapshot is not null then
 new.metadata:=new.metadata||jsonb_build_object('uac_quality_reference',snapshot);
 else
 new.metadata:=new.metadata||jsonb_build_object('quality_reference_scope','PENDING_CLASSIFICATION');
 end if;
 return new;
end;
$$;
create trigger d_programme_quality_reference_snapshot before insert on plantlab_lab.test_run_events
 for each row execute function plantlab_lab.snapshot_programme_reference();

revoke all on function plantlab_lab.require_contract_reader(),plantlab_lab.evaluate_programme_reference(text,text,text,numeric,timestamptz),
 plantlab_lab.programme_reference_for_lot(uuid,text,numeric),
 plantlab_lab.validate_confirmed_germination_counts(jsonb),plantlab_lab.guard_confirmed_germination_contract(),
 plantlab_lab.snapshot_programme_reference() from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_api.get_confirmed_lab_contracts(),plantlab_api.preview_ret_counts(jsonb,text,text)
 from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_confirmed_lab_contracts(),plantlab_api.preview_ret_counts(jsonb,text,text) to authenticated;
comment on table plantlab_lab.confirmed_method_contracts is 'Owner-confirmed 11Nov input contracts. Not active Vigor workflow or controlled SOP. Old method versions/observations preserved.';
notify pgrst,'reload schema';
commit;
