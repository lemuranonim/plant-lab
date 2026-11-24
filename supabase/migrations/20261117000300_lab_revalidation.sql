-- Manual Revalidation1-3, authorized by a dedicated scoped Lab administrator.
-- No automatic schedule, copied counts, changed specification or lot release.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';

-- The pilot role may already exist from the separately approved assignment.
do $$declare r plantlab_platform.role_definitions;module uuid;begin
 select id into strict module from plantlab_platform.module_registry where module_code='LAB' and is_active;
 select * into r from plantlab_platform.role_definitions where role_code='LAB_REVALIDATION_ADMIN';
 if found then
  if r.module_id<>module or r.permissions<>'["revalidation.authorize"]'::jsonb or not r.is_active then raise exception 'Unexpected Revalidation role definition';end if;
 else insert into plantlab_platform.role_definitions(module_id,role_code,role_name,permissions)values(module,'LAB_REVALIDATION_ADMIN','Admin Revalidation Lab (terbatas)','["revalidation.authorize"]');end if;
end$$;
create table plantlab_lab.revalidation_authorizations (
 id uuid primary key default gen_random_uuid(),lab_site_id uuid not null references plantlab_master.sites(id),
 lot_id uuid not null references plantlab_core.lots(id),method_id uuid not null references plantlab_lab.methods(id),
 root_run_id uuid not null references plantlab_lab.test_runs(id),source_run_id uuid not null references plantlab_lab.test_runs(id),
 stage int not null check(stage between 1 and 3),authorized_by uuid not null references plantlab_platform.identities(id),
 authorizer_name text not null check(length(btrim(authorizer_name)) between 1 and 120),
 reason text not null check(length(btrim(reason)) between 3 and 1000),
 sample_plan text not null check(sample_plan in('RETAINED_LAB','NEW_SAMPLE')),
 sample_evidence text not null check(length(btrim(sample_evidence)) between 3 and 1000),
 source_snapshot jsonb not null,authorized_at timestamptz not null default now()
);
create index revalidation_root_stage_idx on plantlab_lab.revalidation_authorizations(root_run_id,stage);
create index revalidation_lab_time_idx on plantlab_lab.revalidation_authorizations(lab_site_id,authorized_at desc,id);
create table plantlab_lab.revalidation_starts (
 authorization_id uuid primary key references plantlab_lab.revalidation_authorizations(id),
 draft_id uuid not null unique references plantlab_lab.routine_drafts(id),
 started_by uuid not null references plantlab_platform.identities(id),
 sample_reference text not null,available_at timestamptz not null,recorded_at timestamptz not null default now()
);
create table plantlab_lab.revalidation_cancellations (
 authorization_id uuid primary key references plantlab_lab.revalidation_authorizations(id),
 cancelled_by uuid not null references plantlab_platform.identities(id),
 reason text not null check(length(btrim(reason)) between 3 and 1000),recorded_at timestamptz not null default now()
);
create table plantlab_lab.revalidation_actions (
 actor_id uuid not null references plantlab_platform.identities(id),action_id uuid not null,payload jsonb not null,response jsonb not null,
 recorded_at timestamptz not null default now(),primary key(actor_id,action_id)
);
do $$declare n text;begin
 foreach n in array array['revalidation_authorizations','revalidation_starts','revalidation_cancellations','revalidation_actions'] loop
  execute format('alter table plantlab_lab.%I enable row level security',n);
  execute format('revoke all on plantlab_lab.%I from PUBLIC,anon,authenticated,service_role',n);
  execute format('create trigger %I before update or delete on plantlab_lab.%I for each row execute function plantlab_lab.guard_uac_reference_history()',n||'_immutable',n);
 end loop;
end$$;

create function plantlab_lab.can_authorize_revalidation(p_lab uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select from plantlab_master.sites s where s.id=p_lab and s.is_active and s.site_type='LAB'
 and plantlab_platform.has_exact_scoped_role('LAB','LAB_REVALIDATION_ADMIN',s.id,s.company_id));
$$;
create function plantlab_lab.can_read_revalidation(p_lab uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select plantlab_lab.can_authorize_revalidation(p_lab) or plantlab_lab.can_use_routine_lab(p_lab);
$$;
create function plantlab_lab.revalidation_authorizer_active(p_auth uuid)
returns boolean language sql stable set search_path='' as $$
 select exists(select from plantlab_lab.revalidation_authorizations a join plantlab_master.sites s on s.id=a.lab_site_id and s.is_active
 join plantlab_platform.user_role_assignments u on u.user_id=a.authorized_by and u.site_id=s.id and u.company_id=s.company_id
 join plantlab_platform.role_definitions r on r.id=u.role_id and r.role_code='LAB_REVALIDATION_ADMIN' and r.is_active
 join plantlab_platform.module_registry m on m.id=r.module_id and m.module_code='LAB' and m.is_active
 where a.id=p_auth and u.is_active and u.valid_from<=now() and (u.valid_until is null or u.valid_until>now()));
$$;
create function plantlab_lab.revalidation_for_draft(p_draft uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare current_draft uuid:=p_draft;depth int:=0;seen uuid[]:='{}';result jsonb;
begin
 loop
  if depth>100 or current_draft=any(seen) then raise exception 'Draft ancestry requires coordinator review' using errcode='54000';end if;
  seen:=array_append(seen,current_draft);
  select jsonb_build_object('authorization_id',a.id,'stage',a.stage,'root_run_id',a.root_run_id,
  'source_run_id',a.source_run_id,'source_run_code',a.source_snapshot->>'run_code','authorized_at',a.authorized_at,
  'authorized_by',a.authorized_by,'authorizer_name',a.authorizer_name,'reason',a.reason,
  'sample_plan',a.sample_plan,'sample_evidence',a.sample_evidence,'source_sample_reference',a.source_snapshot->>'sample_reference',
  'source_sample_id',a.source_snapshot->'sample_id','sample_recording_basis',case when a.sample_plan='RETAINED_LAB' then 'LAB_ALIQUOT_FROM_RETAINED' else 'NEW_LAB_SAMPLE_CONFIRMED' end,
  'is_qa_retest',depth>0) into result
  from plantlab_lab.revalidation_starts st join plantlab_lab.revalidation_authorizations a on a.id=st.authorization_id
  where st.draft_id=current_draft;
  if found then return result;end if;
  select previous.draft_id into current_draft from plantlab_lab.routine_retest_drafts rt
  join plantlab_lab.routine_submissions previous on previous.test_run_id=rt.previous_run_id where rt.draft_id=current_draft;
  if not found then return null;end if;
  depth:=depth+1;
 end loop;
end
$$;

create function plantlab_lab.revalidation_source(p_run uuid,p_lab uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare r plantlab_lab.test_runs;q plantlab_lab.requests;l plantlab_core.lots;decision plantlab_lab.result_decisions;
 context jsonb;parent uuid;depth int:=0;root uuid:=p_run;stage int:=1;d uuid;method text;
begin
 select run.* into r from plantlab_lab.test_runs run join plantlab_lab.request_items i on i.id=run.request_item_id
 join plantlab_lab.requests req on req.id=i.request_id and req.target_lab_site_id=p_lab
 join plantlab_core.lots lot on lot.id=req.lot_id join plantlab_master.sites lab on lab.id=p_lab and lab.is_active and lab.site_type='LAB' and lab.company_id=lot.company_id
 join plantlab_lab.methods m on m.id=run.method_id and m.is_active
 join plantlab_lab.routine_calculation_contracts contract on contract.method_id=m.id where run.id=p_run;
 if not found then raise exception 'Source outside assigned Lab/active method' using errcode='42501';end if;
 select * into decision from plantlab_lab.result_decisions where test_run_id=r.id order by id desc limit 1;
 if r.status<>'APPROVED' or decision.decision is distinct from 'APPROVE' or decision.resulting_status is distinct from 'APPROVED'
  or r.performed_by is null or decision.reviewer_id=r.performed_by then raise exception 'Approved independent QA source required' using errcode='55000';end if;
 select req.* into strict q from plantlab_lab.requests req join plantlab_lab.request_items i on i.request_id=req.id where i.id=r.request_item_id;
 select * into strict l from plantlab_core.lots where id=q.lot_id;
 select method_code into strict method from plantlab_lab.methods where id=r.method_id;
 parent:=r.id;
 loop
  select draft_id into d from plantlab_lab.routine_submissions where test_run_id=parent;
  if d is not null then context:=plantlab_lab.revalidation_for_draft(d);end if;
  if context is not null then root:=(context->>'root_run_id')::uuid;stage:=(context->>'stage')::int+1;exit;end if;
  root:=parent;select retest_of_id into parent from plantlab_lab.test_runs where id=parent;
  exit when parent is null;depth:=depth+1;if depth>100 then raise exception 'Source ancestry too deep; coordinator review required' using errcode='54000';end if;
 end loop;
 return jsonb_build_object('run_id',r.id,'run_code',r.test_code,'request_id',q.id,'lot_id',l.id,'lot_code',l.lot_code,
  'hybrid',(select name from plantlab_master.products where id=l.product_id),'method_id',r.method_id,'method_code',method,
  'method_name',(select method_name from plantlab_lab.methods where id=r.method_id),'lab_site_id',p_lab,
  'sample_id',r.sample_id,'sample_reference',(select coalesce(nullif(btrim(metadata->>'sample_reference'),''),sample_code) from plantlab_core.samples where id=r.sample_id),
  'qa_decision_id',decision.id,'approved_at',decision.decided_at,'root_run_id',root,'next_stage',stage);
end$$;

create function plantlab_lab.replay_revalidation_action(p_action uuid,p_payload jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare a plantlab_lab.revalidation_actions;
begin
 if p_action is null then raise exception 'Action required' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('REVALIDATION_ACTION:'||auth.uid()||':'||p_action,0));
 select * into a from plantlab_lab.revalidation_actions where actor_id=auth.uid() and action_id=p_action;
 if found then if a.payload is distinct from p_payload then raise exception 'Revalidation retry payload changed' using errcode='23505';end if;return a.response;end if;
 return null;
end$$;

create function plantlab_api.get_lab_revalidation_options(p_lab_site_id uuid,p_search text default '',p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not plantlab_lab.can_read_revalidation(p_lab_site_id) then raise exception 'Assigned Lab scope required' using errcode='42501';end if;
 if coalesce(length(p_search),0)>120 or p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid search/page' using errcode='22023';end if;
 with eligible as materialized(select r.id,r.created_at from plantlab_lab.test_runs r join plantlab_lab.request_items i on i.id=r.request_item_id
  join plantlab_lab.requests q on q.id=i.request_id and q.target_lab_site_id=p_lab_site_id
  join plantlab_core.lots l on l.id=q.lot_id join plantlab_master.products p on p.id=l.product_id
  join plantlab_master.sites lab on lab.id=p_lab_site_id and lab.is_active and lab.company_id=l.company_id
  join plantlab_lab.methods m on m.id=r.method_id and m.is_active join plantlab_lab.routine_calculation_contracts c on c.method_id=m.id
  where r.status='APPROVED' and exists(select from plantlab_lab.result_decisions d where d.test_run_id=r.id and d.decision='APPROVE' and d.resulting_status='APPROVED' and d.reviewer_id<>r.performed_by)
  and (coalesce(btrim(p_search),'')='' or position(lower(btrim(p_search)) in lower(l.lot_code||' '||p.name||' '||r.test_code))>0)),
 page as(select * from eligible order by created_at desc,id limit 50 offset p_offset),
 sources as(select plantlab_lab.revalidation_source(page.id,p_lab_site_id) value,page.created_at from page),
 candidates as(select value||jsonb_build_object('blocked_reason',case when (value->>'next_stage')::int>3 then 'Sumber ini sudah mencapai Revalidation3.'
  when exists(select from plantlab_lab.revalidation_authorizations a where a.root_run_id=(value->>'root_run_id')::uuid and a.stage=(value->>'next_stage')::int and not exists(select from plantlab_lab.revalidation_cancellations c where c.authorization_id=a.id)) then 'Tahap ini sudah memiliki persetujuan. Buka daftar persetujuan.' else null end) value,created_at from sources)
 select jsonb_build_object('lab_site_id',p_lab_site_id,'can_authorize',plantlab_lab.can_authorize_revalidation(p_lab_site_id),
  'can_start',plantlab_lab.can_use_routine_lab(p_lab_site_id,true),'candidates',coalesce((select jsonb_agg(value order by created_at desc,value->>'run_id') from candidates),'[]'::jsonb),
  'total',(select count(*) from eligible),'offset',p_offset,'has_more',(select count(*)>p_offset+50 from eligible)) into result;
 return result;
end$$;

create function plantlab_api.authorize_lab_revalidation(p_lab_site_id uuid,p_source_run_id uuid,p_authorizer_name text,p_reason text,p_sample_plan text,p_sample_evidence text,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare source jsonb;payload jsonb;response jsonb;auth_id uuid;name text:=nullif(btrim(p_authorizer_name),'');reason text:=nullif(btrim(p_reason),'');evidence text:=nullif(btrim(p_sample_evidence),'');
begin
 if not plantlab_lab.can_authorize_revalidation(p_lab_site_id) then raise exception 'Scoped Revalidation administrator required' using errcode='42501';end if;
 if name is null or length(name)>120 or reason is null or length(reason) not between 3 and 1000 or evidence is null or length(evidence) not between 3 and 1000
  or p_sample_plan is null or p_sample_plan not in('RETAINED_LAB','NEW_SAMPLE') then raise exception 'Actual authorizer, reason and physical sample plan/evidence required' using errcode='22023';end if;
 payload:=jsonb_build_object('operation','AUTHORIZE','lab',p_lab_site_id,'source',p_source_run_id,'name',name,'reason',reason,'sample_plan',p_sample_plan,'sample_evidence',evidence);
 response:=plantlab_lab.replay_revalidation_action(p_action_id,payload);if response is not null then return response;end if;
 source:=plantlab_lab.revalidation_source(p_source_run_id,p_lab_site_id);
 perform pg_advisory_xact_lock(hashtextextended('REVALIDATION_ROOT:'||(source->>'root_run_id'),0));
 perform from plantlab_lab.test_runs where id=p_source_run_id for share;
 source:=plantlab_lab.revalidation_source(p_source_run_id,p_lab_site_id);
 if (source->>'next_stage')::int>3 then raise exception 'Maximum Revalidation3 reached' using errcode='55000';end if;
 if exists(select from plantlab_lab.revalidation_authorizations a where a.root_run_id=(source->>'root_run_id')::uuid and a.stage=(source->>'next_stage')::int and not exists(select from plantlab_lab.revalidation_cancellations c where c.authorization_id=a.id)) then
  raise exception 'This stage already authorized; reload' using errcode='55000';end if;
 insert into plantlab_lab.revalidation_authorizations(lab_site_id,lot_id,method_id,root_run_id,source_run_id,stage,authorized_by,authorizer_name,reason,sample_plan,sample_evidence,source_snapshot)
 values(p_lab_site_id,(source->>'lot_id')::uuid,(source->>'method_id')::uuid,(source->>'root_run_id')::uuid,p_source_run_id,(source->>'next_stage')::int,auth.uid(),name,reason,p_sample_plan,evidence,source) returning revalidation_authorizations.id into auth_id;
 response:=jsonb_build_object('authorization_id',auth_id,'stage',source->'next_stage','status','AUTHORIZED');
 insert into plantlab_lab.revalidation_actions(actor_id,action_id,payload,response)values(auth.uid(),p_action_id,payload,response);return response;
end$$;

create function plantlab_api.start_lab_revalidation(p_authorization_id uuid,p_sample_reference text,p_available_at timestamptz,p_replicate_count int,p_sample_confirmed boolean,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a plantlab_lab.revalidation_authorizations;st plantlab_lab.revalidation_starts;method text;content jsonb;rows jsonb;form jsonb;response jsonb;payload jsonb;draft uuid:=gen_random_uuid();reference text:=nullif(btrim(p_sample_reference),'');
begin
 select * into a from plantlab_lab.revalidation_authorizations where id=p_authorization_id;
 if not found or not plantlab_lab.can_use_routine_lab(a.lab_site_id,true) then raise exception 'Assigned Lab Analyst required' using errcode='42501';end if;
 if p_sample_confirmed is distinct from true or reference is null or length(reference)>120 or p_available_at is null or not isfinite(p_available_at) or p_available_at>now() then raise exception 'Confirm actual available sample, label and time first' using errcode='22023';end if;
 select method_code into strict method from plantlab_lab.methods where id=a.method_id and is_active;
 if p_replicate_count is null or not(case when method='SAND_25C' then p_replicate_count in(2,4) when method='RET_16C_72H' then p_replicate_count=4 else p_replicate_count=2 end) then raise exception 'Confirmed replication design required' using errcode='22023';end if;
 payload:=jsonb_build_object('operation','START','authorization_id',a.id,'reference',reference,'available_at',p_available_at,'replicate_count',p_replicate_count,'confirmed',p_sample_confirmed);
 response:=plantlab_lab.replay_revalidation_action(p_action_id,payload);if response is not null then return response;end if;
 select * into strict a from plantlab_lab.revalidation_authorizations where id=p_authorization_id for update;
 if exists(select from plantlab_lab.revalidation_cancellations where authorization_id=a.id) then raise exception 'Authorization cancelled' using errcode='55000';end if;
 select * into st from plantlab_lab.revalidation_starts where authorization_id=a.id;
 if found then raise exception 'Revalidation already has a draft; reload instead of creating a second one' using errcode='55000';end if;
 if not plantlab_lab.revalidation_authorizer_active(a.id) then raise exception 'Authorizer assignment expired/revoked; coordinator review required' using errcode='42501';end if;
 perform plantlab_lab.revalidation_source(a.source_run_id,a.lab_site_id);
 if a.sample_plan='RETAINED_LAB' and reference is distinct from a.source_snapshot->>'sample_reference' then raise exception 'Retained sample must match authorized source label' using errcode='22023';end if;
 if method='RET_16C_72H' then rows:=(select jsonb_agg(jsonb_build_object('radicle_at_least_2mm',null)) from generate_series(1,4));
 else rows:=(select jsonb_agg(jsonb_build_object('first_normal',null,'final_normal',null,'abnormal',null,'fresh',null,'hard',null,'dead',null)) from generate_series(1,p_replicate_count*2));end if;
 content:=jsonb_build_object('replicate_count',p_replicate_count,'sample_reference',reference,'received_at',p_available_at,'started_at',null,'final_at',null,'note',null,'observations',rows);
 if method<>'RET_16C_72H' then
  form:=jsonb_build_object('version',1,'crop_species',null,'analyst_name',null,'temperature_text',case when method='SAND_25C' then '25' else null end,'planted_at',null,'first_count_at',null,
   'annotations',(select jsonb_agg(jsonb_build_object('abnormal_kind',null,'remarks',null)) from jsonb_array_elements(rows)));
  content:=content||jsonb_build_object('form',form);
 end if;
 response:=plantlab_api.save_routine_lab_draft(draft,0,gen_random_uuid(),a.lab_site_id,a.lot_id,method,content);
 insert into plantlab_lab.revalidation_starts(authorization_id,draft_id,started_by,sample_reference,available_at)values(a.id,draft,auth.uid(),reference,p_available_at);
 response:=response||jsonb_build_object('authorization_id',a.id,'stage',a.stage);
 insert into plantlab_lab.revalidation_actions(actor_id,action_id,payload,response)values(auth.uid(),p_action_id,payload,response);return response;
end$$;

create function plantlab_api.cancel_lab_revalidation(p_authorization_id uuid,p_reason text,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a plantlab_lab.revalidation_authorizations;reason text:=nullif(btrim(p_reason),'');payload jsonb;response jsonb;
begin
 select * into a from plantlab_lab.revalidation_authorizations where id=p_authorization_id;
 if not found or not plantlab_lab.can_authorize_revalidation(a.lab_site_id) then raise exception 'Scoped Revalidation administrator required' using errcode='42501';end if;
 if reason is null or length(reason) not between 3 and 1000 then raise exception 'Cancellation reason required' using errcode='22023';end if;
 payload:=jsonb_build_object('operation','CANCEL','authorization_id',a.id,'reason',reason);
 response:=plantlab_lab.replay_revalidation_action(p_action_id,payload);if response is not null then return response;end if;
 perform pg_advisory_xact_lock(hashtextextended('REVALIDATION_ROOT:'||a.root_run_id,0));
 perform from plantlab_lab.revalidation_authorizations where id=a.id for update;
 if exists(select from plantlab_lab.revalidation_starts where authorization_id=a.id) or exists(select from plantlab_lab.revalidation_cancellations where authorization_id=a.id) then raise exception 'Already started/cancelled; reload' using errcode='55000';end if;
 insert into plantlab_lab.revalidation_cancellations(authorization_id,cancelled_by,reason)values(a.id,auth.uid(),reason);
 response:=jsonb_build_object('authorization_id',a.id,'status','CANCELLED');
 insert into plantlab_lab.revalidation_actions(actor_id,action_id,payload,response)values(auth.uid(),p_action_id,payload,response);return response;
end$$;

create function plantlab_api.list_lab_revalidations(p_lab_site_id uuid,p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not plantlab_lab.can_read_revalidation(p_lab_site_id) then raise exception 'Assigned Lab scope required' using errcode='42501';end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid page' using errcode='22023';end if;
 with page as(select a.* from plantlab_lab.revalidation_authorizations a where a.lab_site_id=p_lab_site_id order by authorized_at desc,id limit 50 offset p_offset)
 select jsonb_build_object('authorizations',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'stage',a.stage,'source_run_code',a.source_snapshot->>'run_code','lot_code',a.source_snapshot->>'lot_code',
  'method_code',a.source_snapshot->>'method_code','method_name',a.source_snapshot->>'method_name','sample_reference',a.source_snapshot->>'sample_reference',
  'sample_plan',a.sample_plan,'sample_evidence',a.sample_evidence,'reason',a.reason,'authorizer_name',a.authorizer_name,'authorized_at',a.authorized_at,
  'status',case when c.authorization_id is not null then 'CANCELLED' when st.authorization_id is not null then 'DRAFT_CREATED' else 'AUTHORIZED' end,
  'cancellation_reason',c.reason,'draft_id',st.draft_id,
  'can_start',st.authorization_id is null and c.authorization_id is null and plantlab_lab.can_use_routine_lab(a.lab_site_id,true) and plantlab_lab.revalidation_authorizer_active(a.id),
  'can_cancel',st.authorization_id is null and c.authorization_id is null and plantlab_lab.can_authorize_revalidation(a.lab_site_id)) order by a.authorized_at desc,a.id)
  from page a left join plantlab_lab.revalidation_starts st on st.authorization_id=a.id left join plantlab_lab.revalidation_cancellations c on c.authorization_id=a.id),'[]'::jsonb),
  'total',(select count(*) from plantlab_lab.revalidation_authorizations where lab_site_id=p_lab_site_id),'offset',p_offset,
  'has_more',(select count(*)>p_offset+50 from plantlab_lab.revalidation_authorizations where lab_site_id=p_lab_site_id)) into result;
 return result;
end$$;

-- Immutable authorization provenance follows any QA-requested retest of a
-- Revalidation, but does not turn an ordinary retest into a new Revalidation.
alter function plantlab_lab.routine_draft_readiness(uuid) rename to routine_draft_readiness_before_revalidation;
create function plantlab_lab.routine_draft_readiness(p_draft_id uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare result jsonb;context jsonb;d plantlab_lab.routine_drafts;blockers jsonb:='[]';
begin
 result:=plantlab_lab.routine_draft_readiness_before_revalidation(p_draft_id);context:=plantlab_lab.revalidation_for_draft(p_draft_id);
 if context is null then return result;end if;
 select * into strict d from plantlab_lab.routine_drafts where id=p_draft_id;
 if date_trunc('minute',(d.content->>'started_at')::timestamptz)<date_trunc('minute',(context->>'authorized_at')::timestamptz)
 or date_trunc('minute',(d.content#>>'{form,planted_at}')::timestamptz)<date_trunc('minute',(context->>'authorized_at')::timestamptz) then
  blockers:=blockers||'[{"code":"REVALIDATION_AUTH_TIME","message":"Mulai perlakuan/tanam Revalidation harus setelah persetujuan Admin. Jangan memundurkan tanggal."}]';end if;
 if context->>'sample_plan'='RETAINED_LAB' and d.content->>'sample_reference' is distinct from context->>'source_sample_reference' then
  blockers:=blockers||'[{"code":"REVALIDATION_SAMPLE","message":"Label sampel simpanan harus cocok dengan sumber yang disetujui Admin."}]';end if;
 result:=jsonb_set(result,'{blockers}',(result->'blockers')||blockers);
 return result||jsonb_build_object('ready',jsonb_array_length(result->'blockers')=0,'revalidation',context);
end$$;

-- Extend the allowed cycle kind only. Existing cycles and parent guards remain.
alter table plantlab_lab.test_cycles drop constraint test_cycles_cycle_type_ck;
alter table plantlab_lab.test_cycles add constraint test_cycles_cycle_type_ck check(cycle_type in('INITIAL','RESAMPLE','RETEST','DOUBLE_SAMPLE','RCS','OTHER','REVALIDATION'));
do $$declare definition text;needle text;replacement text;signature text;
begin
 definition:=pg_get_functiondef('plantlab_api.submit_routine_lab_draft(uuid,integer,boolean,uuid)'::regprocedure);
 needle:=$old$case when parent.id is null then 'INITIAL' else 'RETEST' end$old$;
 if strpos(definition,needle)=0 then raise exception 'Unexpected routine cycle kind source';end if;
 definition:=replace(definition,needle,$new$case when parent.id is not null then 'RETEST' when plantlab_lab.revalidation_for_draft(d.id) is not null then 'REVALIDATION' else 'INITIAL' end$new$);
 needle:=$old$jsonb_build_object('routine_draft_id',d.id));$old$;
 if strpos(definition,needle)=0 then raise exception 'Unexpected routine cycle metadata';end if;
 definition:=replace(definition,needle,$new$jsonb_build_object('routine_draft_id',d.id,'revalidation',plantlab_lab.revalidation_for_draft(d.id)));$new$);
 needle:=$old$jsonb_build_object('origin','LAB_ROUTINE','sample_reference',d.content->>'sample_reference','actual_available_at',incoming)$old$;
 if strpos(definition,needle)=0 then raise exception 'Unexpected routine physical sample metadata';end if;
 definition:=replace(definition,needle,$new$jsonb_build_object('origin','LAB_ROUTINE','revalidation',plantlab_lab.revalidation_for_draft(d.id),'sample_reference',d.content->>'sample_reference','actual_available_at',incoming)$new$);
 needle:=$old$'origin','LAB_ROUTINE');$old$;
 if strpos(definition,needle)=0 then raise exception 'Unexpected routine final metadata';end if;
 execute replace(definition,needle,$new$'origin','LAB_ROUTINE','revalidation',plantlab_lab.revalidation_for_draft(d.id));$new$);
 -- Existing scoped record readers gain one derived JSON field. No user may
 -- inject purpose into their editable content or relabel an old source run.
 foreach signature in array array['plantlab_api.get_routine_lab_record(uuid)','plantlab_api.list_routine_lab_drafts(uuid,integer)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  needle:='rt.previous_run_id as retest_of_run_id';
  if strpos(definition,needle)=0 then raise exception 'Unexpected routine reader';end if;
  execute replace(definition,needle,needle||',plantlab_lab.revalidation_for_draft(d.id) as revalidation');
 end loop;
 foreach signature in array array['plantlab_api.get_routine_lab_form_export(uuid,integer)','plantlab_api.get_routine_ret_form_export(uuid,integer)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  if signature like '%get_routine_lab_form%' then
   needle:=$old$'test_purpose',case when result->>'retest_of_run_id' is not null then 'RETEST_VERIFICATION' else 'INITIAL' end$old$;
   replacement:=$new$'test_purpose',case when result->'revalidation' is not null and result->'revalidation'<>'null'::jsonb then 'REVALIDATION_'||(result#>>'{revalidation,stage}') when result->>'retest_of_run_id' is not null then 'RETEST_VERIFICATION' else 'INITIAL' end$new$;
  else
   needle:=$old$'test_purpose',case when d->>'retest_of_run_id' is null then 'INITIAL' else 'RETEST_VERIFICATION' end$old$;
   replacement:=$new$'test_purpose',case when d->'revalidation' is not null and d->'revalidation'<>'null'::jsonb then 'REVALIDATION_'||(d#>>'{revalidation,stage}') when d->>'retest_of_run_id' is null then 'INITIAL' else 'RETEST_VERIFICATION' end$new$;
  end if;
  if strpos(definition,needle)=0 then raise exception 'Unexpected routine form purpose';end if;
  execute replace(definition,needle,replacement);
 end loop;
end$$;

revoke all on function plantlab_lab.can_authorize_revalidation(uuid),plantlab_lab.can_read_revalidation(uuid),plantlab_lab.revalidation_authorizer_active(uuid),
 plantlab_lab.revalidation_for_draft(uuid),plantlab_lab.revalidation_source(uuid,uuid),plantlab_lab.replay_revalidation_action(uuid,jsonb),
 plantlab_lab.routine_draft_readiness_before_revalidation(uuid),plantlab_lab.routine_draft_readiness(uuid),
 plantlab_api.get_lab_revalidation_options(uuid,text,int),plantlab_api.authorize_lab_revalidation(uuid,uuid,text,text,text,text,uuid),
 plantlab_api.start_lab_revalidation(uuid,text,timestamptz,int,boolean,uuid),plantlab_api.cancel_lab_revalidation(uuid,text,uuid),plantlab_api.list_lab_revalidations(uuid,int)
 from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_lab_revalidation_options(uuid,text,int),plantlab_api.authorize_lab_revalidation(uuid,uuid,text,text,text,text,uuid),
 plantlab_api.start_lab_revalidation(uuid,text,timestamptz,int,boolean,uuid),plantlab_api.cancel_lab_revalidation(uuid,text,uuid),plantlab_api.list_lab_revalidations(uuid,int) to authenticated;
notify pgrst,'reload schema';
commit;
