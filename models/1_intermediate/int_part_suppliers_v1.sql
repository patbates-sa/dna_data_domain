{{ config(
    materialized='incremental',
    unique_key='part_supplier_key',
    contract={'enforced': true},
    on_schema_change = 'fail'
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
    part.container,
    cast(part.retail_price as number(12, 2)) as retail_price,

    supplier.supplier_key,
    supplier.supplier_name,
    supplier.supplier_address,
    supplier.phone_number,
    cast(supplier.account_balance as number(12, 2)) as account_balance,
    supplier.nation_key,

    part_supplier.available_quantity,
    cast(part_supplier.cost as number(12, 2)) as cost
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
