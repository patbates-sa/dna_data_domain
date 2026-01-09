{{
    config(
        enabled=true,
        severity='error',
        tags=['designed_to_fail']
    )
}}

select *
from {{ ref('fct_agg_returned_orders_by_month') }}
where order_month = (select max(order_month) from {{ ref('fct_agg_returned_orders_by_month') }})
and return_rate > 0.50 
