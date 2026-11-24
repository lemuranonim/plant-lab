-- Provisional UAC reference only, NOT an approved product specification/release.
-- User instruction 7 Nov 2026: FC and Sweet Corn germ >=90%, vigor >=85%,
-- awaiting Reski. No old result, approval, lot, public or CompFeed row is changed.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '20s';
set local search_path = pg_catalog;

create table plantlab_lab.uac_quality_reference_rules (
  id uuid primary key default gen_random_uuid(),
  crop_category_code text not null references plantlab_master.crop_categories(crop_category_code),
  test_code text not null references plantlab_lab.test_types(test_code),
  version integer not null check (version > 0),
  minimum_percent numeric not null check (minimum_percent between 0 and 100),
  unit_code text not null default 'PERCENT' check (unit_code = 'PERCENT'),
  validation_status text not null default 'PENDING_RESKI' check (validation_status = 'PENDING_RESKI'),
  source_note text not null,
  effective_from timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (crop_category_code, test_code, version),
  unique (crop_category_code, test_code, effective_from)
);
alter table plantlab_lab.uac_quality_reference_rules enable row level security;
revoke all on plantlab_lab.uac_quality_reference_rules from PUBLIC, anon, authenticated, service_role;

comment on table plantlab_lab.uac_quality_reference_rules is
  'Append-only provisional references pending Reski. A new dated version supersedes an old version; never edit the old rule or historical result. Not lab.specifications, not release authority.';

create function plantlab_lab.guard_uac_reference_history()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'Create a new dated UAC reference version; historical rules are immutable'
    using errcode = '55000';
end;
$$;
revoke all on function plantlab_lab.guard_uac_reference_history() from PUBLIC, anon, authenticated, service_role;
create trigger uac_quality_reference_immutable before update or delete
on plantlab_lab.uac_quality_reference_rules for each row
execute function plantlab_lab.guard_uac_reference_history();

insert into plantlab_lab.uac_quality_reference_rules
  (crop_category_code, test_code, version, minimum_percent, source_note)
select crop, test, 1, minimum, 'User-authorized interim FC/SC reference, 2026-11-07; Germ 90%, vigor 85%; waiting for Reski validation. SC is stored as SWC. Not an approved product specification.'
from (values ('FC','GERMINATION',90), ('SWC','GERMINATION',90),
             ('FC','VIGOUR',85), ('SWC','VIGOUR',85)) as rule(crop,test,minimum);

create function plantlab_lab.evaluate_uac_quality_reference(
  p_crop text, p_test text, p_value numeric, p_as_of timestamptz default now()
)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'rule_id', r.id, 'version', r.version, 'crop_category_code', r.crop_category_code,
    'test_code', r.test_code, 'minimum_percent', r.minimum_percent, 'unit_code', r.unit_code,
    'validation_status', r.validation_status, 'effective_from', r.effective_from,
    'assessed_value', p_value,
    'assessment', case when p_value is null then 'NO_RESULT'
      when p_value < 0 or p_value > 100 or p_value::text in ('NaN','Infinity','-Infinity') then 'INVALID_PERCENT'
      when p_value >= r.minimum_percent then 'MEETS_PROVISIONAL_REFERENCE'
      else 'BELOW_PROVISIONAL_REFERENCE' end,
    'is_official_specification', false, 'authorizes_lot_release', false,
    'source_note', r.source_note)
  from plantlab_lab.uac_quality_reference_rules r
  where r.crop_category_code = upper(btrim(p_crop)) and r.test_code = upper(btrim(p_test))
    and r.effective_from <= p_as_of
  order by r.effective_from desc, r.version desc limit 1;
$$;
revoke all on function plantlab_lab.evaluate_uac_quality_reference(text,text,numeric,timestamptz)
  from PUBLIC, anon, authenticated, service_role;

-- Existing authenticated site assignments are required; no new account or role.
create function plantlab_api.get_uac_quality_reference(p_crop text, p_test text, p_value numeric default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists (
    select from plantlab_platform.user_role_assignments a
    join plantlab_platform.role_definitions rd on rd.id=a.role_id and rd.is_active
    join plantlab_platform.module_registry m on m.id=rd.module_id and m.is_active
    where a.user_id=auth.uid() and a.is_active and a.valid_from<=now()
      and (a.valid_until is null or a.valid_until>now())
      and m.module_code in ('PLANT','LAB','PLATFORM')
  ) then
    raise exception 'An active Plant/Lab assignment is required' using errcode='42501';
  end if;
  return plantlab_lab.evaluate_uac_quality_reference(p_crop,p_test,p_value,now());
end;
$$;
revoke all on function plantlab_api.get_uac_quality_reference(text,text,numeric)
  from PUBLIC, anon, authenticated, service_role;
grant execute on function plantlab_api.get_uac_quality_reference(text,text,numeric) to authenticated;

-- Snapshot the server-side reference ONLY when a NEW canonical final event is
-- recorded. Do not retrospectively recalculate the already APPROVED UAC case.
-- Result.result/specification snapshots, QA decisions and lot status stay intact.
create function plantlab_lab.snapshot_uac_quality_reference()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_snapshot jsonb;
begin
  if new.event_type = 'OBSERVED_FINAL' then
    select plantlab_lab.evaluate_uac_quality_reference(l.crop_category_code, tt.test_code, rv.numeric_value, now())
      into v_snapshot
    from plantlab_lab.test_runs tr
    join plantlab_lab.request_items ri on ri.id=tr.request_item_id
    join plantlab_lab.requests r on r.id=ri.request_id
    join plantlab_core.lots l on l.id=r.lot_id
    join plantlab_lab.test_types tt on tt.id=ri.test_type_id
    join plantlab_lab.parameters p on p.parameter_code=case tt.test_code
      when 'GERMINATION' then 'GERMINATION_PERCENT' when 'VIGOUR' then 'VIGOUR_PERCENT' end
    join plantlab_lab.result_values rv on rv.test_run_id=tr.id and rv.parameter_id=p.id
    where tr.id=new.test_run_id;
    -- A caller cannot provide a made-up policy result if no configured match.
    new.metadata := new.metadata - 'uac_quality_reference';
    if v_snapshot is not null then
      new.metadata := new.metadata || jsonb_build_object('uac_quality_reference',v_snapshot);
    end if;
  end if;
  return new;
end;
$$;
revoke all on function plantlab_lab.snapshot_uac_quality_reference() from PUBLIC, anon, authenticated, service_role;
create trigger c_uac_quality_reference_snapshot before insert on plantlab_lab.test_run_events
for each row execute function plantlab_lab.snapshot_uac_quality_reference();
commit;
