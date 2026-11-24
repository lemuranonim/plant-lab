-- Owner decision 17Nov2026: independent QA verifies the MC record only.
-- No tolerance, pass/fail, canonical quality result, Plant value or lot release.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';

create table plantlab_lab.moisture_submissions (
 id uuid primary key default gen_random_uuid(),
 draft_id uuid not null,
 revision int not null,
 submitted_by uuid not null references plantlab_platform.identities(id),
 submitted_at timestamptz not null default now(),
 content jsonb not null check(jsonb_typeof(content)='object'),
 mean_percent numeric not null check(mean_percent between 0 and 100),
 foreign key(draft_id,revision) references plantlab_lab.moisture_draft_revisions(draft_id,revision),
 unique(draft_id,revision)
);
create table plantlab_lab.moisture_record_reviews (
 submission_id uuid primary key references plantlab_lab.moisture_submissions(id),
 decision text not null check(decision in('VERIFY_RECORD','RETURN')),
 reviewer_id uuid not null references plantlab_platform.identities(id),
 reviewer_name text not null check(length(btrim(reviewer_name)) between 1 and 120),
 note text check(length(note)<=1000),
 reviewed_at timestamptz not null default now(),
 check(decision<>'RETURN' or coalesce(length(btrim(note)),0)>0)
);
create table plantlab_lab.moisture_workflow_actions (
 actor_id uuid not null references plantlab_platform.identities(id),
 action_id uuid not null,payload jsonb not null,response jsonb not null,
 recorded_at timestamptz not null default now(),primary key(actor_id,action_id)
);
alter table plantlab_lab.moisture_submissions enable row level security;
alter table plantlab_lab.moisture_record_reviews enable row level security;
alter table plantlab_lab.moisture_workflow_actions enable row level security;
revoke all on plantlab_lab.moisture_submissions,plantlab_lab.moisture_record_reviews,
 plantlab_lab.moisture_workflow_actions from PUBLIC,anon,authenticated,service_role;
create trigger moisture_submissions_immutable before update or delete on plantlab_lab.moisture_submissions
 for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger moisture_reviews_immutable before update or delete on plantlab_lab.moisture_record_reviews
 for each row execute function plantlab_lab.guard_uac_reference_history();
create trigger moisture_actions_immutable before update or delete on plantlab_lab.moisture_workflow_actions
 for each row execute function plantlab_lab.guard_uac_reference_history();

create function plantlab_lab.moisture_record_ready(p_content jsonb)
returns boolean language sql immutable set search_path='' as $$
 select not exists(select from unnest(array['sample_reference','sample_type','received_at',
  'measured_at','analyst_name','instrument','method']) k where nullif(btrim(p_content->>k),'') is null)
 and jsonb_typeof(p_content->'readings')='array' and jsonb_array_length(p_content->'readings')=3
 and not exists(select from jsonb_array_elements(p_content->'readings') v where jsonb_typeof(v)<>'number');
$$;

create function plantlab_lab.guard_submitted_moisture()
returns trigger language plpgsql set search_path='' as $$
begin
 -- Also blocks the already-installed old save RPC. No alternate mutable path.
 if exists(select from plantlab_lab.moisture_submissions s
   left join plantlab_lab.moisture_record_reviews r on r.submission_id=s.id
   where s.draft_id=old.id and coalesce(r.decision,'IN_REVIEW')<>'RETURN') then
  raise exception 'Submitted MC record is locked; reload its review status' using errcode='55000';
 end if;
 return new;
end;$$;
create trigger moisture_submitted_draft_lock before update or delete on plantlab_lab.moisture_drafts
 for each row execute function plantlab_lab.guard_submitted_moisture();

create or replace function plantlab_lab.moisture_draft_json(p_id uuid)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',d.id,'lab_site_id',d.lab_site_id,'lot_id',d.lot_id,
  'lot_code',l.lot_code,'stage_code',l.stage_code,'hybrid',p.name,'lab_name',s.site_name,
  'created_by',d.created_by,'revision',d.revision,'content',d.content,'updated_at',d.updated_at,
  'status',case when sub.revision is distinct from d.revision then 'DRAFT'
    when rev.decision='VERIFY_RECORD' then 'VERIFIED_RECORD' when rev.decision='RETURN' then 'RETURNED' else 'IN_REVIEW' end,
  'can_edit',d.created_by=auth.uid() and plantlab_lab.can_use_routine_lab(d.lab_site_id,true)
    and (sub.id is null or coalesce(rev.decision='RETURN',false)),
  'can_submit',d.created_by=auth.uid() and plantlab_lab.can_use_routine_lab(d.lab_site_id,true)
    and (sub.id is null or (coalesce(rev.decision='RETURN',false) and d.revision>sub.revision))
    and plantlab_lab.moisture_record_ready(d.content),
  'can_review',coalesce(sub.revision=d.revision,false) and rev.submission_id is null
    and sub.submitted_by<>auth.uid() and d.created_by<>auth.uid()
    and plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',d.lab_site_id,s.company_id),
  'submission_id',sub.id,'submitted_revision',sub.revision,'submitted_at',sub.submitted_at,
  'review',case when rev.submission_id is null then null else jsonb_build_object(
    'decision',rev.decision,'reviewer_id',rev.reviewer_id,'reviewer_name',rev.reviewer_name,
    'note',rev.note,'reviewed_at',rev.reviewed_at,'revision',sub.revision) end,
  'entered_count',(select count(*) from jsonb_array_elements(d.content->'readings') v where v<>'null'::jsonb),
  'mean_percent',case when not exists(select from jsonb_array_elements(d.content->'readings') v where v='null'::jsonb)
    then (select avg((v::text)::numeric) from jsonb_array_elements(d.content->'readings') v) else null end,
  'authorizes_lot_release',false,'qa_enabled',false,'record_review_enabled',true)
 from plantlab_lab.moisture_drafts d join plantlab_core.lots l on l.id=d.lot_id
 join plantlab_master.products p on p.id=l.product_id join plantlab_master.sites s on s.id=d.lab_site_id
 left join lateral(select x.* from plantlab_lab.moisture_submissions x where x.draft_id=d.id order by x.revision desc limit 1)sub on true
 left join plantlab_lab.moisture_record_reviews rev on rev.submission_id=sub.id
 where d.id=p_id;
$$;

create function plantlab_api.submit_lab_moisture_record(p_draft_id uuid,p_expected_revision int,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d plantlab_lab.moisture_drafts;prior plantlab_lab.moisture_submissions;
 a plantlab_lab.moisture_workflow_actions;payload jsonb;response jsonb;sid uuid;average numeric;
begin
 select * into d from plantlab_lab.moisture_drafts where id=p_draft_id;
 if not found or d.created_by<>auth.uid() or not plantlab_lab.can_use_routine_lab(d.lab_site_id,true)
  or not exists(select from plantlab_core.lots l join plantlab_master.sites lab on lab.id=d.lab_site_id and lab.company_id=l.company_id where l.id=d.lot_id) then
  raise exception 'Original assigned MC analyst required' using errcode='42501';end if;
 if p_expected_revision is null or p_expected_revision<1 or p_action_id is null then raise exception 'Saved revision/action required' using errcode='22023';end if;
 payload:=jsonb_build_object('operation','SUBMIT','draft_id',p_draft_id,'revision',p_expected_revision);
 perform pg_advisory_xact_lock(hashtextextended('MC_ACTION:'||auth.uid()||':'||p_action_id,0));
 select * into a from plantlab_lab.moisture_workflow_actions where actor_id=auth.uid() and action_id=p_action_id;
 if found then
  if a.payload is distinct from payload then raise exception 'MC action payload changed' using errcode='23505';end if;
  return a.response;
 end if;
 select * into strict d from plantlab_lab.moisture_drafts where id=p_draft_id for update;
 if d.revision<>p_expected_revision then raise exception 'MC revision changed; reload' using errcode='40001';end if;
 if not plantlab_lab.moisture_record_ready(d.content) then raise exception 'Complete actual sample, dates, staff, instrument/method and3 readings first' using errcode='22023';end if;
 -- Normalization rechecks physical chronology and finite numeric percentages.
 perform plantlab_lab.normalize_moisture_draft(d.content);
 select * into prior from plantlab_lab.moisture_submissions where draft_id=d.id order by revision desc limit 1;
 if found and (prior.revision>=d.revision or not exists(select from plantlab_lab.moisture_record_reviews r where r.submission_id=prior.id and r.decision='RETURN')) then
  raise exception 'MC already submitted; reload' using errcode='55000';end if;
 select avg((v::text)::numeric) into average from jsonb_array_elements(d.content->'readings') v;
 insert into plantlab_lab.moisture_submissions(draft_id,revision,submitted_by,content,mean_percent)
 values(d.id,d.revision,auth.uid(),d.content,average) returning id into sid;
 response:=jsonb_build_object('draft_id',d.id,'revision',d.revision,'submission_id',sid,'status','IN_REVIEW','authorizes_lot_release',false);
 insert into plantlab_lab.moisture_workflow_actions(actor_id,action_id,payload,response) values(auth.uid(),p_action_id,payload,response);
 return response;
end;$$;

create function plantlab_api.review_lab_moisture_record(p_draft_id uuid,p_expected_revision int,p_submission_id uuid,
 p_action_id uuid,p_decision text,p_reviewer_name text,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d plantlab_lab.moisture_drafts;sub plantlab_lab.moisture_submissions;
 a plantlab_lab.moisture_workflow_actions;payload jsonb;response jsonb;
 name text:=nullif(btrim(p_reviewer_name),'');note text:=nullif(btrim(p_note),'');
begin
 select * into d from plantlab_lab.moisture_drafts where id=p_draft_id;
 if not found or auth.uid() is null or not exists(select from plantlab_master.sites s
  join plantlab_core.lots l on l.id=d.lot_id and l.company_id=s.company_id where s.id=d.lab_site_id and s.is_active
  and plantlab_platform.has_exact_scoped_role('LAB','LAB_QA_APPROVER',s.id,s.company_id)) then
  raise exception 'Assigned MC Lab QA required' using errcode='42501';end if;
 if d.created_by=auth.uid() then raise exception 'Independent MC reviewer required' using errcode='42501';end if;
 if p_action_id is null or p_expected_revision is null or p_expected_revision<1 or p_submission_id is null
  or p_decision is null or p_decision not in('VERIFY_RECORD','RETURN') or name is null or length(name)>120
  or coalesce(length(note),0)>1000 or (p_decision='RETURN' and note is null) then
  raise exception 'Record-only decision, actual reviewer name and return reason required' using errcode='22023';end if;
 payload:=jsonb_build_object('operation','REVIEW','draft_id',p_draft_id,'revision',p_expected_revision,
  'submission_id',p_submission_id,'decision',p_decision,'reviewer_name',name,'note',note);
 perform pg_advisory_xact_lock(hashtextextended('MC_ACTION:'||auth.uid()||':'||p_action_id,0));
 select * into a from plantlab_lab.moisture_workflow_actions where actor_id=auth.uid() and action_id=p_action_id;
 if found then
  if a.payload is distinct from payload then raise exception 'MC action payload changed' using errcode='23505';end if;
  return a.response;
 end if;
 select * into strict d from plantlab_lab.moisture_drafts where id=p_draft_id for update;
 select * into sub from plantlab_lab.moisture_submissions where id=p_submission_id and draft_id=d.id and revision=p_expected_revision;
 if not found or d.revision<>p_expected_revision or exists(select from plantlab_lab.moisture_submissions s where s.draft_id=d.id and s.revision>p_expected_revision) then
  raise exception 'Submitted MC revision changed; reload' using errcode='40001';end if;
 if sub.submitted_by=auth.uid() then raise exception 'Independent MC reviewer required' using errcode='42501';end if;
 if exists(select from plantlab_lab.moisture_record_reviews r where r.submission_id=sub.id) then raise exception 'MC already reviewed; reload' using errcode='55000';end if;
 if d.content is distinct from sub.content then raise exception 'MC snapshot mismatch' using errcode='55000';end if;
 insert into plantlab_lab.moisture_record_reviews(submission_id,decision,reviewer_id,reviewer_name,note)
 values(sub.id,p_decision,auth.uid(),name,note);
 response:=jsonb_build_object('draft_id',d.id,'revision',d.revision,'submission_id',sub.id,
  'status',case when p_decision='VERIFY_RECORD' then 'VERIFIED_RECORD' else 'RETURNED' end,'authorizes_lot_release',false);
 insert into plantlab_lab.moisture_workflow_actions(actor_id,action_id,payload,response) values(auth.uid(),p_action_id,payload,response);
 return response;
end;$$;

revoke all on function plantlab_lab.moisture_record_ready(jsonb),plantlab_lab.guard_submitted_moisture(),
 plantlab_api.submit_lab_moisture_record(uuid,int,uuid),
 plantlab_api.review_lab_moisture_record(uuid,int,uuid,uuid,text,text,text) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.submit_lab_moisture_record(uuid,int,uuid),
 plantlab_api.review_lab_moisture_record(uuid,int,uuid,uuid,text,text,text) to authenticated;
comment on table plantlab_lab.moisture_record_reviews is 'Independent QA record verification only. VERIFY_RECORD is not quality pass/fail, a tolerance assessment, canonical result approval, or lot release.';

-- Preserve the existing Plant/routine query and its filters; change only the MC
-- branch to carry the record-review state. Never count verified MC as APPROVED.
do $migration$
declare source text;needle text;replacement text;
begin
 source:=pg_get_functiondef('plantlab_lab.logbook_entries(uuid)'::regprocedure);
 needle:=$old$select 'MC_DRAFT',d.id,null,null,l.id,l.lot_code,l.hybrid,l.stage_code,'MC_LAB','MC Lab','DRAFT',d.content->>'sample_reference',d.created_at,
   (d.content->>'measured_at')::timestamptz,null,
   case when not exists(select from jsonb_array_elements(d.content->'readings') v where v='null'::jsonb) then (select avg((v::text)::numeric) from jsonb_array_elements(d.content->'readings') v) else null end,
   'DRAFT_MEAN',d.revision,null,'DRAFT'
  from plantlab_lab.moisture_drafts d join lots l on l.id=d.lot_id where d.lab_site_id=p_lab_site_id$old$;
 replacement:=$new$select 'MC_DRAFT',d.id,null,null,l.id,l.lot_code,l.hybrid,l.stage_code,'MC_LAB','MC Lab',mc.value->>'status',d.content->>'sample_reference',d.created_at,
   (d.content->>'measured_at')::timestamptz,
   case when (mc.value#>>'{review,revision}')::int=d.revision then (mc.value#>>'{review,reviewed_at}')::timestamptz else null end,
   (mc.value->>'mean_percent')::numeric,
   case when mc.value->>'status'='DRAFT' then 'DRAFT_MEAN' else 'MC_RECORD_MEAN' end,d.revision,null,mc.value->>'status'
  from plantlab_lab.moisture_drafts d join lots l on l.id=d.lot_id
  cross join lateral(select plantlab_lab.moisture_draft_json(d.id) value)mc where d.lab_site_id=p_lab_site_id$new$;
 if (length(source)-length(replace(source,needle,'')))/length(needle)<>1 then raise exception 'Unexpected existing MC logbook branch';end if;
 execute replace(source,needle,replacement);
 source:=pg_get_functiondef('plantlab_api.get_lab_logbook(uuid,text,date,date,text,text,text,text,integer,integer)'::regprocedure);
 needle:=$old$'CANCELLED','APPROVAL_INCOMPLETE')$old$;
 replacement:=$new$'CANCELLED','APPROVAL_INCOMPLETE','VERIFIED_RECORD','RETURNED')$new$;
 if (length(source)-length(replace(source,needle,'')))/length(needle)<>1 then raise exception 'Unexpected existing logbook status guard';end if;
 execute replace(source,needle,replacement);
end;
$migration$;
notify pgrst,'reload schema';
commit;
