-- Independent Plant daily input. No public/CompFeed reads, Auth mutations,
-- lot release, pair creation or automatic promotion of Excel observations.
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
set local search_path=pg_catalog;

create table plantlab_plant.operation_form_versions (
  process_code text not null, version integer not null check(version>0),
  title text not null, fields jsonb not null check(jsonb_typeof(fields)='array'),
  created_at timestamptz not null default now(),
  primary key(process_code,version)
);
create table plantlab_plant.process_runs (
  id uuid primary key, root_id uuid not null references plantlab_plant.process_runs(id) on delete restrict,
  revision_of_id uuid unique references plantlab_plant.process_runs(id) on delete restrict,
  revision_no integer not null default 0 check(revision_no>=0),
  site_id uuid not null references plantlab_master.sites(id),
  company_id bigint not null references plantlab_master.companies(id),
  product_id bigint not null references plantlab_master.products(id),
  lot_id uuid references plantlab_core.lots(id),
  process_code text not null, form_version integer not null,
  started_at timestamptz not null, finished_at timestamptz,
  input_values jsonb not null check(jsonb_typeof(input_values)='object'),
  status text not null check(status in ('DRAFT','SUBMITTED','NEED_REVISION','APPROVED','VOIDED')),
  row_version integer not null default 1 check(row_version>0),
  created_by uuid not null references plantlab_platform.identities(id),
  reviewed_by uuid references plantlab_platform.identities(id), reviewed_at timestamptz, review_reason text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(process_code,form_version) references plantlab_plant.operation_form_versions(process_code,version),
  unique(root_id,revision_no),
  check(finished_at is null or finished_at>=started_at), check(revision_of_id is distinct from id)
);
create index process_runs_site_idx on plantlab_plant.process_runs(site_id,started_at desc,id);
create index process_runs_root_idx on plantlab_plant.process_runs(root_id,created_at desc,id);
create table plantlab_plant.process_material_lines (
  run_id uuid not null references plantlab_plant.process_runs(id) on delete restrict,
  line_no integer not null check(line_no>0), direction text not null check(direction in ('INPUT','OUTPUT','REJECT')),
  lot_id uuid references plantlab_core.lots(id), reference_code text,
  component text, quantity_kg numeric not null check(quantity_kg>=0 and quantity_kg<=1e12),
  primary key(run_id,line_no)
);
create table plantlab_plant.packing_consumptions (
  run_id uuid not null references plantlab_plant.process_runs(id) on delete restrict,
  line_no integer not null check(line_no>0), material_name text not null check(length(btrim(material_name)) between 1 and 100),
  unit_code text not null check(unit_code in ('GRAM','KG','ML','L','PIECE')),
  quantity numeric not null check(quantity>=0 and quantity<=1e12),
  primary key(run_id,line_no)
);
create table plantlab_plant.operation_events (
  id uuid primary key default gen_random_uuid(), run_id uuid not null references plantlab_plant.process_runs(id),
  action_id uuid unique, event_type text not null, actor_id uuid not null,
  occurred_at timestamptz not null default now(), details jsonb not null
);
alter table plantlab_plant.operation_form_versions enable row level security;
alter table plantlab_plant.process_runs enable row level security;
alter table plantlab_plant.process_material_lines enable row level security;
alter table plantlab_plant.packing_consumptions enable row level security;
alter table plantlab_plant.operation_events enable row level security;
revoke all on plantlab_plant.operation_form_versions,plantlab_plant.process_runs,
  plantlab_plant.process_material_lines,plantlab_plant.packing_consumptions,
  plantlab_plant.operation_events from PUBLIC,anon,authenticated,service_role;

insert into plantlab_plant.operation_form_versions(process_code,version,title,fields) values
('RECEIVING',1,'Receiving', '[{"key":"field_number","label":"Nomor field","type":"text","required":true},{"key":"vehicle_number","label":"Nomor kendaraan","type":"text","required":true},{"key":"transporter","label":"Transporter","type":"text"},{"key":"seal_number","label":"Nomor seal","type":"text"},{"key":"harvest_at","label":"Waktu panen","type":"timestamp"},{"key":"arrival_at","label":"Waktu tiba di Plant","type":"timestamp","required":true},{"key":"sacks","label":"Jumlah karung","type":"integer","min":0},{"key":"field_weight_kg","label":"Berat field","type":"number","unit":"KG","min":0},{"key":"plant_weight_kg","label":"Berat timbang Plant","type":"number","unit":"KG","min":0.001,"required":true},{"key":"weighbridge_slip","label":"Nomor slip timbang","type":"text"},{"key":"field_flag","label":"Flag field","type":"select","options":["GF","YF","OF","RF","UNKNOWN"]},{"key":"remark","label":"Catatan","type":"text"}]'),
('INTAKE',1,'Intake / Sortir','[{"key":"bin_number","label":"Nomor bin","type":"text","required":true},{"key":"sorting_accuracy_percent","label":"Sorting accuracy","type":"number","unit":"PERCENT","min":0,"max":100},{"key":"good_in_discard_percent","label":"Good in discard","type":"number","unit":"PERCENT","min":0,"max":100},{"key":"remark","label":"Catatan","type":"text"}]'),
('DRYING',1,'Drying','[{"key":"bin_number","label":"Nomor bin","type":"text","required":true},{"key":"dryer_type","label":"Jenis dryer","type":"text","required":true},{"key":"mc_start_percent","label":"MC awal","type":"number","unit":"PERCENT","min":0,"max":100},{"key":"mc_top_percent","label":"MC stop top","type":"number","unit":"PERCENT","min":0,"max":100,"required":true},{"key":"mc_bottom_percent","label":"MC stop bottom","type":"number","unit":"PERCENT","min":0,"max":100,"required":true},{"key":"remark","label":"Catatan","type":"text"}]'),
('SHELLING',1,'Shelling','[{"key":"line","label":"Line","type":"text","required":true},{"key":"shift","label":"Shift","type":"integer","min":1,"max":3},{"key":"mc_percent","label":"MC shelling","type":"number","unit":"PERCENT","min":0,"max":100,"required":true},{"key":"remark","label":"Catatan","type":"text"}]'),
('CLEANING',1,'Cleaning','[{"key":"line","label":"Line","type":"text","required":true},{"key":"shift","label":"Shift","type":"integer","min":1,"max":3},{"key":"mc_percent","label":"MC clean seed","type":"number","unit":"PERCENT","min":0,"max":100,"required":true},{"key":"remark","label":"Catatan; PP dicatat PI pada menu terpisah","type":"text"}]'),
('RE_CLEAN',1,'Re-clean / Rework','[{"key":"line","label":"Line","type":"text","required":true},{"key":"shift","label":"Shift","type":"integer","min":1,"max":3},{"key":"reason","label":"Alasan rework","type":"text","required":true},{"key":"mc_percent","label":"MC setelah re-clean","type":"number","unit":"PERCENT","min":0,"max":100},{"key":"remark","label":"Catatan","type":"text"}]'),
('TREATMENT',1,'Treatment','[{"key":"line","label":"Line","type":"text","required":true},{"key":"mc_percent","label":"MC treatment","type":"number","unit":"PERCENT","min":0,"max":100},{"key":"remark","label":"Catatan; pemakaian aktual dicatat per bahan","type":"text"}]'),
('PACKING',1,'Packing','[{"key":"line","label":"Line","type":"text","required":true},{"key":"pack_size_kg","label":"Ukuran kemasan","type":"number","unit":"KG","min":0.001,"required":true},{"key":"sack_output","label":"Jumlah kemasan keluar","type":"integer","min":0},{"key":"expiry_date","label":"Tanggal kedaluwarsa","type":"date"},{"key":"remark","label":"Catatan","type":"text"}]');

-- Functional PI role definition only. No account/assignment created.
insert into plantlab_platform.role_definitions(module_id,role_code,role_name,permissions)
select id,'PLANT_PI','Plant Inspector',
  '["plantlab_master.read","lot.read","sample.read","inspection.read","test.read","test.write","pp.write","attachment.read","attachment.write"]'::jsonb
from plantlab_platform.module_registry where module_code='PLANT';

create function plantlab_plant.validate_operation_values(p_fields jsonb,p_values jsonb,p_final boolean)
returns void language plpgsql set search_path='' as $$
declare f jsonb; v jsonb; k text; n numeric;
begin
  if jsonb_typeof(p_values) is distinct from 'object' then raise exception 'Values must be an object' using errcode='22023'; end if;
  for k in select jsonb_object_keys(p_values) loop
    if not exists(select from jsonb_array_elements(p_fields) x where x->>'key'=k) then
      raise exception 'Unknown input field: %',k using errcode='22023';
    end if;
  end loop;
  for f in select value from jsonb_array_elements(p_fields) loop
    k:=f->>'key'; v:=p_values->k;
    if v is null or v='null'::jsonb or v='""'::jsonb then
      if p_final and coalesce((f->>'required')::boolean,false) then raise exception 'Required field: %',k using errcode='22023'; end if;
      continue;
    end if;
    if f->>'type' in ('number','integer') then
      if jsonb_typeof(v)<>'number' then raise exception 'Expected numeric field: %',k using errcode='22023'; end if;
      n:=(v#>>'{}')::numeric;
      if n::text in ('NaN','Infinity','-Infinity') or (f ? 'min' and n<(f->>'min')::numeric)
        or (f ? 'max' and n>(f->>'max')::numeric) or (f->>'type'='integer' and n<>trunc(n)) then
        raise exception 'Value out of range: %',k using errcode='22023';
      end if;
    else
      if jsonb_typeof(v)<>'string' or length(v#>>'{}')>500 then raise exception 'Expected text <=500 characters: %',k using errcode='22023'; end if;
      if p_final and coalesce((f->>'required')::boolean,false) and btrim(v#>>'{}')='' then raise exception 'Required field: %',k using errcode='22023'; end if;
      if f->>'type'='select' and not (f->'options' ? (v#>>'{}')) then raise exception 'Invalid selection: %',k using errcode='22023'; end if;
      if f->>'type'='timestamp' then
        if (v#>>'{}') !~ '^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$' then raise exception 'Timestamp must include timezone: %',k using errcode='22023'; end if;
        perform (v#>>'{}')::timestamptz;
      elsif f->>'type'='date' then
        if (v#>>'{}') !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'Invalid date: %',k using errcode='22023'; end if;
        perform (v#>>'{}')::date;
      end if;
    end if;
  end loop;
  if p_values ? 'harvest_at' and p_values ? 'arrival_at'
    and nullif(p_values->>'harvest_at','')::timestamptz> nullif(p_values->>'arrival_at','')::timestamptz then
    raise exception 'Arrival precedes harvest' using errcode='22023';
  end if;
end;
$$;
revoke all on function plantlab_plant.validate_operation_values(jsonb,jsonb,boolean) from PUBLIC,anon,authenticated,service_role;

create function plantlab_plant.operation_document(p_id uuid)
returns jsonb language sql stable set search_path='' as $$
 select (to_jsonb(r)-'input_values')||jsonb_build_object('values',r.input_values,'lot_code',l.lot_code,'product_name',p.name,'site_code',s.site_code,
   'duration_hours',extract(epoch from (r.finished_at-r.started_at))/3600,
   'materials',coalesce((select jsonb_agg(to_jsonb(m)-'run_id' order by m.line_no) from plantlab_plant.process_material_lines m where m.run_id=r.id),'[]'::jsonb),
   'consumptions',coalesce((select jsonb_agg(to_jsonb(c)-'run_id' order by c.line_no) from plantlab_plant.packing_consumptions c where c.run_id=r.id),'[]'::jsonb))
 from plantlab_plant.process_runs r join plantlab_master.sites s on s.id=r.site_id
 join plantlab_master.products p on p.id=r.product_id left join plantlab_core.lots l on l.id=r.lot_id where r.id=p_id;
$$;
revoke all on function plantlab_plant.operation_document(uuid) from PUBLIC,anon,authenticated,service_role;

create function plantlab_api.get_plant_operation_options()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not plantlab_platform.has_module_permission('PLANT','inspection.read') then
    raise exception 'Plant access required' using errcode='42501';
  end if;
  return jsonb_build_object('forms',(select jsonb_agg(to_jsonb(f) order by process_code) from plantlab_plant.operation_form_versions f),
    'sites',(select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'site_code',s.site_code,'site_name',s.site_name,'company_id',s.company_id,
      'can_write',plantlab_platform.has_permission('PLANT','inspection.write',s.id,s.company_id)) order by s.site_code),'[]'::jsonb)
      from plantlab_master.sites s where s.is_active and s.site_type='PLANT' and plantlab_platform.has_permission('PLANT','inspection.read',s.id,s.company_id)),
    'products',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'sku',p.sku) order by p.name),'[]'::jsonb) from plantlab_master.products p where p.is_active),
    'lots',(select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'lot_code',l.lot_code,'site_id',l.plant_site_id,'product_id',l.product_id,'stage_code',l.stage_code) order by l.lot_code,l.id),'[]'::jsonb)
      from plantlab_core.lots l where plantlab_platform.can_access_plant_lot(l.id,'lot.read')));
end;
$$;

create function plantlab_api.save_plant_operation(p_document jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb:=p_document; r plantlab_plant.process_runs%rowtype; parent plantlab_plant.process_runs%rowtype;
  site plantlab_master.sites%rowtype; lot plantlab_core.lots%rowtype; f plantlab_plant.operation_form_versions%rowtype;
  v_id uuid:=(d->>'id')::uuid; v_site uuid:=(d->>'site_id')::uuid; v_lot uuid:=nullif(d->>'lot_id','')::uuid;
  v_product bigint:=(d->>'product_id')::bigint; v_process text:=d->>'process_code';
  v_submit boolean:=coalesce((d->>'submit')::boolean,false); v_start timestamptz:=(d->>'started_at')::timestamptz;
  v_end timestamptz:=nullif(d->>'finished_at','')::timestamptz; v_parent uuid:=nullif(d->>'revision_of_id','')::uuid;
  v_values jsonb:=coalesce(d->'values','{}'); v_materials jsonb:=coalesce(d->'materials','[]'); v_consumptions jsonb:=coalesce(d->'consumptions','[]');
  item jsonb; n integer:=0; amount numeric; input_total numeric:=0; output_total numeric:=0; reject_total numeric:=0;
  v_expected integer:=coalesce((d->>'expected_version')::integer,0); v_document jsonb; v_root uuid; v_revision integer:=0;
begin
  if auth.uid() is null or v_id is null or v_site is null or v_start is null or v_product is null
    or jsonb_typeof(d) is distinct from 'object' or pg_column_size(d)>200000 then raise exception 'Invalid operation document' using errcode='22023'; end if;
  if exists(select from jsonb_object_keys(d) k where k not in ('id','site_id','lot_id','product_id','process_code','started_at','finished_at','revision_of_id','submit','expected_version','values','materials','consumptions')) then
    raise exception 'Unknown document field' using errcode='22023'; end if;
  if jsonb_typeof(d->'started_at') is distinct from 'string' or (d->>'started_at') !~ '^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'
    or (v_end is not null and (d->>'finished_at') !~ '^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$')
    or (d ? 'submit' and jsonb_typeof(d->'submit')<>'boolean') then raise exception 'Expected ISO timestamp with timezone and boolean submit' using errcode='22023'; end if;
  select * into site from plantlab_master.sites s where s.id=v_site and s.is_active and s.site_type='PLANT';
  if not found or not plantlab_platform.has_permission('PLANT','inspection.write',site.id,site.company_id) then raise exception 'Plant write scope required' using errcode='42501'; end if;
  if not exists(select from plantlab_master.products p where p.id=v_product and p.is_active) then raise exception 'Active Plant/Lab product required' using errcode='22023'; end if;
  select * into f from plantlab_plant.operation_form_versions where process_code=v_process and version=1;
  if not found then raise exception 'Unknown process' using errcode='22023'; end if;
  if v_lot is null and v_process<>'RECEIVING' then raise exception 'Select lot for this process' using errcode='22023'; end if;
  if v_lot is not null then
    select * into lot from plantlab_core.lots where id=v_lot;
    if not found or lot.plant_site_id is distinct from site.id or lot.company_id is distinct from site.company_id or lot.product_id<>v_product
      or not plantlab_platform.can_access_plant_lot(v_lot,'lot.read') then raise exception 'Lot outside operation scope' using errcode='42501'; end if;
  end if;
  if v_start>now()+interval '5 minutes' or v_end>now()+interval '5 minutes' or v_end<v_start or (v_submit and v_end is null) then
    raise exception 'Check actual start and finish times' using errcode='22023'; end if;
  perform plantlab_plant.validate_operation_values(f.fields,v_values,v_submit);
  if jsonb_typeof(v_materials)<>'array' or jsonb_array_length(v_materials)>100 or jsonb_typeof(v_consumptions)<>'array' or jsonb_array_length(v_consumptions)>100 then
    raise exception 'Expected at most 100 material/consumption lines' using errcode='22023'; end if;
  for item in select value from jsonb_array_elements(v_materials) loop
    if jsonb_typeof(item)<>'object' or jsonb_typeof(item->'quantity_kg') is distinct from 'number'
      or coalesce(item->>'direction','') not in ('INPUT','OUTPUT','REJECT') or length(coalesce(item->>'reference_code',''))>100
      or length(coalesce(item->>'component',''))>100 then raise exception 'Invalid material line' using errcode='22023'; end if;
    if exists(select from jsonb_object_keys(item) k where k not in ('direction','lot_id','reference_code','component','quantity_kg')) then raise exception 'Unknown material field' using errcode='22023'; end if;
    amount:=(item->>'quantity_kg')::numeric;
    if amount<0 or amount>1e12 or amount::text in ('NaN','Infinity','-Infinity') then raise exception 'Invalid quantity' using errcode='22023'; end if;
    if nullif(item->>'lot_id','') is not null and not exists(select from plantlab_core.lots l where l.id=(item->>'lot_id')::uuid
      and l.plant_site_id=site.id and l.company_id=site.company_id and l.product_id=v_product and plantlab_platform.can_access_plant_lot(l.id,'lot.read')) then
      raise exception 'Material lot outside scope' using errcode='42501'; end if;
    if item->>'direction'='INPUT' then input_total:=input_total+amount;
    elsif item->>'direction'='OUTPUT' then output_total:=output_total+amount;
    else reject_total:=reject_total+amount; end if;
  end loop;
  if v_submit and v_process<>'RECEIVING' and (input_total<=0 or output_total<=0 or output_total+reject_total>input_total) then
    raise exception 'Positive feeding/output and accounted quantity <= feeding required' using errcode='22023'; end if;
  if v_process='RECEIVING' and jsonb_array_length(v_materials)>0 then raise exception 'Receiving weight belongs to weighbridge field, not a second material total' using errcode='22023'; end if;
  if v_process not in ('TREATMENT','PACKING') and jsonb_array_length(v_consumptions)>0 then raise exception 'Consumption belongs to treatment/packing' using errcode='22023'; end if;
  for item in select value from jsonb_array_elements(v_consumptions) loop
    if jsonb_typeof(item)<>'object' or jsonb_typeof(item->'quantity') is distinct from 'number'
      or length(btrim(coalesce(item->>'material_name',''))) not between 1 and 100
      or coalesce(item->>'unit_code','') not in ('GRAM','KG','ML','L','PIECE')
      or (item->>'quantity')::numeric<0 or (item->>'quantity')::numeric>1e12 then raise exception 'Invalid actual consumption' using errcode='22023'; end if;
    if exists(select from jsonb_object_keys(item) k where k not in ('material_name','unit_code','quantity')) then raise exception 'Unknown consumption field' using errcode='22023'; end if;
  end loop;
  -- Normalize absent optional fields before comparing a replay to stored rows.
  select coalesce(jsonb_agg(jsonb_build_object('direction',value->>'direction','lot_id',nullif(value->>'lot_id','')::uuid,
    'reference_code',value->>'reference_code','component',value->>'component','quantity_kg',(value->>'quantity_kg')::numeric) order by ord),'[]'::jsonb)
    into v_materials from jsonb_array_elements(v_materials) with ordinality as lines(value,ord);
  -- Transaction-level lock serializes initial create and concurrent/retried saves.
  perform pg_advisory_xact_lock(hashtextextended(v_id::text,0));
  select * into r from plantlab_plant.process_runs where id=v_id for update;
  if found then
    if r.created_by<>auth.uid() or r.site_id<>site.id then raise exception 'Cannot edit another actor record' using errcode='42501'; end if;
    v_document:=plantlab_plant.operation_document(r.id);
    -- Exact same retry is idempotent even if the caller lost the last response.
    if r.lot_id is not distinct from v_lot and r.product_id=v_product and r.process_code=v_process and r.started_at=v_start
      and r.finished_at is not distinct from v_end and r.input_values=v_values and r.revision_of_id is not distinct from v_parent
      and ((r.status='SUBMITTED' and v_submit) or (r.status='DRAFT' and not v_submit))
      and (select coalesce(jsonb_agg(value-'line_no' order by (value->>'line_no')::int),'[]') from jsonb_array_elements(v_document->'materials'))=v_materials
      and (select coalesce(jsonb_agg(value-'line_no' order by (value->>'line_no')::int),'[]') from jsonb_array_elements(v_document->'consumptions'))=v_consumptions then return v_document; end if;
    if r.status<>'DRAFT' then raise exception 'Submitted/final record is locked; create a controlled revision' using errcode='55000'; end if;
    if r.row_version<>v_expected then raise exception 'Record changed; reload before editing' using errcode='40001'; end if;
    if r.site_id<>v_site or r.process_code<>v_process or r.product_id<>v_product or r.revision_of_id is distinct from v_parent then raise exception 'Identity is locked after draft creation' using errcode='22023'; end if;
    update plantlab_plant.process_runs set lot_id=v_lot,started_at=v_start,finished_at=v_end,input_values=v_values,
      status=case when v_submit then 'SUBMITTED' else 'DRAFT' end,row_version=row_version+1,updated_at=now() where id=v_id;
    delete from plantlab_plant.process_material_lines where run_id=v_id;
    delete from plantlab_plant.packing_consumptions where run_id=v_id;
  else
    if v_expected<>0 then raise exception 'Unknown draft version' using errcode='40001'; end if;
    v_root:=v_id;
    if v_parent is not null then
      select * into parent from plantlab_plant.process_runs where id=v_parent for update;
      if not found or parent.status not in ('APPROVED','NEED_REVISION') or parent.created_by<>auth.uid()
        or parent.site_id<>site.id or parent.product_id<>v_product or parent.process_code<>v_process then raise exception 'Invalid revision source' using errcode='42501'; end if;
      v_root:=parent.root_id;
      v_revision:=parent.revision_no+1;
    end if;
    insert into plantlab_plant.process_runs(id,root_id,revision_of_id,revision_no,site_id,company_id,product_id,lot_id,process_code,form_version,started_at,finished_at,input_values,status,created_by)
    values(v_id,v_root,v_parent,v_revision,site.id,site.company_id,v_product,v_lot,v_process,1,v_start,v_end,v_values,case when v_submit then 'SUBMITTED' else 'DRAFT' end,auth.uid());
  end if;
  n:=0;
  for item in select value from jsonb_array_elements(v_materials) loop
    n:=n+1; insert into plantlab_plant.process_material_lines values(v_id,n,item->>'direction',nullif(item->>'lot_id','')::uuid,item->>'reference_code',item->>'component',(item->>'quantity_kg')::numeric);
  end loop;
  n:=0;
  for item in select value from jsonb_array_elements(v_consumptions) loop
    n:=n+1; insert into plantlab_plant.packing_consumptions values(v_id,n,item->>'material_name',item->>'unit_code',(item->>'quantity')::numeric);
  end loop;
  insert into plantlab_plant.operation_events(run_id,event_type,actor_id,details)
  values(v_id,case when v_submit then 'SUBMITTED' else 'DRAFT_SAVED' end,auth.uid(),plantlab_plant.operation_document(v_id));
  return plantlab_plant.operation_document(v_id);
end;
$$;

create function plantlab_api.list_plant_operations(p_limit integer default 30,p_offset integer default 0)
returns jsonb language sql stable security definer set search_path='' as $$
  with visible as materialized (select id,started_at from plantlab_plant.process_runs r where auth.uid() is not null
    and plantlab_platform.has_permission('PLANT','inspection.read',r.site_id,r.company_id)), page as (
    select * from visible order by started_at desc,id desc limit least(greatest(coalesce(p_limit,30),1),100) offset greatest(coalesce(p_offset,0),0))
  select jsonb_build_object('total',(select count(*) from visible),'records',coalesce((select jsonb_agg(plantlab_plant.operation_document(p.id) order by started_at desc,id desc) from page p),'[]'::jsonb));
$$;

create function plantlab_api.review_plant_operation(p_run_id uuid,p_expected_version integer,p_decision text,p_reason text,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r plantlab_plant.process_runs%rowtype; e plantlab_plant.operation_events%rowtype;
begin
  select * into r from plantlab_plant.process_runs where id=p_run_id for update;
  if not found or auth.uid() is null or not plantlab_platform.can_review_lot_pair(r.site_id,r.company_id)
    or r.created_by=auth.uid() then raise exception 'Independent Plant Supervisor required' using errcode='42501'; end if;
  if p_decision not in ('APPROVED','NEED_REVISION','VOIDED') or length(btrim(coalesce(p_reason,''))) not between 5 and 500 or p_action_id is null then
    raise exception 'Decision and specific reason required' using errcode='22023'; end if;
  select * into e from plantlab_plant.operation_events where action_id=p_action_id;
  if found then
    if e.run_id<>r.id or e.actor_id<>auth.uid() or e.event_type<>p_decision or e.details->>'reason'<>p_reason then raise exception 'Review idempotency key conflict' using errcode='22023'; end if;
    return plantlab_plant.operation_document(r.id);
  end if;
  if r.status<>'SUBMITTED' or r.row_version<>p_expected_version then raise exception 'Review target changed or is not submitted' using errcode='40001'; end if;
  update plantlab_plant.process_runs set status=p_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_reason=p_reason,
    row_version=row_version+1,updated_at=now() where id=r.id;
  insert into plantlab_plant.operation_events(run_id,action_id,event_type,actor_id,details)
    values(r.id,p_action_id,p_decision,auth.uid(),jsonb_build_object('reason',p_reason,'row_version',r.row_version+1));
  return plantlab_plant.operation_document(r.id);
end;
$$;

-- Quantity totals deliberately use only the latest approved revision per root.
create function plantlab_api.get_plant_daily_report(p_from date,p_to date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not plantlab_platform.has_module_permission('PLANT','inspection.read') then raise exception 'Plant access required' using errcode='42501'; end if;
  if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise exception 'Select a period of at most 367 days' using errcode='22023'; end if;
  return (with latest as materialized (
    select distinct on(root_id) r.* from plantlab_plant.process_runs r
    where status='APPROVED' and plantlab_platform.has_permission('PLANT','inspection.read',r.site_id,r.company_id)
    order by root_id,revision_no desc,id desc
  ), rows as (select r.*,s.site_code,s.timezone_name,(r.started_at at time zone s.timezone_name)::date as business_date
    from latest r join plantlab_master.sites s on s.id=r.site_id), selected as (
    select r.*,coalesce((select sum(quantity_kg) from plantlab_plant.process_material_lines where run_id=r.id and direction='INPUT'),
      case when r.process_code='RECEIVING' then (r.input_values->>'plant_weight_kg')::numeric end) as input_kg,
      (select sum(quantity_kg) from plantlab_plant.process_material_lines where run_id=r.id and direction='OUTPUT') as output_kg,
      (select sum(quantity_kg) from plantlab_plant.process_material_lines where run_id=r.id and direction='REJECT') as reject_kg
    from rows r where business_date between p_from and p_to
  ) select jsonb_build_object('basis','LATEST_APPROVED_OPERATION_REVISION_NOT_LOT_RELEASE','from',p_from,'to',p_to,
    'rows',coalesce(jsonb_agg(jsonb_build_object('date',business_date,'site_code',site_code,'process_code',process_code,
      'run_id',id,'input_kg',input_kg,'output_kg',output_kg,'reject_kg',reject_kg,
      'recovery_percent',case when input_kg>0 and output_kg is not null then 100*output_kg/input_kg end,
      'duration_hours',extract(epoch from(finished_at-started_at))/3600) order by business_date,site_code,process_code,id),'[]'::jsonb)) from selected);
end;
$$;

revoke all on function plantlab_api.get_plant_operation_options(),plantlab_api.save_plant_operation(jsonb),
  plantlab_api.list_plant_operations(integer,integer),plantlab_api.review_plant_operation(uuid,integer,text,text,uuid),
  plantlab_api.get_plant_daily_report(date,date) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_plant_operation_options(),plantlab_api.save_plant_operation(jsonb),
  plantlab_api.list_plant_operations(integer,integer),plantlab_api.review_plant_operation(uuid,integer,text,text,uuid),
  plantlab_api.get_plant_daily_report(date,date) to authenticated;
commit;
