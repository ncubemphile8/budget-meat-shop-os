-- BudgetOS initial schema (PostgreSQL / Supabase-compatible)
-- This is a deployment blueprint. The demo frontend does not connect to this schema.
-- Apply only in a new, secured database after reviewing with Budget Meat Shop management.
begin;

create extension if not exists pgcrypto;

do $$ begin
  create type public.staff_role as enum ('owner','group_manager','branch_manager','stock_controller','cashier','dispatch','accountant','viewer');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.stock_unit as enum ('kg','g','pack','piece','crate','tray','unit');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.order_status as enum ('received','payment_review','confirmed','preparing','packed','ready_for_dispatch','out_for_delivery','delivered','completed','cancelled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.payment_status as enum ('awaiting_payment','review','paid','partially_refunded','refunded','failed');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.delivery_status as enum ('awaiting_assignment','assigned','preparing','out_for_delivery','delivered','failed','returned');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.stock_movement_type as enum ('receipt','sale','waste','adjustment','transfer_out','transfer_in','return','production_input','production_output');
exception when duplicate_object then null; end $$;

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  address text,
  phone text,
  opening_hours jsonb not null default '{}'::jsonb,
  delivery_enabled boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.branches(slug,name,address) values
 ('fort-street','Fort Street','122 Fort Street, between 11th & 12th Avenue, Bulawayo'),
 ('leopold-takawira','Leopold Takawira Street','Shop 2, between Herbert Chitepo & Lobengula Street, Bulawayo'),
 ('lobengula-street','Lobengula Street','44 Lobengula Street, between 2nd & 3rd Avenue, Bulawayo')
on conflict (slug) do nothing;

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.staff_role not null default 'viewer',
  branch_id uuid references public.branches(id),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint group_role_no_branch check (role not in ('owner','group_manager','accountant') or branch_id is null)
);

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique,
  name text not null,
  category_id uuid references public.product_categories(id),
  sell_unit public.stock_unit not null default 'kg',
  variable_weight boolean not null default true,
  default_unit_price numeric(12,4) not null check (default_unit_price >= 0),
  reorder_default numeric(14,3) not null default 0 check (reorder_default >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_name text,
  phone text,
  email text,
  address text,
  payment_terms text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory_batches (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  product_id uuid not null references public.products(id),
  supplier_id uuid references public.suppliers(id),
  batch_code text not null,
  received_at timestamptz not null default now(),
  expires_on date,
  unit public.stock_unit not null,
  received_qty numeric(14,3) not null check (received_qty >= 0),
  on_hand_qty numeric(14,3) not null check (on_hand_qty >= 0),
  unit_cost numeric(12,4) not null check (unit_cost >= 0),
  unit_price numeric(12,4) not null check (unit_price >= 0),
  status text not null default 'available' check (status in ('available','quarantined','expired','depleted')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique(branch_id,product_id,batch_code)
);

create index if not exists inventory_batches_branch_product_idx on public.inventory_batches(branch_id,product_id);
create index if not exists inventory_batches_expiry_idx on public.inventory_batches(expires_on) where on_hand_qty > 0;

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  product_id uuid not null references public.products(id),
  batch_id uuid references public.inventory_batches(id),
  movement_type public.stock_movement_type not null,
  unit public.stock_unit not null,
  quantity numeric(14,3) not null check (quantity > 0),
  direction smallint not null check (direction in (-1,1)),
  from_branch_id uuid references public.branches(id),
  to_branch_id uuid references public.branches(id),
  reason text not null,
  reference_type text,
  reference_id uuid,
  unit_cost numeric(12,4) check (unit_cost is null or unit_cost >= 0),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (from_branch_id is null or to_branch_id is null or from_branch_id <> to_branch_id)
);
create index if not exists stock_movements_branch_date_idx on public.stock_movements(branch_id,created_at desc);
create index if not exists stock_movements_product_date_idx on public.stock_movements(product_id,created_at desc);

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  po_number text not null unique,
  supplier_id uuid not null references public.suppliers(id),
  branch_id uuid not null references public.branches(id),
  status text not null default 'draft' check (status in ('draft','submitted','partially_received','received','cancelled')),
  expected_on date,
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  notes text,
  created_by uuid references auth.users(id),
  received_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  ordered_qty numeric(14,3) not null check (ordered_qty > 0),
  received_qty numeric(14,3) not null default 0 check (received_qty >= 0),
  unit public.stock_unit not null,
  unit_cost numeric(12,4) not null check (unit_cost >= 0),
  line_total numeric(14,2) generated always as (round(ordered_qty * unit_cost,2)) stored,
  check (received_qty <= ordered_qty)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  phone text,
  email text,
  delivery_address text,
  marketing_consent_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  branch_id uuid not null references public.branches(id),
  customer_id uuid references public.customers(id),
  source text not null default 'in_store' check (source in ('in_store','online','whatsapp','phone','wholesale')),
  status public.order_status not null default 'received',
  payment_status public.payment_status not null default 'awaiting_payment',
  currency char(3) not null default 'USD',
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount_total numeric(14,2) not null default 0 check (discount_total >= 0),
  delivery_fee numeric(14,2) not null default 0 check (delivery_fee >= 0),
  total numeric(14,2) not null default 0 check (total >= 0),
  customer_name_snapshot text,
  customer_phone_snapshot text,
  delivery_address_snapshot text,
  requested_delivery_window tstzrange,
  notes text,
  created_by uuid references auth.users(id),
  packed_by uuid references auth.users(id),
  packed_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists sales_orders_branch_created_idx on public.sales_orders(branch_id,created_at desc);
create index if not exists sales_orders_status_created_idx on public.sales_orders(status,created_at desc);

create table if not exists public.sales_order_items (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null references public.sales_orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  batch_id uuid references public.inventory_batches(id),
  ordered_qty numeric(14,3) not null check (ordered_qty > 0),
  packed_qty numeric(14,3) check (packed_qty is null or packed_qty > 0),
  unit public.stock_unit not null,
  unit_price numeric(12,4) not null check (unit_price >= 0),
  unit_cost_snapshot numeric(12,4) not null check (unit_cost_snapshot >= 0),
  line_discount numeric(14,2) not null default 0 check (line_discount >= 0),
  line_total numeric(14,2) not null check (line_total >= 0),
  created_at timestamptz not null default now()
);
create index if not exists sales_order_items_order_idx on public.sales_order_items(sales_order_id);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null references public.sales_orders(id),
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null default 'USD',
  method text not null check (method in ('cash','mobile_money','card','bank_transfer','other')),
  provider text,
  provider_reference text,
  status text not null default 'pending' check (status in ('pending','review','confirmed','failed','refunded','partially_refunded')),
  received_by uuid references auth.users(id),
  reconciled_by uuid references auth.users(id),
  reconciled_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists payments_order_idx on public.payments(sales_order_id,created_at desc);

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  delivery_number text not null unique,
  sales_order_id uuid not null unique references public.sales_orders(id),
  branch_id uuid not null references public.branches(id),
  status public.delivery_status not null default 'awaiting_assignment',
  driver_user_id uuid references auth.users(id),
  driver_name_snapshot text,
  delivery_address text not null,
  delivery_area text,
  delivery_window tstzrange,
  delivery_fee numeric(14,2) not null default 0 check (delivery_fee >= 0),
  assigned_at timestamptz,
  dispatched_at timestamptz,
  delivered_at timestamptz,
  failed_at timestamptz,
  failure_reason text,
  proof_of_delivery_url text,
  external_courier text,
  external_tracking_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists deliveries_branch_status_idx on public.deliveries(branch_id,status,created_at desc);
create index if not exists deliveries_driver_idx on public.deliveries(driver_user_id,status);

create table if not exists public.delivery_events (
  id uuid primary key default gen_random_uuid(),
  delivery_id uuid not null references public.deliveries(id) on delete cascade,
  status public.delivery_status not null,
  event_note text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  recorded_by uuid references auth.users(id),
  recorded_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  category text not null,
  description text not null,
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null default 'USD',
  payment_method text,
  reference_number text,
  receipt_url text,
  incurred_on date not null default current_date,
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists expenses_branch_date_idx on public.expenses(branch_id,incurred_on desc);

create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  promo_code text unique,
  description text,
  discount_type text not null check (discount_type in ('percent','fixed_amount','delivery_waiver','bundle')),
  discount_value numeric(12,4) not null default 0 check (discount_value >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  status text not null default 'draft' check (status in ('draft','scheduled','active','paused','expired')),
  redemptions_count bigint not null default 0 check (redemptions_count >= 0),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  category text not null check (category in ('stock','expiry','payment','delivery','variance','operations','security')),
  severity text not null check (severity in ('low','medium','high','critical')),
  title text not null,
  detail text not null,
  related_table text,
  related_id uuid,
  status text not null default 'open' check (status in ('open','acknowledged','resolved')),
  acknowledged_by uuid references auth.users(id),
  acknowledged_at timestamptz,
  resolved_by uuid references auth.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists alerts_status_severity_idx on public.alerts(status,severity,created_at desc);
create index if not exists alerts_branch_status_idx on public.alerts(branch_id,status);

create table if not exists public.audit_log (
  id bigserial primary key,
  actor_user_id uuid references auth.users(id),
  action text not null,
  entity_table text not null,
  entity_id uuid,
  branch_id uuid references public.branches(id),
  before_data jsonb,
  after_data jsonb,
  request_id text,
  created_at timestamptz not null default now()
);
create index if not exists audit_log_branch_date_idx on public.audit_log(branch_id,created_at desc);

-- Auth helper functions use the authenticated JWT and a definer context to avoid
-- recursive RLS lookups against user_profiles. Review permissions before go-live.
create or replace function public.current_staff_role()
returns public.staff_role language sql stable security definer set search_path=public
as $$
  select role from public.user_profiles where user_id=auth.uid() and active=true
$$;

create or replace function public.can_access_branch(target_branch uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.user_profiles p
    where p.user_id=auth.uid() and p.active=true
      and (p.role in ('owner','group_manager','accountant') or p.branch_id=target_branch)
  )
$$;

create or replace function public.has_any_role(allowed public.staff_role[])
returns boolean language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.user_profiles p
    where p.user_id=auth.uid() and p.active=true and p.role=any(allowed)
  )
$$;

alter table public.branches enable row level security;
alter table public.user_profiles enable row level security;
alter table public.product_categories enable row level security;
alter table public.products enable row level security;
alter table public.suppliers enable row level security;
alter table public.inventory_batches enable row level security;
alter table public.stock_movements enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;
alter table public.customers enable row level security;
alter table public.sales_orders enable row level security;
alter table public.sales_order_items enable row level security;
alter table public.payments enable row level security;
alter table public.deliveries enable row level security;
alter table public.delivery_events enable row level security;
alter table public.expenses enable row level security;
alter table public.promotions enable row level security;
alter table public.alerts enable row level security;
alter table public.audit_log enable row level security;

-- Read only branch records needed for labels and branch selection.
drop policy if exists "staff read active branches" on public.branches;
create policy "staff read active branches" on public.branches for select to authenticated using (
  active=true and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller','cashier','dispatch','accountant','viewer']::public.staff_role[])
);
drop policy if exists "group managers maintain branches" on public.branches;
create policy "group managers maintain branches" on public.branches for all to authenticated using (
  public.has_any_role(array['owner','group_manager']::public.staff_role[])
) with check (public.has_any_role(array['owner','group_manager']::public.staff_role[]));

drop policy if exists "staff read own profile" on public.user_profiles;
create policy "staff read own profile" on public.user_profiles for select to authenticated using (
  user_id=auth.uid() or public.has_any_role(array['owner','group_manager']::public.staff_role[])
);
drop policy if exists "management maintains profiles" on public.user_profiles;
create policy "management maintains profiles" on public.user_profiles for all to authenticated using (
  public.has_any_role(array['owner','group_manager']::public.staff_role[])
) with check (public.has_any_role(array['owner','group_manager']::public.staff_role[]));

drop policy if exists "authenticated read categories" on public.product_categories;
create policy "authenticated read categories" on public.product_categories for select to authenticated using (true);
drop policy if exists "management maintains categories" on public.product_categories;
create policy "management maintains categories" on public.product_categories for all to authenticated using (
  public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[])
) with check (public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[]));

drop policy if exists "staff read active products" on public.products;
create policy "staff read active products" on public.products for select to authenticated using (active=true);
drop policy if exists "authorised staff maintain products" on public.products;
create policy "authorised staff maintain products" on public.products for all to authenticated using (
  public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[])
) with check (public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[]));

drop policy if exists "staff read suppliers" on public.suppliers;
create policy "staff read suppliers" on public.suppliers for select to authenticated using (
  public.has_any_role(array['owner','group_manager','branch_manager','stock_controller','accountant']::public.staff_role[])
);
drop policy if exists "purchasing roles maintain suppliers" on public.suppliers;
create policy "purchasing roles maintain suppliers" on public.suppliers for all to authenticated using (
  public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[])
) with check (public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[]));

drop policy if exists "branch staff read inventory" on public.inventory_batches;
create policy "branch staff read inventory" on public.inventory_batches for select to authenticated using (public.can_access_branch(branch_id));
drop policy if exists "stock roles manage inventory" on public.inventory_batches;
create policy "stock roles manage inventory" on public.inventory_batches for all to authenticated using (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[])
) with check (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[])
);

drop policy if exists "branch staff read stock movements" on public.stock_movements;
create policy "branch staff read stock movements" on public.stock_movements for select to authenticated using (public.can_access_branch(branch_id));
drop policy if exists "stock roles write movements" on public.stock_movements;
create policy "stock roles write movements" on public.stock_movements for insert to authenticated with check (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller','cashier']::public.staff_role[])
);

drop policy if exists "branch users read purchase orders" on public.purchase_orders;
create policy "branch users read purchase orders" on public.purchase_orders for select to authenticated using (public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller','accountant']::public.staff_role[]));
drop policy if exists "purchasing roles write purchase orders" on public.purchase_orders;
create policy "purchasing roles write purchase orders" on public.purchase_orders for all to authenticated using (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[])
) with check (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[])
);
drop policy if exists "purchase line access via parent order" on public.purchase_order_lines;
create policy "purchase line access via parent order" on public.purchase_order_lines for all to authenticated using (
  exists(select 1 from public.purchase_orders p where p.id=purchase_order_id and public.can_access_branch(p.branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller','accountant']::public.staff_role[]))
) with check (
  exists(select 1 from public.purchase_orders p where p.id=purchase_order_id and public.can_access_branch(p.branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','stock_controller']::public.staff_role[]))
);

drop policy if exists "customer data branch scope via orders" on public.customers;
create policy "customer data branch scope via orders" on public.customers for select to authenticated using (
  public.has_any_role(array['owner','group_manager','accountant']::public.staff_role[]) or exists(
    select 1 from public.sales_orders o where o.customer_id=customers.id and public.can_access_branch(o.branch_id)
  )
);
drop policy if exists "authorised staff create customer" on public.customers;
create policy "authorised staff create customer" on public.customers for insert to authenticated with check (
  public.has_any_role(array['owner','group_manager','branch_manager','cashier','dispatch']::public.staff_role[])
);

drop policy if exists "branch staff read orders" on public.sales_orders;
create policy "branch staff read orders" on public.sales_orders for select to authenticated using (public.can_access_branch(branch_id));
drop policy if exists "sales roles manage orders" on public.sales_orders;
create policy "sales roles manage orders" on public.sales_orders for all to authenticated using (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','cashier','dispatch']::public.staff_role[])
) with check (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','cashier','dispatch']::public.staff_role[])
);

drop policy if exists "order item access via order" on public.sales_order_items;
create policy "order item access via order" on public.sales_order_items for select to authenticated using (
  exists(select 1 from public.sales_orders o where o.id=sales_order_id and public.can_access_branch(o.branch_id))
);
drop policy if exists "sales roles manage order items" on public.sales_order_items;
create policy "sales roles manage order items" on public.sales_order_items for all to authenticated using (
  exists(select 1 from public.sales_orders o where o.id=sales_order_id and public.can_access_branch(o.branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','cashier']::public.staff_role[]))
) with check (
  exists(select 1 from public.sales_orders o where o.id=sales_order_id and public.can_access_branch(o.branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','cashier']::public.staff_role[]))
);

drop policy if exists "finance roles read payments" on public.payments;
create policy "finance roles read payments" on public.payments for select to authenticated using (
  exists(select 1 from public.sales_orders o where o.id=sales_order_id and public.can_access_branch(o.branch_id)) and public.has_any_role(array['owner','group_manager','branch_manager','cashier','accountant']::public.staff_role[])
);
drop policy if exists "payment roles manage payments" on public.payments;
create policy "payment roles manage payments" on public.payments for all to authenticated using (
  exists(select 1 from public.sales_orders o where o.id=sales_order_id and public.can_access_branch(o.branch_id)) and public.has_any_role(array['owner','group_manager','branch_manager','cashier','accountant']::public.staff_role[])
) with check (
  exists(select 1 from public.sales_orders o where o.id=sales_order_id and public.can_access_branch(o.branch_id)) and public.has_any_role(array['owner','group_manager','branch_manager','cashier','accountant']::public.staff_role[])
);

drop policy if exists "delivery staff read deliveries" on public.deliveries;
create policy "delivery staff read deliveries" on public.deliveries for select to authenticated using (public.can_access_branch(branch_id));
drop policy if exists "dispatch roles maintain deliveries" on public.deliveries;
create policy "dispatch roles maintain deliveries" on public.deliveries for all to authenticated using (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','dispatch']::public.staff_role[])
) with check (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','dispatch']::public.staff_role[])
);
drop policy if exists "delivery events accessible by branch" on public.delivery_events;
create policy "delivery events accessible by branch" on public.delivery_events for all to authenticated using (
  exists(select 1 from public.deliveries d where d.id=delivery_id and public.can_access_branch(d.branch_id))
) with check (
  exists(select 1 from public.deliveries d where d.id=delivery_id and public.can_access_branch(d.branch_id))
);

drop policy if exists "finance roles read expenses" on public.expenses;
create policy "finance roles read expenses" on public.expenses for select to authenticated using (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','accountant']::public.staff_role[])
);
drop policy if exists "authorised roles write expenses" on public.expenses;
create policy "authorised roles write expenses" on public.expenses for insert to authenticated with check (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','branch_manager','accountant']::public.staff_role[])
);
drop policy if exists "management update expenses" on public.expenses;
create policy "management update expenses" on public.expenses for update to authenticated using (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','accountant']::public.staff_role[])
) with check (
  public.can_access_branch(branch_id) and public.has_any_role(array['owner','group_manager','accountant']::public.staff_role[])
);

drop policy if exists "staff read promotions" on public.promotions;
create policy "staff read promotions" on public.promotions for select to authenticated using (public.has_any_role(array['owner','group_manager','branch_manager','cashier','accountant','viewer']::public.staff_role[]));
drop policy if exists "management manages promotions" on public.promotions;
create policy "management manages promotions" on public.promotions for all to authenticated using (
  public.has_any_role(array['owner','group_manager','branch_manager']::public.staff_role[])
) with check (public.has_any_role(array['owner','group_manager','branch_manager']::public.staff_role[]));

drop policy if exists "staff read branch alerts" on public.alerts;
create policy "staff read branch alerts" on public.alerts for select to authenticated using (
  branch_id is null and public.has_any_role(array['owner','group_manager','accountant']::public.staff_role[]) or public.can_access_branch(branch_id)
);
drop policy if exists "staff acknowledge accessible alerts" on public.alerts;
create policy "staff acknowledge accessible alerts" on public.alerts for update to authenticated using (
  (branch_id is null and public.has_any_role(array['owner','group_manager']::public.staff_role[])) or public.can_access_branch(branch_id)
) with check (
  (branch_id is null and public.has_any_role(array['owner','group_manager']::public.staff_role[])) or public.can_access_branch(branch_id)
);

drop policy if exists "management reads audit log" on public.audit_log;
create policy "management reads audit log" on public.audit_log for select to authenticated using (
  public.has_any_role(array['owner','group_manager','accountant']::public.staff_role[]) and (branch_id is null or public.can_access_branch(branch_id))
);
drop policy if exists "authenticated may append audit log" on public.audit_log;
create policy "authenticated may append audit log" on public.audit_log for insert to authenticated with check (
  actor_user_id=auth.uid() and (branch_id is null or public.can_access_branch(branch_id))
);

grant usage on schema public to authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
grant usage,select on sequence public.audit_log_id_seq to authenticated;
grant execute on function public.current_staff_role() to authenticated;
grant execute on function public.can_access_branch(uuid) to authenticated;
grant execute on function public.has_any_role(public.staff_role[]) to authenticated;

commit;
