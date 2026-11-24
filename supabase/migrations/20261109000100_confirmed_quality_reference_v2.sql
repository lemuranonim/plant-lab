-- User correction 9 Nov: FC/SWC germination >=90%, vigour >=80%.
-- New dated reference only: never rewrite approved observations or release lots.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '20s';
set local search_path = pg_catalog;

-- Keep the legacy validation_status contract for already installed APKs.
-- Business confirmation is distinct from controlled SOP/product validation.
alter table plantlab_lab.uac_quality_reference_rules
  add column business_confirmation_status text not null default 'PENDING'
  check (business_confirmation_status in ('PENDING','USER_CONFIRMED'));

insert into plantlab_lab.uac_quality_reference_rules
  (crop_category_code,test_code,version,minimum_percent,business_confirmation_status,source_note)
select crop,test,2,minimum,'USER_CONFIRMED',
  'Project owner correction 2026-11-09: Germination 90%, vigour 80% for FC/SC. SC is SWC. Supersedes interim 85% for new assessments only. Business reference, not a controlled product specification or lot release authority.'
from (values ('FC','GERMINATION',90),('SWC','GERMINATION',90),
             ('FC','VIGOUR',80),('SWC','VIGOUR',80)) as rule(crop,test,minimum);

comment on table plantlab_lab.uac_quality_reference_rules is
  'Append-only dated business references. USER_CONFIRMED is owner confirmation, not controlled product specification or release authority. Preserve original rules and result snapshots.';

create or replace function plantlab_lab.evaluate_uac_quality_reference(
  p_crop text,p_test text,p_value numeric,p_as_of timestamptz default now()
) returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('rule_id',r.id,'version',r.version,'crop_category_code',r.crop_category_code,
    'test_code',r.test_code,'minimum_percent',r.minimum_percent,'unit_code',r.unit_code,
    'validation_status',r.validation_status,'business_confirmation_status',r.business_confirmation_status,
    'effective_from',r.effective_from,'assessed_value',p_value,
    'assessment',case when p_value is null then 'NO_RESULT'
      when p_value<0 or p_value>100 or p_value::text in ('NaN','Infinity','-Infinity') then 'INVALID_PERCENT'
      when p_value>=r.minimum_percent then 'MEETS_PROVISIONAL_REFERENCE' else 'BELOW_PROVISIONAL_REFERENCE' end,
    'is_official_specification',false,'authorizes_lot_release',false,'source_note',r.source_note)
  from plantlab_lab.uac_quality_reference_rules r
  where r.crop_category_code=upper(btrim(p_crop)) and r.test_code=upper(btrim(p_test)) and r.effective_from<=p_as_of
  order by r.effective_from desc,r.version desc limit 1;
$$;
revoke all on function plantlab_lab.evaluate_uac_quality_reference(text,text,numeric,timestamptz)
  from PUBLIC,anon,authenticated,service_role;
commit;
