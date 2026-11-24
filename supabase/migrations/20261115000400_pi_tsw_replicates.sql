-- Optional PI TSW 8x100 capture, distinct from direct weighing of1000seeds.
-- No new role assignments, Lab writes, official specification or lot release.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create function plantlab_plant.calculate_tsw_weights(p_weights jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare x jsonb;n int:=0;total numeric:=0;mean numeric;variance numeric;cv numeric;value numeric;state text:='INCOMPLETE';
begin
 if jsonb_typeof(p_weights) is distinct from 'array' or jsonb_array_length(p_weights)<>8 then raise exception 'Eight100-seed readings required' using errcode='22023';end if;
 for x in select v from jsonb_array_elements(p_weights)v loop
  if x<>'null'::jsonb then
   if jsonb_typeof(x)<>'number' or x::text in('NaN','Infinity','-Infinity') or x::numeric not between 0 and 100000 then raise exception 'Weights must be grams,0..100000; blank is not zero' using errcode='22023';end if;
   n:=n+1;total:=total+x::numeric;
  end if;
 end loop;
 if n=8 then
  mean:=total/8;
  select sum(power(v::numeric-mean,2))/8 into variance from jsonb_array_elements(p_weights)v;
  if mean>0 then
   cv:=sqrt(variance)/mean*100;
   -- Compare squared values to avoid rounding CV before its4%source boundary.
   if variance<=mean*mean*0.0016 then state:='WITHIN_WORKBOOK_REFERENCE';value:=mean*10;else state:='RECOUNT_WORKBOOK_REFERENCE';end if;
  else state:='ZERO_MEAN';end if;
 end if;
 return jsonb_build_object('version',1,'weights_g',p_weights,'entered_count',n,'replicate_count',8,'seeds_per_replicate',100,'actual_seed_count',800,'result_seed_basis',1000,
  'mean_100_g',mean,'population_variance_g2',variance,'cv_percent',cv,'tsw_g',value,'kernel_per_kg',case when value>0 then 1000000/value end,
  'reference_cv_percent',4,'calculation_state',state,'source_reference','Copy of KC Lab.xlsx / MC,PP,TSW!AJ3:BI3; All Form.xlsx / ALL Form!AG4:AX6',
  'source_sha256','5595f8bb17b2763a11f6139572bfb595c37e4ed4529904014277268e3d2306b8','variance_denominator',8,'is_official_specification',false,'authorizes_lot_release',false);
end;
$$;
create table plantlab_plant.tsw_weight_revisions(
 test_id uuid not null references plantlab_plant.pi_test_contexts(test_id),source_row_version int not null check(source_row_version>0),
 action_id uuid not null unique,weights_g jsonb not null,calculation jsonb not null,
 saved_by uuid not null references plantlab_platform.identities(id),saved_at timestamptz not null default now(),primary key(test_id,source_row_version)
);
create table plantlab_plant.tsw_weight_actions(
 action_id uuid primary key references plantlab_plant.pi_test_events(action_id),test_id uuid not null references plantlab_plant.pi_test_contexts(test_id),
 actor_id uuid not null references plantlab_platform.identities(id),payload_sha256 text not null,response jsonb not null,occurred_at timestamptz not null default now()
);
alter table plantlab_plant.tsw_weight_revisions enable row level security;
alter table plantlab_plant.tsw_weight_actions enable row level security;
revoke all on plantlab_plant.tsw_weight_revisions,plantlab_plant.tsw_weight_actions from PUBLIC,anon,authenticated,service_role;
create trigger tsw_weights_immutable before update or delete on plantlab_plant.tsw_weight_revisions for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger tsw_actions_immutable before update or delete on plantlab_plant.tsw_weight_actions for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_plant.pi_test_tsw_document(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select d||jsonb_build_object('tsw_raw',(select r.calculation||jsonb_build_object('source_row_version',r.source_row_version,'saved_at',r.saved_at)
  from plantlab_plant.tsw_weight_revisions r where r.test_id=p_id order by r.source_row_version desc limit 1))
 from(select plantlab_plant.pi_test_document(p_id)d)x where d is not null;
$$;

alter function plantlab_api.save_pi_test(jsonb) rename to save_pi_test_before_tsw;
create function plantlab_api.save_pi_test(p_document jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb:=p_document;id uuid:=(d->>'id')::uuid;action uuid:=(d->>'action_id')::uuid;lablot plantlab_core.lots;
 old plantlab_plant.tsw_weight_actions;calc jsonb;response jsonb;h text:=encode(sha256(convert_to(d::text,'UTF8')),'hex');has_raw boolean;
begin
 if auth.uid() is null or id is null or action is null or jsonb_typeof(d)<>'object' or octet_length(d::text)>26000 then raise exception 'PI identity and bounded document required' using errcode='22023';end if;
 select l.* into lablot from plantlab_core.lots l where l.id=(d->>'lot_id')::uuid;
 if not found or not plantlab_platform.has_exact_scoped_role('PLANT','PLANT_PI',lablot.plant_site_id,lablot.company_id) then raise exception 'Assigned PI role required in this site' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(action::text,891));
 select * into old from plantlab_plant.tsw_weight_actions where action_id=action;
 if found then
  if old.actor_id<>auth.uid() or old.payload_sha256<>h then raise exception 'Action key reused with different raw readings' using errcode='22023';end if;
  return old.response;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(lablot.id::text,892));
 has_raw:=exists(select from plantlab_plant.tsw_weight_revisions where test_id=id);
 if not(d?'tsw_weights') then
  if has_raw then raise exception 'Raw100-seed readings must be preserved; update client' using errcode='22023';end if;
  return plantlab_api.save_pi_test_before_tsw(d);
 end if;
 if d->>'test_type' is distinct from 'TSW' or (d->'numeric_value' is not null and d->'numeric_value'<>'null'::jsonb) then raise exception 'Raw TSW is calculated on server; do not supply a manual result' using errcode='22023';end if;
 if not has_raw and exists(select from plantlab_plant.pi_test_contexts where test_id=id) then raise exception 'Measurement basis locked after first save' using errcode='22023';end if;
 if exists(select from plantlab_plant.pi_test_events where action_id=action) then raise exception 'Action belongs to another PI operation' using errcode='22023';end if;
 calc:=plantlab_plant.calculate_tsw_weights(d->'tsw_weights');
 if coalesce((d->>'submit')::boolean,false) and calc->>'calculation_state'<>'WITHIN_WORKBOOK_REFERENCE' then raise exception 'Complete and check all8weights; recount when outside workbook reference' using errcode='22023';end if;
 response:=plantlab_api.save_pi_test_before_tsw((d-'tsw_weights')||jsonb_build_object('numeric_value',calc->'tsw_g'));
 insert into plantlab_plant.tsw_weight_revisions values(id,(response->>'row_version')::int,action,d->'tsw_weights',calc,auth.uid(),now());
 response:=plantlab_plant.pi_test_tsw_document(id);
 insert into plantlab_plant.tsw_weight_actions values(action,id,auth.uid(),h,response,now());
 return response;
end;
$$;
alter function plantlab_api.list_pi_tests(int,int) rename to list_pi_tests_before_tsw;
create function plantlab_api.list_pi_tests(p_limit int default 20,p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 result:=plantlab_api.list_pi_tests_before_tsw(p_limit,p_offset);
 return result||jsonb_build_object('records',coalesce((select jsonb_agg(plantlab_plant.pi_test_tsw_document((r->>'id')::uuid) order by n)
 from jsonb_array_elements(result->'records') with ordinality x(r,n)),'[]'::jsonb));
end;
$$;
revoke all on function plantlab_plant.calculate_tsw_weights(jsonb),plantlab_plant.pi_test_tsw_document(uuid),
 plantlab_api.save_pi_test_before_tsw(jsonb),plantlab_api.list_pi_tests_before_tsw(int,int),plantlab_api.save_pi_test(jsonb),plantlab_api.list_pi_tests(int,int)
 from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.save_pi_test(jsonb),plantlab_api.list_pi_tests(int,int) to authenticated;
notify pgrst,'reload schema';
commit;
