-- Business revision conflicts must be HTTP409, not a retriable engine failure.
-- Scope: Lab endpoints/helpers only. No Plant/PI/shared Auth or business rows.
-- Supabase KB: high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b
begin;
set local search_path=pg_catalog;
set local lock_timeout='3s';set local statement_timeout='30s';
do $migration$
declare signature text;definition text;source text;replaced text;
begin
 foreach signature in array array[
 'plantlab_api.check_routine_lab_draft(uuid,integer)',
 'plantlab_api.get_lab_logbook_export(uuid,text,date,date,text,text,text,text)',
 'plantlab_api.get_lab_moisture_draft(uuid,integer)',
 'plantlab_api.get_request_ret_form_export(text,text)',
 'plantlab_api.get_request_seedling_form_export(text,text)',
 'plantlab_api.get_request_seedling_form_export_v2(text,text,integer)',
 'plantlab_api.get_routine_lab_form_export(uuid,integer)',
 'plantlab_api.get_routine_ret_form_export(uuid,integer)',
 'plantlab_api.review_lab_moisture_record(uuid,integer,uuid,uuid,text,text,text)',
 'plantlab_api.review_request_germination_detail(uuid,text,integer,uuid,text,text,text)',
 'plantlab_api.save_lab_moisture_draft(uuid,integer,uuid,uuid,uuid,jsonb)',
 'plantlab_api.save_request_germination_detail(uuid,text,integer,uuid,jsonb)',
 'plantlab_api.save_routine_lab_draft(uuid,integer,uuid,uuid,uuid,text,jsonb)',
 'plantlab_api.start_germination_retest(uuid,text,boolean)',
 'plantlab_api.submit_lab_moisture_record(uuid,integer,uuid)',
 'plantlab_api.submit_request_germination_detail(uuid,text,integer,uuid,boolean)',
 'plantlab_api.submit_routine_lab_draft(uuid,integer,boolean,uuid)',
 'plantlab_lab.request_seedling_legacy_snapshot(text,text)',
 'plantlab_lab.require_current_germination_attempt(uuid,text,text)'] loop
  select prosrc into strict source from pg_proc where oid=signature::regprocedure;
  replaced:=regexp_replace(source,$pattern$(errcode[[:space:]]*=[[:space:]]*)'40001'$pattern$,$replace$\1'PT409'$replace$,'gi');
  if replaced=source or strpos(replaced,'40001')>0 then raise exception 'Unexpected business conflict source: %',signature;end if;
  definition:=pg_get_functiondef(signature::regprocedure);
  execute regexp_replace(definition,$pattern$(errcode[[:space:]]*=[[:space:]]*)'40001'$pattern$,$replace$\1'PT409'$replace$,'gi');
 end loop;
end $migration$;
notify pgrst,'reload schema';
commit;
