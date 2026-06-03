
with source as (

    select * from {{ source('tpch_now', 'orders') }}

),

rename as (

    select
    
        o_orderkey as order_key,
        o_custkey as customer_key,
        o_orderstatus as status_code,
        {{ order_status_label('o_orderstatus') }} as status_label,
        o_totalprice as total_price,
        o_orderdate as order_date,
        o_ordertime as order_time,
        o_orderpriority as priority_code,
        {{ order_priority_label('o_orderpriority') }} as priority_label,
        {{ is_high_priority_order('o_orderpriority') }} as is_high_priority,
        o_clerk as clerk_name,
        o_shippriority as ship_priority,
        o_comment as comment

    from source

)

select * from rename
