-- Dedicated routine RET form, read-only. Existing calculations/reviews are unchanged.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';
create function plantlab_api.get_routine_ret_form_export(p_draft_id uuid,p_expected_revision int)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d jsonb;c plantlab_lab.routine_drafts;w jsonb;decision plantlab_lab.result_decisions;approved boolean:=false;state text;
begin
 d:=plantlab_api.get_routine_lab_record(p_draft_id);
 if p_expected_revision is null or p_expected_revision<1 then raise exception 'Saved revision required' using errcode='22023';end if;
 if (d->>'revision')::int<>p_expected_revision then raise exception 'Saved revision changed; reload before download' using errcode='40001';end if;
 if d->>'method_code'<>'RET_16C_72H' then raise exception 'RET form only; Germination and Vigour forms stay separate' using errcode='22023';end if;
 select * into strict c from plantlab_lab.routine_drafts where id=p_draft_id;
 w:=d->'workflow';state:=coalesce(w->>'status','DRAFT');
 if w->>'run_id' is not null then
  select * into decision from plantlab_lab.result_decisions where test_run_id=(w->>'run_id')::uuid order by id desc limit 1;
  approved:=coalesce(state='APPROVED' and decision.decision='APPROVE' and decision.resulting_status='APPROVED'
   and decision.reviewer_id is distinct from (w->>'analyst_id')::uuid and decision.reviewer_id=(w->>'reviewer_id')::uuid
   and decision.decided_at is not null and w->'summary'->>'calculation_code'='RET_RADICLE_4X100_V1'
   and (w#>>'{summary,within_tolerance}')::boolean is true and (w#>>'{summary,elapsed_requirement_met}')::boolean is true,false);
 end if;
 return d||jsonb_build_object('ret_form_version',1,'read_only',true,'authorizes_lot_release',false,
  'export_status',case when state='APPROVED' and not approved then 'APPROVAL_INCOMPLETE' else state end,
  'qa_approval_verified',approved,'qa_decision',decision.decision,
  'lab_name',(select site_name from plantlab_master.sites where id=c.lab_site_id),
  'crop_category',(select crop_category_code from plantlab_core.lots where id=c.lot_id),
  'test_purpose',case when d->>'retest_of_run_id' is null then 'INITIAL' else 'RETEST_VERIFICATION' end,
  'operator_names_recorded',false,'snapshot_at',statement_timestamp());
end;
$$;
revoke all on function plantlab_api.get_routine_ret_form_export(uuid,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_routine_ret_form_export(uuid,int) to authenticated;
comment on function plantlab_api.get_routine_ret_form_export(uuid,int) is 'Read-only routine RET saved revision, 4x100 radicle>=2mm. Same existing assigned-Lab source read boundary. No changes to calculation, QA, protocol, Auth, assignments or lot release. Operator names are not invented; account IDs remain explicit.';
notify pgrst,'reload schema';
commit;
