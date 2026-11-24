-- PI capture reuses Plant tests/components/attachments. No Auth provisioning,
-- legacy policy edits, master promotion, Lab-result changes or lot release.
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
set local search_path=pg_catalog;

create table plantlab_plant.pi_test_contexts (
  test_id uuid primary key references plantlab_plant.tests(id),
  revision_of_id uuid unique references plantlab_plant.pi_test_contexts(test_id),
  material_form text not null check(material_form in ('GLEONDONG','SEED')),
  crop_kind text not null check(crop_kind in ('FC','SWC','UNKNOWN')),
  programme text not null check(programme in ('COMMERCIAL','PARENT_SEED','UNKNOWN')),
  method_reference text not null, equipment_reference text not null, notes text not null default '',
  seed_count integer check(seed_count is null or seed_count=1000),
  source_status text not null default 'DRAFT' check(source_status in ('DRAFT','SUBMITTED','VERIFIED','REVISION_REQUIRED')),
  assessment jsonb not null default '{}'::jsonb,
  row_version integer not null default 1 check(row_version>0),
  created_by uuid not null references plantlab_platform.identities(id),
  reviewed_by uuid references plantlab_platform.identities(id), reviewed_at timestamptz, review_reason text,
  created_at timestamptz not null default now()
);
create table plantlab_plant.pi_reference_rules (
  crop_kind text not null, programme text not null, version integer not null,
  minimum_percent numeric not null check(minimum_percent between 0 and 100),
  source_note text not null, effective_from timestamptz not null default now(),
  primary key(crop_kind,programme,version)
);
insert into plantlab_plant.pi_reference_rules values
 ('FC','PARENT_SEED',1,99,'Owner screenshot 2026-11-09: internal PP minimum. Not regulatory certification.',now()),
 ('SWC','PARENT_SEED',1,99.8,'Owner screenshot 2026-11-09: internal PP minimum. Not regulatory certification.',now()),
 ('FC','COMMERCIAL',1,98,'Owner screenshot 2026-11-09: internal PP minimum. Not regulatory certification.',now()),
 ('SWC','COMMERCIAL',1,99.5,'Owner screenshot 2026-11-09: internal PP minimum. Not regulatory certification.',now());
create table plantlab_plant.pi_test_events (
  action_id uuid primary key, test_id uuid not null references plantlab_plant.tests(id),
  actor_id uuid not null references plantlab_platform.identities(id), event_type text not null,
  payload_sha256 text not null, response jsonb not null, occurred_at timestamptz not null default now()
);
create table plantlab_lab.pi_source_reviews (
  action_id uuid primary key, test_id uuid not null references plantlab_plant.tests(id),
  request_id uuid not null references plantlab_lab.requests(id),
  decision text not null check(decision in ('ACKNOWLEDGED','CLARIFICATION_REQUIRED')),
  reason text not null check(length(btrim(reason)) between 3 and 1000),
  reviewed_by uuid not null references plantlab_platform.identities(id), reviewed_at timestamptz not null default now()
);
alter table plantlab_plant.pi_test_contexts enable row level security;
alter table plantlab_plant.pi_reference_rules enable row level security;
alter table plantlab_plant.pi_test_events enable row level security;
alter table plantlab_lab.pi_source_reviews enable row level security;
revoke all on plantlab_plant.pi_test_contexts,plantlab_plant.pi_reference_rules,
  plantlab_plant.pi_test_events,plantlab_lab.pi_source_reviews from PUBLIC,anon,authenticated,service_role;

create function plantlab_platform.has_exact_scoped_role(p_module text,p_role text,p_site uuid,p_company bigint)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select from plantlab_platform.user_role_assignments a
 join plantlab_platform.role_definitions r on r.id=a.role_id
 join plantlab_platform.module_registry m on m.id=r.module_id
 where a.user_id=auth.uid() and a.is_active and r.is_active and m.is_active
 and m.module_code=p_module and r.role_code=p_role and a.valid_from<=now()
 and (a.valid_until is null or a.valid_until>now())
 and a.region_code is null
 and (p_role<>'PLANT_PI' or r.permissions ? 'test.write' or r.permissions ? '*')
 and (a.site_id is null or a.site_id=p_site) and (a.company_id is null or a.company_id=p_company));
$$;
create function plantlab_plant.can_read_pi_test(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(plantlab_platform.can_access_plant_lot(t.lot_id,'test.read') or
 (c.source_status<>'DRAFT' and exists(select from plantlab_lab.requests q
 where q.lot_id=t.lot_id and plantlab_platform.has_permission('LAB','request.read',q.target_lab_site_id,l.company_id))),false)
 from plantlab_plant.tests t join plantlab_plant.pi_test_contexts c on c.test_id=t.id
 join plantlab_core.lots l on l.id=t.lot_id where t.id=p_id;
$$;
create function plantlab_plant.pi_test_document(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',t.id,'test_code',t.test_code,'lot_id',t.lot_id,'lot_code',l.lot_code,
 'site_code',s.site_code,'test_type',t.test_type,'numeric_value',t.numeric_value,'unit_code',t.unit_code,
 'tested_at',t.tested_at,'attempt_no',t.attempt_no,'canonical_status',t.status,'created_by',c.created_by,
 'revision_of_id',c.revision_of_id,'material_form',c.material_form,'crop_kind',c.crop_kind,'programme',c.programme,
 'method_reference',c.method_reference,'equipment_reference',c.equipment_reference,'seed_count',c.seed_count,
 'notes',c.notes,'source_status',c.source_status,'row_version',c.row_version,'assessment',c.assessment,
 'review_reason',c.review_reason,'reviewed_at',c.reviewed_at,
 'can_write',c.created_by=auth.uid() and c.source_status='DRAFT' and plantlab_platform.has_exact_scoped_role('PLANT','PLANT_PI',l.plant_site_id,l.company_id),
 'can_review',c.created_by<>auth.uid() and c.source_status='SUBMITTED' and plantlab_platform.has_exact_scoped_role('PLANT','PLANT_SPV',l.plant_site_id,l.company_id),
 'can_revise',c.source_status in ('VERIFIED','REVISION_REQUIRED') and plantlab_platform.has_exact_scoped_role('PLANT','PLANT_PI',l.plant_site_id,l.company_id)
   and not exists(select from plantlab_plant.pi_test_contexts child where child.revision_of_id=t.id),
 'components',coalesce((select jsonb_object_agg(p.parameter_code,v.numeric_value) from plantlab_plant.test_result_values v
 join plantlab_lab.parameters p on p.id=v.parameter_id where v.plant_test_id=t.id),'{}'),
 'evidence',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'path',a.storage_path,'filename',a.original_filename,
   'captured_at',a.captured_at,'mime_type',a.mime_type,'bytes',a.byte_size) order by a.created_at,a.id)
 from plantlab_core.attachments a where a.module_code='PLANT' and a.entity_type='TEST' and a.entity_key=t.id::text
 and a.storage_bucket='plantlab-pi-evidence'),'[]'),
 'lab_requests',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'request_code',q.request_code,
   'can_review',c.source_status='VERIFIED' and c.created_by<>auth.uid()
    and plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',q.target_lab_site_id,l.company_id)))
 from plantlab_lab.requests q where q.lot_id=t.lot_id and plantlab_platform.has_permission('LAB','request.read',q.target_lab_site_id,l.company_id)),'[]'),
 'lab_reviews',coalesce((select jsonb_agg(jsonb_build_object('request_id',r.request_id,'decision',r.decision,'reason',r.reason,'reviewed_at',r.reviewed_at) order by r.reviewed_at desc)
 from plantlab_lab.pi_source_reviews r join plantlab_lab.requests q on q.id=r.request_id where r.test_id=t.id
 and (plantlab_platform.can_access_plant_lot(t.lot_id,'test.read') or plantlab_platform.has_permission('LAB','request.read',q.target_lab_site_id,l.company_id))),'[]'))
 from plantlab_plant.tests t join plantlab_plant.pi_test_contexts c on c.test_id=t.id
 join plantlab_core.lots l on l.id=t.lot_id join plantlab_master.sites s on s.id=l.plant_site_id
 where t.id=p_id and plantlab_plant.can_read_pi_test(t.id);
$$;
create function plantlab_api.get_pi_test_options()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (plantlab_platform.has_module_permission('PLANT','test.read') or plantlab_platform.has_module_permission('LAB','request.read')) then
 raise exception 'Plant/Lab access required' using errcode='42501'; end if;
 return jsonb_build_object('schema_version',1,'evidence_bucket','plantlab-pi-evidence','max_image_bytes',8388608,
 'activation_note','Input requires a separately assigned PLANT_PI role. No new Auth account has been provisioned.',
 'lots',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'lot_code',l.lot_code,'stage_code',l.stage_code,
 'crop_category_code',l.crop_category_code,'product_name',p.name,'site_code',s.site_code,
 'can_write',plantlab_platform.has_exact_scoped_role('PLANT','PLANT_PI',l.plant_site_id,l.company_id)) order by l.lot_code,l.id)
 from plantlab_core.lots l join plantlab_master.products p on p.id=l.product_id join plantlab_master.sites s on s.id=l.plant_site_id
 where plantlab_platform.can_access_plant_lot(l.id,'test.read')),'[]'),
 'types','[{"code":"MC","unit":"PERCENT","minimum_images":3},{"code":"PP","unit":"PERCENT","minimum_images":1},{"code":"TSW","unit":"GRAM","minimum_images":0}]'::jsonb,
 'pp_components','["WORKING_SAMPLE_GRAM","PURE_SEED_GRAM","INERT_MATTER_GRAM","FUNGI_GRAM","DAMAGE_GRAM","PREGERM_GRAM","SMALL_SEED_GRAM","OTHER_SEED_GRAM","TOTAL_COMPONENT_GRAM"]'::jsonb);
end;
$$;
create function plantlab_api.list_pi_tests(p_limit integer default 20,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (plantlab_platform.has_module_permission('PLANT','test.read') or plantlab_platform.has_module_permission('LAB','request.read')) then
 raise exception 'Plant/Lab access required' using errcode='42501'; end if;
 if p_limit not between 1 and 50 or p_offset<0 or p_limit is null or p_offset is null then raise exception 'Invalid page' using errcode='22023'; end if;
 return jsonb_build_object('total',(select count(*) from plantlab_plant.pi_test_contexts c where plantlab_plant.can_read_pi_test(c.test_id)),
 'records',coalesce((select jsonb_agg(plantlab_plant.pi_test_document(q.test_id) order by q.created_at desc,q.test_id)
 from(select c.test_id,c.created_at from plantlab_plant.pi_test_contexts c where plantlab_plant.can_read_pi_test(c.test_id)
 order by c.created_at desc,c.test_id limit p_limit offset p_offset) q),'[]'));
end;
$$;

-- For these new PI records only, measurements remain source measurements.
-- Do not inherit the legacy universal MC<=32 or turn an internal reference into PASS.
create function plantlab_plant.protect_pi_test_measurement()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select from plantlab_plant.pi_test_contexts where test_id=old.id) then
   if old.status<>'DRAFT' then raise exception 'Submitted PI source is immutable; create a revision' using errcode='55000'; end if;
   new.lower_spec:=null; new.upper_spec:=null; new.result:='PENDING_REVIEW';
 end if;
 return new;
end;
$$;
create trigger c_pi_test_measurement_guard before update on plantlab_plant.tests
 for each row execute function plantlab_plant.protect_pi_test_measurement();

create function plantlab_plant.pi_assessment(p_type text,p_value numeric,p_form text,p_crop text,p_programme text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r plantlab_plant.pi_reference_rules; bound numeric; kind text:='NO_APPROVED_REFERENCE';
begin
 if p_type='PP' then
   select * into r from plantlab_plant.pi_reference_rules where crop_kind=p_crop and programme=p_programme and effective_from<=now() order by version desc limit 1;
   if found then bound:=r.minimum_percent; kind:='OWNER_INTERNAL_PP_REFERENCE'; else kind:='PENDING_CLASSIFICATION'; end if;
 elsif p_type='MC' and p_form='GLEONDONG' then bound:=32; kind:='BLUEPRINT_GLEONDONG_ONLY'; end if;
 return jsonb_build_object('basis',kind,'minimum_percent',case when p_type='PP' then bound end,
 'maximum_percent',case when p_type='MC' then bound end,'reference_version',r.version,
 'assessment',case when bound is null then kind when p_type='PP' and p_value<bound or p_type='MC' and p_value>bound
 then 'OUTSIDE_INTERNAL_REFERENCE' else 'MEETS_INTERNAL_REFERENCE' end,
 'classification_source','PI_DECLARATION_NOT_MASTER_PROMOTION','is_official_specification',false,'authorizes_lot_release',false);
end;
$$;
create function plantlab_api.save_pi_test(p_document jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb:=p_document; v_id uuid:=(d->>'id')::uuid; v_action uuid:=(d->>'action_id')::uuid;
 v_lot uuid:=(d->>'lot_id')::uuid; v_type text:=d->>'test_type'; v_parent uuid:=nullif(d->>'revision_of_id','')::uuid;
 v_final boolean:=coalesce((d->>'submit')::boolean,false); v_expected int:=(d->>'expected_version')::int;
 v_value numeric; v_at timestamptz; v_components jsonb:=coalesce(d->'components','{}'); item record;
 l plantlab_core.lots; t plantlab_plant.tests; c plantlab_plant.pi_test_contexts; parent plantlab_plant.tests;
 previous plantlab_plant.pi_test_events; h text:=encode(sha256(convert_to(d::text,'UTF8')),'hex'); response jsonb; v_attempt int;
begin
 if auth.uid() is null or v_id is null or v_action is null or v_lot is null or v_expected is null or jsonb_typeof(d)<>'object' then raise exception 'PI identity/version required' using errcode='22023'; end if;
 select * into l from plantlab_core.lots where id=v_lot;
 if not found or not plantlab_platform.has_exact_scoped_role('PLANT','PLANT_PI',l.plant_site_id,l.company_id) then
 raise exception 'Assigned PI role required in this site' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_action::text,891));
 select * into previous from plantlab_plant.pi_test_events where action_id=v_action;
 if found then
   if previous.actor_id<>auth.uid() or previous.payload_sha256<>h then raise exception 'Action key reused with different content' using errcode='22023'; end if;
   return previous.response;
 end if;
 if exists(select from jsonb_object_keys(d) k where k not in ('id','action_id','lot_id','test_type','revision_of_id','submit','expected_version',
 'numeric_value','tested_at','material_form','crop_kind','programme','method_reference','equipment_reference','seed_count','notes','components'))
 or v_type is null or v_type not in ('PP','MC','TSW') or coalesce(d->>'material_form','') not in ('GLEONDONG','SEED')
 or coalesce(d->>'crop_kind','') not in ('FC','SWC','UNKNOWN') or coalesce(d->>'programme','') not in ('COMMERCIAL','PARENT_SEED','UNKNOWN') then
 raise exception 'Invalid PI fields/classification' using errcode='22023'; end if;
 if v_type<>'MC' and d->>'material_form'<>'SEED' then raise exception 'PP/TSW require seed sample form' using errcode='22023'; end if;
 if l.crop_category_code in ('FC','SWC') and d->>'crop_kind' not in (l.crop_category_code,'UNKNOWN') then raise exception 'Crop declaration conflicts with lot' using errcode='22023'; end if;
 if d->>'tested_at' is null or d->>'tested_at' !~ '^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$' then raise exception 'Actual test time with timezone required' using errcode='22023'; end if;
 v_at:=(d->>'tested_at')::timestamptz;
 if v_at>now()+interval '5 minutes' then raise exception 'Test time cannot be in the future' using errcode='22023'; end if;
 if coalesce(length(d->>'method_reference'),0)>300 or coalesce(length(d->>'equipment_reference'),0)>300 or coalesce(length(d->>'notes'),0)>1000 then raise exception 'Text too long' using errcode='22023'; end if;
 if d->'numeric_value' is not null and d->'numeric_value'<>'null'::jsonb then
   if jsonb_typeof(d->'numeric_value')<>'number' then raise exception 'Numeric measurement required' using errcode='22023'; end if;
   v_value:=(d->>'numeric_value')::numeric;
   if v_value::text in ('NaN','Infinity','-Infinity') or v_value<0 or v_value>(case when v_type='TSW' then 1000000 else 100 end) then raise exception 'Measurement out of range/unit' using errcode='22023'; end if;
 end if;
 if v_type='TSW' and (d->>'seed_count')::numeric is distinct from 1000 then raise exception 'TSW represents exactly 1000 seeds, in grams' using errcode='22023'; end if;
 if v_type<>'TSW' and d->>'seed_count' is not null then raise exception 'Seed count belongs to TSW' using errcode='22023'; end if;
 if jsonb_typeof(v_components)<>'object' or (v_type<>'PP' and v_components<>'{}') then raise exception 'Components belong to PP' using errcode='22023'; end if;
 for item in select * from jsonb_each(v_components) loop
   if item.key not in ('WORKING_SAMPLE_GRAM','PURE_SEED_GRAM','INERT_MATTER_GRAM','FUNGI_GRAM','DAMAGE_GRAM','PREGERM_GRAM','SMALL_SEED_GRAM','OTHER_SEED_GRAM','TOTAL_COMPONENT_GRAM')
   or jsonb_typeof(item.value)<>'number' or (item.value#>>'{}')::numeric<0 or (item.value#>>'{}')::numeric>1000000 then
   raise exception 'Invalid PP gram component' using errcode='22023'; end if;
 end loop;
 if (v_components->>'PURE_SEED_GRAM')::numeric>(v_components->>'WORKING_SAMPLE_GRAM')::numeric then raise exception 'Pure seed exceeds working sample grams' using errcode='22023'; end if;
 if v_final and (v_value is null or v_type='TSW' and v_value<=0 or length(btrim(coalesce(d->>'method_reference','')))=0 or length(btrim(coalesce(d->>'equipment_reference','')))=0) then
 raise exception 'Measurement, method and equipment required before submit' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_lot::text,892));
 select * into t from plantlab_plant.tests where id=v_id for update;
 if found then
   select * into c from plantlab_plant.pi_test_contexts where test_id=v_id for update;
   if c.test_id is null or c.created_by<>auth.uid() or t.lot_id<>v_lot or t.test_type<>v_type or c.revision_of_id is distinct from v_parent then raise exception 'Cannot replace PI identity/owner' using errcode='42501'; end if;
   if c.source_status<>'DRAFT' or t.status<>'DRAFT' then raise exception 'Submitted PI source is immutable' using errcode='55000'; end if;
   if c.row_version<>v_expected then raise exception 'PI draft version conflict; reload' using errcode='40001'; end if;
 else
   if v_expected<>0 then raise exception 'New PI draft version must be zero' using errcode='40001'; end if;
   if v_parent is not null then
     select pt.* into parent from plantlab_plant.tests pt join plantlab_plant.pi_test_contexts pc on pc.test_id=pt.id
     where pt.id=v_parent and pc.source_status in ('VERIFIED','REVISION_REQUIRED');
     if not found or parent.lot_id<>v_lot or parent.test_type<>v_type then raise exception 'Invalid PI revision parent' using errcode='22023'; end if;
   end if;
   select coalesce(max(attempt_no),0)+1 into v_attempt from plantlab_plant.tests where lot_id=v_lot and test_type=v_type and sample_id is null and process_step_id is null;
   insert into plantlab_plant.tests(id,lot_id,test_type,unit_code,attempt_no,created_by,updated_by,tested_by)
   values(v_id,v_lot,v_type,case when v_type='TSW' then 'GRAM' else 'PERCENT' end,v_attempt,auth.uid(),auth.uid(),auth.uid());
   insert into plantlab_plant.pi_test_contexts(test_id,revision_of_id,material_form,crop_kind,programme,method_reference,equipment_reference,created_by)
   values(v_id,v_parent,d->>'material_form',d->>'crop_kind',d->>'programme',coalesce(d->>'method_reference',''),coalesce(d->>'equipment_reference',''),auth.uid());
 end if;
 update plantlab_plant.tests set numeric_value=v_value,tested_at=v_at,updated_by=auth.uid() where id=v_id;
 delete from plantlab_plant.test_result_values where plant_test_id=v_id;
 insert into plantlab_plant.test_result_values(plant_test_id,parameter_id,numeric_value,unit_code,recorded_by)
 select v_id,p.id,(x.value#>>'{}')::numeric,'GRAM',auth.uid() from jsonb_each(v_components) x join plantlab_lab.parameters p on p.parameter_code=x.key;
 update plantlab_plant.pi_test_contexts set material_form=d->>'material_form',crop_kind=d->>'crop_kind',programme=d->>'programme',
 method_reference=coalesce(d->>'method_reference',''),equipment_reference=coalesce(d->>'equipment_reference',''),notes=coalesce(d->>'notes',''),
 seed_count=(d->>'seed_count')::integer,row_version=case when v_expected=0 then 1 else row_version+1 end where test_id=v_id;
 if v_final then
   if (select count(*) from plantlab_core.attachments a join storage.objects o on o.bucket_id=a.storage_bucket and o.name=a.storage_path
      where a.entity_type='TEST' and a.entity_key=v_id::text and a.storage_bucket='plantlab-pi-evidence' and a.uploaded_by=auth.uid())
      <(case v_type when 'MC' then 3 when 'PP' then 1 else 0 end) then raise exception 'Uploaded evidence missing: MC 3 images, PP 1 image' using errcode='22023'; end if;
   update plantlab_plant.tests set status='SUBMITTED',updated_by=auth.uid() where id=v_id;
   update plantlab_plant.pi_test_contexts set source_status='SUBMITTED',assessment=plantlab_plant.pi_assessment(v_type,v_value,d->>'material_form',d->>'crop_kind',d->>'programme') where test_id=v_id;
 end if;
 response:=plantlab_plant.pi_test_document(v_id);
 insert into plantlab_plant.pi_test_events values(v_action,v_id,auth.uid(),case when v_final then 'SUBMITTED' else 'DRAFT_SAVED' end,h,response,now());
 return response;
end;
$$;

create function plantlab_plant.can_access_pi_object(p_name text,p_write boolean)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_id uuid; c plantlab_plant.pi_test_contexts; l plantlab_core.lots;
begin
 if p_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return false; end if;
 begin v_id:=split_part(p_name,'/',1)::uuid; exception when invalid_text_representation then return false; end;
 if not p_write then return coalesce(plantlab_plant.can_read_pi_test(v_id),false); end if;
 select * into c from plantlab_plant.pi_test_contexts where test_id=v_id;
 select lot.* into l from plantlab_core.lots lot join plantlab_plant.tests t on t.lot_id=lot.id where t.id=v_id;
 return coalesce(c.source_status='DRAFT' and c.created_by=auth.uid() and plantlab_platform.has_exact_scoped_role('PLANT','PLANT_PI',l.plant_site_id,l.company_id),false);
end;
$$;
-- A dedicated private bucket only. Existing buckets/policies remain unchanged.
do $$ begin
 if exists(select from storage.buckets where id='plantlab-pi-evidence') then raise exception 'PI bucket already exists; inspect rather than overwrite'; end if;
end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('plantlab-pi-evidence','plantlab-pi-evidence',false,8388608,array['image/jpeg','image/png','image/webp']);
create policy plantlab_pi_evidence_insert on storage.objects for insert to authenticated
 with check(bucket_id='plantlab-pi-evidence' and owner_id=auth.uid()::text and plantlab_plant.can_access_pi_object(name,true));
create policy plantlab_pi_evidence_select on storage.objects for select to authenticated
 using(bucket_id='plantlab-pi-evidence' and plantlab_plant.can_access_pi_object(name,false));
-- No object UPDATE/DELETE policy: submitted evidence cannot be overwritten.

create function plantlab_api.register_pi_evidence(p_test_id uuid,p_path text,p_filename text,p_captured_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare obj storage.objects; t plantlab_plant.tests; l plantlab_core.lots; a plantlab_core.attachments; c plantlab_plant.pi_test_contexts;
begin
 select * into c from plantlab_plant.pi_test_contexts where test_id=p_test_id for update;
 if not found or not plantlab_plant.can_access_pi_object(p_path,true) or split_part(p_path,'/',1)<>p_test_id::text then raise exception 'Evidence outside editable PI draft' using errcode='42501'; end if;
 if p_captured_at is null or p_captured_at>now()+interval '5 minutes' or p_filename is null or length(p_filename) not between 1 and 150 then raise exception 'Actual capture time and filename required' using errcode='22023'; end if;
 select * into obj from storage.objects where bucket_id='plantlab-pi-evidence' and name=p_path and owner_id=auth.uid()::text;
 if not found or coalesce(obj.metadata->>'mimetype','') not in ('image/jpeg','image/png','image/webp')
   or coalesce((obj.metadata->>'size')::bigint,0) not between 1 and 8388608 then raise exception 'Uploaded image object missing or invalid' using errcode='22023'; end if;
 select * into a from plantlab_core.attachments where storage_bucket='plantlab-pi-evidence' and storage_path=p_path;
 if found then
   if a.entity_key<>p_test_id::text or a.uploaded_by<>auth.uid() or a.captured_at<>p_captured_at or a.original_filename<>p_filename then raise exception 'Immutable evidence metadata differs' using errcode='22023'; end if;
   return plantlab_plant.pi_test_document(p_test_id);
 end if;
 if (select count(*) from plantlab_core.attachments where storage_bucket='plantlab-pi-evidence' and entity_key=p_test_id::text)>=12 then raise exception 'Maximum 12 evidence images per PI test' using errcode='22023'; end if;
 select * into t from plantlab_plant.tests where id=p_test_id;
 select * into l from plantlab_core.lots where id=t.lot_id;
 insert into plantlab_core.attachments(module_code,entity_type,entity_key,category,site_id,company_id,storage_bucket,storage_path,original_filename,mime_type,byte_size,captured_at,uploaded_by,metadata)
 values('PLANT','TEST',p_test_id::text,'EVIDENCE',l.plant_site_id,l.company_id,'plantlab-pi-evidence',p_path,p_filename,obj.metadata->>'mimetype',(obj.metadata->>'size')::bigint,p_captured_at,auth.uid(),'{"capture_time_source":"USER_DECLARED","object_verified":true}');
 update plantlab_plant.pi_test_contexts set row_version=row_version+1 where test_id=p_test_id;
 return plantlab_plant.pi_test_document(p_test_id);
end;
$$;
create function plantlab_api.review_pi_test(p_test_id uuid,p_expected_version integer,p_decision text,p_reason text,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c plantlab_plant.pi_test_contexts; l plantlab_core.lots; e plantlab_plant.pi_test_events; response jsonb;
 h text:=encode(sha256(convert_to(jsonb_build_array(p_test_id,p_expected_version,p_decision,p_reason)::text,'UTF8')),'hex');
begin
 if p_action_id is null or p_decision is null or p_decision not in ('VERIFIED','REVISION_REQUIRED') or length(btrim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'Source decision and reason required' using errcode='22023'; end if;
 select lot.* into l from plantlab_core.lots lot join plantlab_plant.tests t on t.lot_id=lot.id where t.id=p_test_id;
 if not found or not plantlab_platform.has_exact_scoped_role('PLANT','PLANT_SPV',l.plant_site_id,l.company_id) then raise exception 'Scoped SPV required' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_action_id::text,891));
 select * into e from plantlab_plant.pi_test_events where action_id=p_action_id;
 if found then
 if e.actor_id<>auth.uid() or e.payload_sha256<>h then raise exception 'Action key conflict' using errcode='22023'; end if; return e.response; end if;
 select * into c from plantlab_plant.pi_test_contexts where test_id=p_test_id for update;
 if c.test_id is null or c.created_by=auth.uid() then raise exception 'Independent SPV source review required' using errcode='42501'; end if;
 if c.source_status<>'SUBMITTED' then raise exception 'PI source is not awaiting review' using errcode='55000'; end if;
 if c.row_version is distinct from p_expected_version then raise exception 'PI source version conflict' using errcode='40001'; end if;
 update plantlab_plant.pi_test_contexts set source_status=p_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_reason=p_reason,row_version=row_version+1 where test_id=p_test_id;
 response:=plantlab_plant.pi_test_document(p_test_id);
 insert into plantlab_plant.pi_test_events values(p_action_id,p_test_id,auth.uid(),'SPV_SOURCE_'||p_decision,h,response,now());
 return response;
end;
$$;
create function plantlab_api.review_pi_source(p_test_id uuid,p_request_id uuid,p_decision text,p_reason text,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare q plantlab_lab.requests; l plantlab_core.lots; c plantlab_plant.pi_test_contexts; e plantlab_plant.pi_test_events; response jsonb;
 h text:=encode(sha256(convert_to(jsonb_build_array(p_test_id,p_request_id,p_decision,p_reason)::text,'UTF8')),'hex');
begin
 if p_action_id is null or p_decision is null or p_decision not in ('ACKNOWLEDGED','CLARIFICATION_REQUIRED') or length(btrim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'Lab source decision and reason required' using errcode='22023'; end if;
 select * into q from plantlab_lab.requests where id=p_request_id;
 select lot.* into l from plantlab_core.lots lot join plantlab_plant.tests t on t.lot_id=lot.id where t.id=p_test_id;
 if q.id is null or l.id is null or q.lot_id<>l.id or not plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',q.target_lab_site_id,l.company_id) then raise exception 'Matching request and scoped Lab QA required' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_action_id::text,891));
 select * into e from plantlab_plant.pi_test_events where action_id=p_action_id;
 if found then
 if e.actor_id<>auth.uid() or e.payload_sha256<>h then raise exception 'Action key conflict' using errcode='22023'; end if; return e.response; end if;
 select * into c from plantlab_plant.pi_test_contexts where test_id=p_test_id for update;
 if c.test_id is null or c.created_by=auth.uid() or c.source_status<>'VERIFIED' then raise exception 'Independent review of verified PI source required' using errcode='42501'; end if;
 insert into plantlab_lab.pi_source_reviews values(p_action_id,p_test_id,p_request_id,p_decision,p_reason,auth.uid(),now());
 response:=plantlab_plant.pi_test_document(p_test_id);
 insert into plantlab_plant.pi_test_events values(p_action_id,p_test_id,auth.uid(),'LAB_SOURCE_'||p_decision,h,response,now());
 return response;
end;
$$;

revoke all on function plantlab_platform.has_exact_scoped_role(text,text,uuid,bigint),
 plantlab_plant.can_read_pi_test(uuid),plantlab_plant.pi_test_document(uuid),plantlab_plant.pi_assessment(text,numeric,text,text,text),
 plantlab_plant.protect_pi_test_measurement() from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_plant.can_access_pi_object(text,boolean) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_plant.can_access_pi_object(text,boolean) to authenticated;
revoke all on function plantlab_api.get_pi_test_options(),plantlab_api.list_pi_tests(integer,integer),plantlab_api.save_pi_test(jsonb),
 plantlab_api.register_pi_evidence(uuid,text,text,timestamptz),plantlab_api.review_pi_test(uuid,integer,text,text,uuid),
 plantlab_api.review_pi_source(uuid,uuid,text,text,uuid) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_pi_test_options(),plantlab_api.list_pi_tests(integer,integer),plantlab_api.save_pi_test(jsonb),
 plantlab_api.register_pi_evidence(uuid,text,text,timestamptz),plantlab_api.review_pi_test(uuid,integer,text,text,uuid),
 plantlab_api.review_pi_source(uuid,uuid,text,text,uuid) to authenticated;
comment on table plantlab_plant.pi_test_contexts is 'PI source capture/review, not Lab approval or lot release. Canonical submitted tests and components remain immutable; revise with a new attempt.';
notify pgrst,'reload schema';
commit;
