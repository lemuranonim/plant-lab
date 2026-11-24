-- Keep the same RPC signature for installed APKs. The former newest-100 subset
-- hid older/paired references after a larger import. Stable order, same scope,
-- bounded 1000 rows and explicit truncation; no change to write authorization.
begin;
set local lock_timeout='3s';
set local statement_timeout='20s';
create or replace function plantlab_api.get_request_options()
returns jsonb language sql stable security definer set search_path='' as $$
  with scoped_lots as materialized (
    select l.id,l.lot_code,l.canonical_lot_code,l.company_id
    from plantlab_core.lots l
    join plantlab_master.sites s on s.id=l.plant_site_id and s.company_id=l.company_id
      and s.site_type='PLANT' and s.is_active
    where auth.uid() is not null
      and plantlab_platform.has_permission('PLANT','request.create',s.id,l.company_id)
  ), lots as (select * from scoped_lots order by lot_code,id limit 1000)
  select jsonb_build_object(
    'lots',coalesce((select jsonb_agg(to_jsonb(l) order by l.lot_code,l.id) from lots l),'[]'::jsonb),
    'lot_count',(select count(*) from scoped_lots),'lot_limit',1000,
    'lots_truncated',(select count(*)>1000 from scoped_lots),
    'lab_sites',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'site_name',s.site_name,'company_id',s.company_id)
      order by s.site_name,s.id) from plantlab_master.sites s where s.site_type='LAB' and s.is_active
      and exists(select from scoped_lots l where l.company_id=s.company_id)),'[]'::jsonb),
    'test_types',coalesce((select jsonb_agg(jsonb_build_object('test_code',t.test_code,'test_name',t.test_name)
      order by t.test_name,t.id) from plantlab_lab.test_types t where t.is_active and exists(select from scoped_lots)),'[]'::jsonb)
  );
$$;
revoke all on function plantlab_api.get_request_options() from PUBLIC,anon,authenticated,service_role;
grant execute on function plantlab_api.get_request_options() to authenticated;
commit;
