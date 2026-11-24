-- Source history is NOT a new test run, QA approval, stock or lot release.
-- Additive plantlab_* only. Imported payloads and typed children are append-only.
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
set local search_path=pg_catalog;

create table plantlab_lab.historical_records (
  id uuid primary key default gen_random_uuid(),
  source_import_row_id uuid not null references plantlab_integration.import_rows(id) on delete restrict,
  source_type text not null check (source_type in ('QUALITY_INFORMATION_2026','GERMINATION_VIGOR_2026')),
  source_sha256 text not null check(source_sha256 ~ '^[0-9a-f]{64}$'),
  source_row_sha256 text not null check(source_row_sha256 ~ '^[0-9a-f]{64}$'),
  mapping_version integer not null check(mapping_version>0),
  lot_id uuid references plantlab_core.lots(id) on delete restrict,
  dss_lot_id uuid references plantlab_core.lots(id) on delete restrict,
  dcs_lot_id uuid references plantlab_core.lots(id) on delete restrict,
  source_testing_type text,
  history_status text not null default 'SOURCE_HISTORY_NOT_APP_APPROVED'
    check(history_status='SOURCE_HISTORY_NOT_APP_APPROVED'),
  payload_sha256 text not null check(payload_sha256 ~ '^[0-9a-f]{64}$'),
  canonical_payload jsonb not null check(jsonb_typeof(canonical_payload)='object'),
  imported_at timestamptz not null default now(),
  unique(source_import_row_id,mapping_version),
  check((source_type='GERMINATION_VIGOR_2026' and lot_id is not null and dss_lot_id is null and dcs_lot_id is null)
    or (source_type='QUALITY_INFORMATION_2026' and lot_id is null and dss_lot_id is not null and dcs_lot_id is not null
        and dss_lot_id<>dcs_lot_id))
);
create index historical_records_lot_idx on plantlab_lab.historical_records(lot_id);
create index historical_records_pair_idx on plantlab_lab.historical_records(dss_lot_id,dcs_lot_id);

create table plantlab_lab.historical_phases (
  id uuid primary key default gen_random_uuid(),
  historical_record_id uuid not null references plantlab_lab.historical_records(id) on delete restrict,
  phase_key text not null,
  source_label text not null,
  phase_kind text not null check(phase_kind in ('FIRST_COUNT','FINAL_COUNT','CONTEXT','SOURCE_CYCLE','LATEST_SUMMARY')),
  test_code text references plantlab_lab.test_types(test_code) on delete restrict,
  method_id uuid references plantlab_lab.methods(id) on delete restrict,
  source_method_label text,
  source_stage text check(source_stage in ('DSS','DCS')),
  source_planted_date date,
  source_planted_origin text,
  source_observation_date date,
  source_observation_origin text,
  source_percent numeric,
  diagnostic_percent numeric check(diagnostic_percent between 0 and 100),
  source_comparison text not null,
  source_conclusion text,
  replicate_groups jsonb not null check(jsonb_typeof(replicate_groups)='array'),
  review_codes jsonb not null check(jsonb_typeof(review_codes)='array'),
  unique(historical_record_id,phase_key)
);

create table plantlab_lab.historical_observations (
  id uuid primary key default gen_random_uuid(),
  historical_phase_id uuid not null references plantlab_lab.historical_phases(id) on delete restrict,
  source_row_number integer not null check(source_row_number>0),
  source_label text,
  replicate_no integer check(replicate_no>0),
  subunit text check(subunit in ('A','B')),
  normal_count integer check(normal_count>=0),
  abnormal_count integer check(abnormal_count>=0),
  dead_count integer check(dead_count>=0),
  total_count integer generated always as (case when normal_count is not null and abnormal_count is not null and dead_count is not null
    then normal_count+abnormal_count+dead_count else null end) stored,
  source_counts jsonb not null check(jsonb_typeof(source_counts)='array'),
  unique(historical_phase_id,source_row_number),
  check((replicate_no is null)=(subunit is null))
);

create table plantlab_lab.historical_values (
  id uuid primary key default gen_random_uuid(),
  historical_phase_id uuid not null references plantlab_lab.historical_phases(id) on delete restrict,
  coordinate text not null check(coordinate ~ '^[A-Z]+[1-9][0-9]*$'),
  source_header text not null,
  source_header_band text,
  semantic_role text not null,
  source_unit text not null,
  test_hint text,
  value_number numeric,
  value_date date,
  source_value jsonb not null,
  value_origin text not null check(value_origin in ('LITERAL','FORMULA_CACHE','FORMULA_ERROR','SOURCE_ERROR')),
  source_formula text,
  warning text,
  unique(historical_phase_id,coordinate)
);

do $$
declare target text;
begin
  foreach target in array array['historical_records','historical_phases','historical_observations','historical_values'] loop
    execute format('alter table plantlab_lab.%I enable row level security',target);
    execute format('revoke all on plantlab_lab.%I from PUBLIC,anon,authenticated,service_role',target);
    execute format('create trigger %I before update or delete on plantlab_lab.%I for each row execute function plantlab_audit.prevent_append_only_mutation()',target||'_immutable',target);
  end loop;
end;
$$;
comment on table plantlab_lab.historical_records is
  'Typed source history, never an application-approved result. Source/fact corrections require a new mapping version, not overwriting imported observations.';

create function plantlab_integration.import_historical_quality(p_doc jsonb,p_sha256 text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  source_record record; old_record plantlab_lab.historical_records;
  lot_record plantlab_core.lots; record_id uuid; phase_id uuid; method_id uuid;
  phase jsonb; observation jsonb; fact jsonb; n_phases integer:=0; n_observations integer:=0; n_values integer:=0;
begin
  if p_doc->>'history_status' is distinct from 'SOURCE_HISTORY_NOT_APP_APPROVED' or p_doc->>'source_hybrid' is distinct from 'H59'
    or p_doc->>'crop' is distinct from 'SWC' or (p_doc->>'mapping_version')::integer is distinct from 1
    or jsonb_typeof(p_doc->'phases') is distinct from 'array' or p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'Unsupported historical import contract'; end if;
  select r.*,b.source_type,b.source_file_sha256,b.parser_version into strict source_record
    from plantlab_integration.import_rows r join plantlab_integration.import_batches b on b.id=r.batch_id
    where r.id=(p_doc->>'source_import_row_id')::uuid and b.parser_version=20001
      and b.source_type=p_doc->>'source_type' and b.source_file_sha256=p_doc->>'source_sha256'
      and r.row_sha256=p_doc->>'source_row_sha256' and r.sheet_name=p_doc->>'sheet'
      and r.source_row_number=(p_doc->>'source_row')::integer;
  if source_record.source_type='GERMINATION_VIGOR_2026' then
    select l.* into strict lot_record from plantlab_core.lots l join plantlab_master.products p on p.id=l.product_id
      where l.id=(p_doc->>'lot_id')::uuid and l.crop_category_code='SWC' and p.sku='EXCEL-SWC-H59'
        and plantlab_core.normalize_identifier(l.lot_code)=plantlab_core.normalize_identifier(source_record.normalized_payload->>'tested_lot_code');
    if source_record.normalized_payload->>'source_hybrid'<>'H59' or source_record.normalized_payload->>'crop_category_hint'<>'SWC' then
      raise exception 'Germination source identity not resolved'; end if;
  elsif source_record.source_type='QUALITY_INFORMATION_2026' then
    if not exists(select from plantlab_core.dss_dcs_pairs pair
      join plantlab_core.lots dss on dss.id=pair.dss_lot_id join plantlab_core.lots dcs on dcs.id=pair.dcs_lot_id
      join plantlab_master.products product on product.id=dss.product_id
      where pair.dss_lot_id=(p_doc->>'dss_lot_id')::uuid and pair.dcs_lot_id=(p_doc->>'dcs_lot_id')::uuid
        and product.sku='EXCEL-SWC-H59' and dss.crop_category_code='SWC' and dcs.crop_category_code='SWC'
        and plantlab_core.normalize_identifier(dss.lot_code)=plantlab_core.normalize_identifier(source_record.normalized_payload->>'lot_dss_code')
        and plantlab_core.normalize_identifier(dcs.lot_code)=plantlab_core.normalize_identifier(source_record.normalized_payload->>'lot_dcs_code')
        and source_record.normalized_payload->>'canonical_dss_lot_id'=dss.id::text
        and source_record.normalized_payload->>'canonical_dcs_lot_id'=dcs.id::text
        and source_record.status='VALIDATED') then raise exception 'Quality Information fixed pair not resolved'; end if;
  else raise exception 'Unsupported source'; end if;
  perform pg_advisory_xact_lock(hashtextextended('PLANTLAB_SOURCE_HISTORY:'||(p_doc->>'source_import_row_id'),0));
  select * into old_record from plantlab_lab.historical_records h
    where h.source_import_row_id=source_record.id and h.mapping_version=1;
  if found then
    if old_record.payload_sha256 is distinct from p_sha256 or old_record.canonical_payload is distinct from p_doc then
      raise exception 'Immutable historical payload changed; use a reviewed new mapping version'; end if;
    return jsonb_build_object('record_id',old_record.id,'inserted',false);
  end if;
  insert into plantlab_lab.historical_records(source_import_row_id,source_type,source_sha256,source_row_sha256,
    mapping_version,lot_id,dss_lot_id,dcs_lot_id,source_testing_type,payload_sha256,canonical_payload)
  values(source_record.id,source_record.source_type,source_record.source_file_sha256,source_record.row_sha256,
    1,(p_doc->>'lot_id')::uuid,(p_doc->>'dss_lot_id')::uuid,(p_doc->>'dcs_lot_id')::uuid,
    p_doc->>'source_testing_type',p_sha256,p_doc) returning id into record_id;
  for phase in select value from jsonb_array_elements(p_doc->'phases') loop
    method_id:=null;
    if phase->>'method_code' is not null then
      select m.id into strict method_id from plantlab_lab.methods m where m.method_code=phase->>'method_code' and m.version=1;
    end if;
    insert into plantlab_lab.historical_phases(historical_record_id,phase_key,source_label,phase_kind,test_code,method_id,
      source_method_label,source_stage,source_planted_date,source_planted_origin,source_observation_date,source_observation_origin,
      source_percent,diagnostic_percent,source_comparison,source_conclusion,replicate_groups,review_codes)
    values(record_id,phase->>'key',phase->>'label',phase->>'kind',phase->>'test_code',method_id,
      phase->>'method_label',phase->>'source_stage',(phase#>>'{planted,date}')::date,phase#>>'{planted,origin}',
      (phase#>>'{observed,date}')::date,phase#>>'{observed,origin}',(phase#>>'{source_result,number}')::numeric,
      (phase->>'computed_percent')::numeric,phase->>'comparison',phase->>'source_conclusion',
      phase->'replicate_groups',phase->'review_codes') returning id into phase_id;
    n_phases:=n_phases+1;
    for observation in select value from jsonb_array_elements(phase->'observations') loop
      insert into plantlab_lab.historical_observations(historical_phase_id,source_row_number,source_label,replicate_no,
        subunit,normal_count,abnormal_count,dead_count,source_counts)
      values(phase_id,(observation->>'source_row')::integer,observation->>'label',(observation->>'replicate_no')::integer,
        observation->>'subunit',(observation->>'normal')::integer,(observation->>'abnormal')::integer,
        (observation->>'dead')::integer,observation->'source_counts');
      n_observations:=n_observations+1;
    end loop;
    for fact in select value from jsonb_array_elements(phase->'values') loop
      insert into plantlab_lab.historical_values(historical_phase_id,coordinate,source_header,source_header_band,
        semantic_role,source_unit,test_hint,value_number,value_date,source_value,value_origin,source_formula,warning)
      values(phase_id,fact->>'coordinate',fact->>'header',fact->>'header_band',fact->>'role',fact->>'unit',fact->>'test_hint',
        (fact->>'number')::numeric,(fact->>'date')::date,fact->'value',fact->>'origin',fact->>'formula',fact->>'warning');
      n_values:=n_values+1;
    end loop;
  end loop;
  return jsonb_build_object('record_id',record_id,'inserted',true,'phases',n_phases,'observations',n_observations,'values',n_values);
end;
$$;
revoke all on function plantlab_integration.import_historical_quality(jsonb,text) from PUBLIC,anon,authenticated,service_role;

create function plantlab_api.get_lot_historical_quality(p_lot_id uuid,p_module text,p_limit integer default 5,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare l plantlab_core.lots; module text:=upper(btrim(p_module)); result jsonb;
begin
  if auth.uid() is null then return null; end if;
  select * into l from plantlab_core.lots where id=p_lot_id;
  if not found then return null; end if;
  if not (case module when 'PLANT' then plantlab_platform.has_permission('PLANT','result.read',l.plant_site_id,l.company_id)
    when 'LAB' then exists(select from plantlab_lab.requests r where r.lot_id=l.id and r.status<>'DRAFT'
      and plantlab_platform.has_permission('LAB','result.read',r.target_lab_site_id,l.company_id)) else false end)
    then return null; end if;
  with eligible as (
    select h.*,r.sheet_name,r.source_row_number,b.source_file_name
    from plantlab_lab.historical_records h join plantlab_integration.import_rows r on r.id=h.source_import_row_id
    join plantlab_integration.import_batches b on b.id=r.batch_id
    where (h.lot_id=l.id or h.dss_lot_id=l.id or h.dcs_lot_id=l.id)
      and not exists(select from plantlab_lab.historical_records newer where newer.source_import_row_id=h.source_import_row_id
        and newer.mapping_version>h.mapping_version)
      and (module='PLANT' or h.source_type='GERMINATION_VIGOR_2026' or exists(
        select from plantlab_lab.historical_phases p where p.historical_record_id=h.id and p.source_stage=l.stage_code))
  ), page as (select * from eligible order by source_type,sheet_name,source_row_number,id
    limit least(greatest(coalesce(p_limit,5),0),20) offset greatest(coalesce(p_offset,0),0))
  select jsonb_build_object('lot_code',l.lot_code,'history_status','SOURCE_HISTORY_NOT_APP_APPROVED',
    'total_records',(select count(*) from eligible),'records',coalesce(jsonb_agg(jsonb_build_object(
      'id',h.id,'source_type',h.source_type,'source_file_name',h.source_file_name,'sheet',h.sheet_name,
      'source_row',h.source_row_number,'mapping_version',h.mapping_version,'source_testing_type',h.source_testing_type,
      'source_sha256',h.source_sha256,'phases',coalesce((select jsonb_agg(jsonb_build_object(
        'key',p.phase_key,'label',p.source_label,'kind',p.phase_kind,'test_code',p.test_code,
        'source_method_label',p.source_method_label,'source_stage',p.source_stage,
        'source_planted_date',p.source_planted_date,'source_planted_origin',p.source_planted_origin,
        'source_observation_date',p.source_observation_date,'source_observation_origin',p.source_observation_origin,
        'source_percent',p.source_percent,'diagnostic_percent',p.diagnostic_percent,'source_comparison',p.source_comparison,
        'source_conclusion',p.source_conclusion,'review_codes',p.review_codes,
        'replicate_groups',coalesce((select jsonb_agg(g-'normal_sum_formula') from jsonb_array_elements(p.replicate_groups) g),'[]'::jsonb),
        'subunits',coalesce((select jsonb_agg(jsonb_build_object('source_row',o.source_row_number,'label',o.source_label,
          'replicate_no',o.replicate_no,'subunit',o.subunit,'normal',o.normal_count,'abnormal',o.abnormal_count,
          'dead',o.dead_count,'total',o.total_count) order by o.source_row_number)
          from plantlab_lab.historical_observations o where o.historical_phase_id=p.id),'[]'::jsonb),
        'values',coalesce((select jsonb_agg(jsonb_build_object('coordinate',v.coordinate,'header',v.source_header,
          'header_band',v.source_header_band,'role',v.semantic_role,'unit',v.source_unit,'test_hint',v.test_hint,
          'number',v.value_number,'date',v.value_date,'source_value',v.source_value,'origin',v.value_origin,
          'has_formula',v.source_formula is not null,'warning',v.warning) order by v.coordinate)
          from plantlab_lab.historical_values v where v.historical_phase_id=p.id),'[]'::jsonb)) order by p.phase_key)
        from plantlab_lab.historical_phases p where p.historical_record_id=h.id
          and (module='PLANT' or h.source_type='GERMINATION_VIGOR_2026' or p.source_stage=l.stage_code)),'[]'::jsonb))
      order by h.source_type,h.sheet_name,h.source_row_number,h.id),'[]'::jsonb)) into result from page h;
  return result;
end;
$$;
revoke all on function plantlab_api.get_lot_historical_quality(uuid,text,integer,integer) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_lot_historical_quality(uuid,text,integer,integer) to authenticated;
commit;
