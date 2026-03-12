{{ config(
    materialized='incremental',
    unique_key='part_supplier_key'
) }}

with part as (

    select * from {{ ref('stg_parts') }}

),

supplier as (

    select * from {{ ref('stg_suppliers') }}

),

part_supplier as (

    select * from {{ ref('stg_part_suppliers') }}

),

final as (
    select

    part_supplier.part_supplier_key,
    part.part_key,
    part.name as part_name,
    part.manufacturer,
    part.brand,
    part.type as part_type,
    part.size as part_size,
    part.retail_price,

    supplier.supplier_key,
    supplier.supplier_name,
    supplier.supplier_address,
    supplier.phone_number,
    supplier.account_balance,
    supplier.nation_key,

    part_supplier.available_quantity,
    part_supplier.cost,

    -- v2: New calculated fields
    part_supplier.available_quantity * part_supplier.cost as total_inventory_value,
    part.retail_price - part_supplier.cost as supply_margin,
    case
        when part_supplier.available_quantity = 0 then 'Out of Stock'
        when part_supplier.available_quantity < 100 then 'Low Stock'
        when part_supplier.available_quantity < 500 then 'Normal Stock'
        else 'High Stock'
    end as stock_status
from
    part
inner join
    part_supplier
        on part.part_key = part_supplier.part_key
inner join
    supplier
        on part_supplier.supplier_key = supplier.supplier_key
order by
    part.part_key
)

select * from final

{% if is_incremental() %}
    where part_supplier_key not in (select part_supplier_key from {{ this }})
{% endif %}
