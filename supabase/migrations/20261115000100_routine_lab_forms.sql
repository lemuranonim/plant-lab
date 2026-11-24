-- Additive form capture for routine Germination/Vigour. No legacy backfill.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create function plantlab_lab.normalize_routine_form(p_method text,p_content jsonb,p_form jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare k text;v jsonb;result jsonb:='{}';notes jsonb:='[]';r jsonb;t timestamptz;planted timestamptz;first_at timestamptz;n int;
begin
 if p_method='RET_16C_72H' or jsonb_typeof(p_form) is distinct from 'object' or p_form->'version' is distinct from '1'::jsonb
  or octet_length(p_form::text)>14000 then raise exception 'Unsupported form version or method' using errcode='22023';end if;
 if exists(select from jsonb_object_keys(p_form) x where x not in('version','crop_species','analyst_name','temperature_text','planted_at','first_count_at','annotations')) then raise exception 'Unknown form field' using errcode='22023';end if;
 foreach k in array array['crop_species','analyst_name','temperature_text'] loop
  v:=coalesce(p_form->k,'null'::jsonb);
  if v<>'null'::jsonb and (jsonb_typeof(v)<>'string' or length(p_form->>k)>120) then raise exception 'Form text outside limit' using errcode='22023';end if;
  result:=result||jsonb_build_object(k,nullif(btrim(p_form->>k),''));
 end loop;
 if p_method='SAND_25C' and result->>'temperature_text' is not null and result->>'temperature_text'<>'25' then raise exception 'Active Germination protocol is Sand25C, not another temperature' using errcode='22023';end if;
 foreach k in array array['planted_at','first_count_at'] loop
  v:=coalesce(p_form->k,'null'::jsonb);t:=null;
  if v<>'null'::jsonb then
   if jsonb_typeof(v)<>'string' then raise exception 'Actual form timestamp expected' using errcode='22023';end if;
   t:=(p_form->>k)::timestamptz;
   if not isfinite(t) or t>now() then raise exception 'Actual form time cannot be future' using errcode='22023';end if;
  end if;
  if k='planted_at' then planted:=t;else first_at:=t;end if;
  result:=result||jsonb_build_object(k,t);
 end loop;
 if planted<(p_content->>'started_at')::timestamptz or planted>(p_content->>'final_at')::timestamptz
  or first_at<planted or first_at<(p_content->>'started_at')::timestamptz or first_at>(p_content->>'final_at')::timestamptz then
  raise exception 'Form dates outside actual test sequence' using errcode='22023';end if;
 n:=jsonb_array_length(p_content->'observations');
 if jsonb_typeof(p_form->'annotations') is distinct from 'array' or jsonb_array_length(p_form->'annotations')<>n then raise exception 'One form annotation per actual subreplicate required' using errcode='22023';end if;
 for r in select value from jsonb_array_elements(p_form->'annotations') loop
  if jsonb_typeof(r)<>'object' or exists(select from jsonb_object_keys(r) x where x not in('abnormal_kind','remarks')) then raise exception 'Unknown observation note field' using errcode='22023';end if;
  v:='{}';
  foreach k in array array['abnormal_kind','remarks'] loop
   if coalesce(r->k,'null'::jsonb)<>'null'::jsonb and (jsonb_typeof(r->k)<>'string' or length(r->>k)>300) then raise exception 'Observation note outside limit' using errcode='22023';end if;
   v:=v||jsonb_build_object(k,nullif(btrim(r->>k),''));
  end loop;
  notes:=notes||jsonb_build_array(v);
 end loop;
 return result||jsonb_build_object('version',1,'annotations',notes);
end;
$$;

alter function plantlab_lab.normalize_routine_draft(text,jsonb) rename to normalize_routine_draft_before_forms;
create function plantlab_lab.normalize_routine_draft(p_method text,p_content jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare result jsonb;
begin
 if octet_length(p_content::text)>38000 then raise exception 'Draft too large' using errcode='22023';end if;
 result:=plantlab_lab.normalize_routine_draft_before_forms(p_method,p_content-'form');
 if p_content ? 'form' then result:=result||jsonb_build_object('form',plantlab_lab.normalize_routine_form(p_method,result,p_content->'form'));end if;
 return result;
end;
$$;
create function plantlab_lab.guard_routine_form_capture()
returns trigger language plpgsql security definer set search_path='' as $$
declare code text;
begin
 -- Older clients may edit an unsubmitted draft but must not discard new fields.
 if tg_op='UPDATE' and old.content ? 'form' and not(new.content ? 'form') then new.content:=new.content||jsonb_build_object('form',old.content->'form');end if;
 if new.content ? 'form' then
  select method_code into strict code from plantlab_lab.methods where id=new.method_id;
  new.content:=jsonb_set(new.content,'{form}',plantlab_lab.normalize_routine_form(code,new.content,new.content->'form'));
 end if;
 return new;
end;
$$;
create trigger routine_form_capture before insert or update on plantlab_lab.routine_drafts for each row execute function plantlab_lab.guard_routine_form_capture();

create function plantlab_lab.reset_routine_retest_form()
returns trigger language plpgsql security definer set search_path='' as $$
declare f jsonb;d plantlab_lab.routine_drafts;code text;
begin
 select * into strict d from plantlab_lab.routine_drafts where id=new.draft_id;
 if d.content ? 'form' then
  select method_code into strict code from plantlab_lab.methods where id=d.method_id;
  f:=d.content->'form';
  f:=f||jsonb_build_object('analyst_name',null,'planted_at',null,'first_count_at',null,'temperature_text',case when code='SAND_25C' then '25' else null end,
   'annotations',(select jsonb_agg(jsonb_build_object('abnormal_kind',null,'remarks',null)) from jsonb_array_elements(d.content->'observations')));
  update plantlab_lab.routine_drafts set content=jsonb_set(content,'{form}',f) where id=d.id;
 end if;
 return new;
end;
$$;
create trigger routine_retest_form_reset after insert on plantlab_lab.routine_retest_drafts for each row execute function plantlab_lab.reset_routine_retest_form();

alter function plantlab_lab.routine_draft_readiness(uuid) rename to routine_draft_readiness_before_forms;
create function plantlab_lab.routine_draft_readiness(p_draft_id uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare result jsonb;d plantlab_lab.routine_drafts;f jsonb;blockers jsonb:='[]';i int;
begin
 result:=plantlab_lab.routine_draft_readiness_before_forms(p_draft_id);
 select * into strict d from plantlab_lab.routine_drafts where id=p_draft_id;
 if d.content ? 'form' then
  f:=d.content->'form';
  if f->>'crop_species' is null or f->>'analyst_name' is null or f->>'temperature_text' is null or f->>'planted_at' is null then
   blockers:=blockers||'[{"code":"FORM_HEADER","message":"Lengkapi tanaman atau spesies, nama pelaksana, suhu pada form, dan waktu tanam aktual."}]';
  end if;
  if exists(select from jsonb_array_elements(d.content->'observations') r where r->>'first_normal' is not null) and f->>'first_count_at' is null then
   blockers:=blockers||'[{"code":"FIRST_COUNT_TIME","message":"Hitungan first count memerlukan waktu pengamatan aktual. DAP dihitung dari tanggal tanam, bukan mulai perlakuan."}]';
  end if;
  for i in 0..jsonb_array_length(d.content->'observations')-1 loop
   if (d.content->'observations'->i->>'abnormal')::int>0 and f->'annotations'->i->>'abnormal_kind' is null then
    blockers:=blockers||jsonb_build_array(jsonb_build_object('code','ABNORMAL_KIND','message','Isi jenis abnormal pada subulangan '||(i+1)||' sesuai pengamatan.'));
   end if;
  end loop;
 end if;
 result:=jsonb_set(result,'{blockers}',(result->'blockers')||blockers);
 return jsonb_set(result,'{ready}',to_jsonb(jsonb_array_length(result->'blockers')=0));
end;
$$;

create table plantlab_lab.routine_form_reviews (
 run_id uuid primary key references plantlab_lab.test_runs(id),
 reviewer_id uuid not null references plantlab_platform.identities(id),
 reviewer_name text not null check(length(btrim(reviewer_name)) between 2 and 120),
 decision text not null check(decision in('APPROVE','RETEST')),
 action_id uuid not null,
 recorded_at timestamptz not null default now()
);
alter table plantlab_lab.routine_form_reviews enable row level security;
revoke all on plantlab_lab.routine_form_reviews from PUBLIC,anon,authenticated,service_role;
create trigger routine_form_review_immutable before update or delete on plantlab_lab.routine_form_reviews for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_lab.guard_routine_form_review_name()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select from plantlab_lab.routine_submissions s where s.test_run_id=new.test_run_id and s.draft_snapshot->'form'->>'version'='1')
  and not exists(select from plantlab_lab.routine_form_reviews f where f.run_id=new.test_run_id and f.reviewer_id=new.reviewer_id and f.decision=new.decision) then
  raise exception 'New form requires independent QA review with examiner name' using errcode='23514';
 end if;
 return new;
end;
$$;
create trigger routine_form_review_name_guard before insert on plantlab_lab.result_decisions for each row execute function plantlab_lab.guard_routine_form_review_name();

create function plantlab_api.review_routine_lab_form_result(p_run_id uuid,p_decision text,p_reason text,p_protocol_checked boolean,p_action_id uuid,p_reviewer_name text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d plantlab_lab.routine_drafts;r plantlab_lab.test_runs;old plantlab_lab.routine_form_reviews;name text:=nullif(btrim(p_reviewer_name),'');choice text:=upper(btrim(p_decision));result jsonb;
begin
 select draft.* into d from plantlab_lab.routine_submissions s join plantlab_lab.routine_drafts draft on draft.id=s.draft_id where s.test_run_id=p_run_id;
 if not found or not plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',d.lab_site_id,(select company_id from plantlab_core.lots where id=d.lot_id)) then raise exception 'Assigned QA required' using errcode='42501';end if;
 select * into strict r from plantlab_lab.test_runs where id=p_run_id for update;
 if r.performed_by is null or r.performed_by=auth.uid() then raise exception 'Independent QA required' using errcode='42501';end if;
 if name is null or length(name) not between 2 and 120 or p_action_id is null or choice is null or choice not in('APPROVE','RETEST') then raise exception 'Actual examiner name and decision required' using errcode='22023';end if;
 select * into old from plantlab_lab.routine_form_reviews where run_id=p_run_id;
 if found then
  if old.reviewer_id<>auth.uid() or old.action_id<>p_action_id or old.reviewer_name<>name or old.decision<>choice then raise exception 'QA form action replay changed' using errcode='23505';end if;
 else
  if r.status<>'IN_REVIEW' then raise exception 'Run not awaiting QA' using errcode='55000';end if;
  insert into plantlab_lab.routine_form_reviews(run_id,reviewer_id,reviewer_name,decision,action_id) values(p_run_id,auth.uid(),name,choice,p_action_id);
 end if;
 result:=plantlab_api.review_routine_lab_result(p_run_id,choice,p_reason,p_protocol_checked,p_action_id);
 return result||jsonb_build_object('reviewer_name',name);
end;
$$;

create function plantlab_api.get_routine_lab_form_export(p_draft_id uuid,p_expected_revision int)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;d plantlab_lab.routine_drafts;review_name text;
begin
 result:=plantlab_api.get_routine_lab_record(p_draft_id);
 if (result->>'revision')::int is distinct from p_expected_revision then raise exception 'Reload saved revision before exporting' using errcode='40001';end if;
 if result->>'method_code'='RET_16C_72H' then raise exception 'RET requires its own radicle form, not a germination form' using errcode='22023';end if;
 select * into strict d from plantlab_lab.routine_drafts where id=p_draft_id;
 select f.reviewer_name into review_name from plantlab_lab.routine_form_reviews f where f.run_id=(result->'workflow'->>'run_id')::uuid and f.reviewer_id=(result->'workflow'->>'reviewer_id')::uuid;
 return result||jsonb_build_object('form_export_version',1,'lab_name',(select site_name from plantlab_master.sites where id=d.lab_site_id),
  'crop_category',(select crop_category_code from plantlab_core.lots where id=d.lot_id),'reviewer_name',review_name,
  'test_purpose',case when result->>'retest_of_run_id' is not null then 'RETEST_VERIFICATION' else 'INITIAL' end);
end;
$$;

revoke all on function plantlab_lab.normalize_routine_form(text,jsonb,jsonb),plantlab_lab.normalize_routine_draft_before_forms(text,jsonb),
 plantlab_lab.normalize_routine_draft(text,jsonb),plantlab_lab.guard_routine_form_capture(),plantlab_lab.reset_routine_retest_form(),
 plantlab_lab.routine_draft_readiness_before_forms(uuid),plantlab_lab.routine_draft_readiness(uuid),plantlab_lab.guard_routine_form_review_name() from PUBLIC,anon,authenticated,service_role;
revoke all on function plantlab_api.review_routine_lab_form_result(uuid,text,text,boolean,uuid,text),plantlab_api.get_routine_lab_form_export(uuid,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.review_routine_lab_form_result(uuid,text,text,boolean,uuid,text),plantlab_api.get_routine_lab_form_export(uuid,int) to authenticated;
notify pgrst,'reload schema';
commit;
