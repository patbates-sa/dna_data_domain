{{
  config(
    materialized = "table",
    table_format="iceberg",
    external_volume="ICEBERGEXVOL",
  )
}}

with part as (

    select * from {{ref('stg_tpch_parts')}}

),

final as (
    select 
        part_key,
        manufacturer,
        name,
        brand,
        type,
        size,
        container,
        retail_price
    from
        part
)
select *
from final  
order by part_key