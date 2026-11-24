-- A reference is part of a visible request, not permission to browse both lots.
-- No data, table RLS, role assignment, legacy schema, or shared Auth is changed.
begin;
set local search_path = pg_catalog;
set local lock_timeout = '3s';
set local statement_timeout = '20s';

create or replace function plantlab_api.list_request_lot_pairs(p_request_ids uuid[], p_module text)
returns table (request_id uuid, tested_stage_code text, dss_lot_code text, dcs_lot_code text)
language sql stable security definer set search_path = ''
as $$
  select r.id, tested.stage_code, dss.lot_code, dcs.lot_code
  from plantlab_lab.requests r
  join plantlab_core.lots tested on tested.id = r.lot_id
  join plantlab_core.dss_dcs_pairs pair on
    (tested.stage_code = 'DSS' and pair.dss_lot_id = tested.id)
    or (tested.stage_code = 'DCS' and pair.dcs_lot_id = tested.id)
  join plantlab_core.lots dss on dss.id = pair.dss_lot_id
  join plantlab_core.lots dcs on dcs.id = pair.dcs_lot_id
  where r.id = any(p_request_ids[1:50]) and auth.uid() is not null
    and r.status <> 'DRAFT'
    and dss.company_id = tested.company_id and dcs.company_id = tested.company_id
    and dss.product_id = tested.product_id and dcs.product_id = tested.product_id
    and case upper(btrim(p_module))
      when 'LAB' then plantlab_platform.has_permission('LAB', 'request.read', r.target_lab_site_id, tested.company_id)
      when 'PLANT' then r.source_module = 'PLANT' and r.request_site_id is not null
        and plantlab_platform.has_permission('PLANT', 'request.read', r.request_site_id, tested.company_id)
      else false
    end;
$$;

comment on function plantlab_api.list_request_lot_pairs(uuid[], text) is
  'Only stage and official DSS/DCS reference codes for authorized non-draft requests. Direct lot RLS, import evidence and result access are unchanged; no general counterpart-lot access is granted.';
revoke all on function plantlab_api.list_request_lot_pairs(uuid[], text)
  from PUBLIC, anon, authenticated, service_role;
grant execute on function plantlab_api.list_request_lot_pairs(uuid[], text) to authenticated;
commit;
