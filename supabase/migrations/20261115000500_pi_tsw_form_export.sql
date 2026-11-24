-- Read-only TSW form snapshot. No Auth, assignments, calculation or result writes.
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';
set local statement_timeout='30s';
create function plantlab_api.get_pi_tsw_form_export(p_test_id uuid,p_expected_version int)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d jsonb;c plantlab_plant.pi_test_contexts;t plantlab_plant.tests;l plantlab_core.lots;
begin
 if auth.uid() is null or p_test_id is null then raise exception 'Assigned source access required' using errcode='42501';end if;
 d:=plantlab_plant.pi_test_tsw_document(p_test_id);
 if d is null then raise exception 'Source not available in assigned scope' using errcode='42501';end if;
 if p_expected_version is null or p_expected_version<1 then raise exception 'Saved version required' using errcode='22023';end if;
 if d->>'test_type'<>'TSW' then raise exception 'TSW form only; other forms stay separate' using errcode='22023';end if;
 if (d->>'row_version')::int<>p_expected_version then raise exception 'Source version changed; reload before download' using errcode='40001';end if;
 select * into strict c from plantlab_plant.pi_test_contexts where test_id=p_test_id;
 select * into strict t from plantlab_plant.tests where id=p_test_id;
 select * into strict l from plantlab_core.lots where id=t.lot_id;
 return d||jsonb_build_object('form_export_version',1,'read_only',true,'hybrid',(select name from plantlab_master.products where id=l.product_id),
  'stage_code',l.stage_code,'basis',case when d->'tsw_raw' is null or d->'tsw_raw'='null'::jsonb then 'DIRECT_1000' else 'EIGHT_100' end,
  'reviewed_by',c.reviewed_by,'reviewer_name',null,'reviewer_name_recorded',false,
  'snapshot_note','Sumber PI pada versi tersimpan; bukan approval hasil Lab atau pelepasan lot.',
  'authorizes_lot_release',false);
end;
$$;
revoke all on function plantlab_api.get_pi_tsw_form_export(uuid,int) from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_pi_tsw_form_export(uuid,int) to authenticated;
comment on function plantlab_api.get_pi_tsw_form_export(uuid,int) is 'Read-only current saved source snapshot. Scope exactly follows PI source read permission. Expected context version includes SPV review/evidence changes; raw weight version remains explicit. No fake verifier name or QA approval. One TSW form, no combined MC/PP/Germ/Vigour.';
notify pgrst,'reload schema';
commit;
