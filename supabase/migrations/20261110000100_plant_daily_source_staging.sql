-- Immutable source intake only. No transaction, master, pair, result or approval
-- is created from these Excel rows. No public/CompFeed dependency or exposed RPC.
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
create table plantlab_integration.plant_daily_source_files (
  source_sha256 text primary key check(source_sha256 ~ '^[0-9a-f]{64}$'),
  source_file_name text not null,
  source_bytes bigint not null check(source_bytes>0),
  declared_rows integer not null check(declared_rows>0),
  manifest jsonb not null check(jsonb_typeof(manifest)='object'),
  imported_at timestamptz not null default now()
);
create table plantlab_integration.plant_daily_source_rows (
  source_sha256 text not null references plantlab_integration.plant_daily_source_files(source_sha256),
  sheet_name text not null, source_block text not null, source_row integer not null check(source_row>0),
  payload jsonb not null check(jsonb_typeof(payload)='object'),
  payload_sha256 text not null check(payload_sha256 ~ '^[0-9a-f]{64}$'),
  history_status text not null default 'SOURCE_HISTORY_NOT_APP_APPROVED'
    check(history_status='SOURCE_HISTORY_NOT_APP_APPROVED'),
  imported_at timestamptz not null default now(),
  primary key(source_sha256,sheet_name,source_block,source_row)
);
alter table plantlab_integration.plant_daily_source_files enable row level security;
alter table plantlab_integration.plant_daily_source_rows enable row level security;
revoke all on plantlab_integration.plant_daily_source_files,plantlab_integration.plant_daily_source_rows
  from PUBLIC,anon,authenticated,service_role;

create function plantlab_integration.guard_plant_daily_source()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Source intake is immutable; use a new source/mapping version' using errcode='55000'; end;
$$;
revoke all on function plantlab_integration.guard_plant_daily_source() from PUBLIC,anon,authenticated,service_role;
create trigger plant_daily_file_immutable before update or delete on plantlab_integration.plant_daily_source_files
for each row execute function plantlab_integration.guard_plant_daily_source();
create trigger plant_daily_row_immutable before update or delete on plantlab_integration.plant_daily_source_rows
for each row execute function plantlab_integration.guard_plant_daily_source();

create function plantlab_integration.stage_plant_daily_chunk(p_manifest jsonb,p_rows jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare source_hash text:=p_manifest->>'source_sha256'; old_manifest jsonb; item jsonb; v_payload jsonb; canonical text;
  actual_hash text; existing_hash text; inserted integer:=0; unchanged integer:=0;
begin
  if coalesce((p_manifest->>'version')::integer,0)<>1 or source_hash !~ '^[0-9a-f]{64}$'
    or coalesce((p_manifest->>'records')::integer,0)<=0 or coalesce((p_manifest->>'source_bytes')::bigint,0)<=0
    or jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows)>1000 then
    raise exception 'Invalid immutable intake manifest/chunk' using errcode='22023';
  end if;
  insert into plantlab_integration.plant_daily_source_files(source_sha256,source_file_name,source_bytes,declared_rows,manifest)
    values(source_hash,p_manifest->>'source_file',(p_manifest->>'source_bytes')::bigint,(p_manifest->>'records')::integer,p_manifest)
    on conflict do nothing;
  select manifest into old_manifest from plantlab_integration.plant_daily_source_files where source_sha256=source_hash;
  if old_manifest is distinct from p_manifest then raise exception 'Manifest changed for immutable source' using errcode='22023'; end if;
  for item in select value from jsonb_array_elements(p_rows) loop
    canonical:=item->>'canonical_payload';
    actual_hash:=encode(sha256(convert_to(canonical,'UTF8')),'hex');
    if actual_hash is distinct from item->>'payload_sha256' or octet_length(canonical)>100000 then
      raise exception 'Source row fingerprint mismatch or oversized row' using errcode='22023'; end if;
    v_payload:=canonical::jsonb;
    if v_payload->>'history_status' is distinct from 'SOURCE_HISTORY_NOT_APP_APPROVED'
      or jsonb_typeof(v_payload->'cells') is distinct from 'object' or (v_payload->>'source_row')::integer<=0
      or not (p_manifest->'blocks' ? ((v_payload->>'sheet')||'/'||(v_payload->>'block'))) then
      raise exception 'Unrecognized source row/block' using errcode='22023'; end if;
    if exists(select from jsonb_each(v_payload->'cells') c where jsonb_typeof(c.value)<>'array' or jsonb_array_length(c.value)<>3
      or coalesce(c.value->>1,'') not in ('LITERAL','FORMULA_CACHE','SOURCE_ERROR') or jsonb_typeof(c.value->2)<>'number') then
      raise exception 'Invalid source cell origin/style' using errcode='22023'; end if;
    insert into plantlab_integration.plant_daily_source_rows(source_sha256,sheet_name,source_block,source_row,payload,payload_sha256)
    values(source_hash,v_payload->>'sheet',v_payload->>'block',(v_payload->>'source_row')::integer,v_payload,actual_hash)
    on conflict do nothing;
    if found then inserted:=inserted+1;
    else
      select payload_sha256 into existing_hash from plantlab_integration.plant_daily_source_rows
      where source_sha256=source_hash and sheet_name=v_payload->>'sheet' and source_block=v_payload->>'block' and source_row=(v_payload->>'source_row')::integer;
      if existing_hash is distinct from actual_hash then raise exception 'Immutable source row changed' using errcode='22023'; end if;
      unchanged:=unchanged+1;
    end if;
  end loop;
  return jsonb_build_object('inserted_rows',inserted,'unchanged_rows',unchanged,'operational_writes',0);
end;
$$;
revoke all on function plantlab_integration.stage_plant_daily_chunk(jsonb,jsonb) from PUBLIC,anon,authenticated,service_role;
comment on table plantlab_integration.plant_daily_source_rows is
  'Private immutable workbook source candidates. Literal/cache/error and raw date/percent values retained. Not app-approved, not accessible through Data API.';
commit;
