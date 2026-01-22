{{
  config(
    materialized = 'table',
    catalog_name = 'iceberg_horizon' if target.name == 'prod' else None
  )
}}

with fct_order_items as (
    select * from {{ ref('fct_order_items') }}
),

dim_customers as (
    select * from {{ ref('dim_customers') }}
),

final as (
    select
        dim_customers.customer_key,
        dim_customers.name as customer_name,
        dim_customers.nation,
        dim_customers.region,
        dim_customers.market_segment,
        count(distinct fct_order_items.order_key) as total_orders,
        count(fct_order_items.order_item_key) as total_order_items,
        sum(fct_order_items.gross_item_sales_amount) as total_gross_sales,
        sum(fct_order_items.net_item_sales_amount) as total_net_sales,
        sum(case when fct_order_items.is_return then 1 else 0 end) as total_returns,
        avg(fct_order_items.gross_item_sales_amount) as avg_order_item_value
    from fct_order_items
    inner join dim_customers
        on fct_order_items.customer_key = dim_customers.customer_key
    group by 1, 2, 3, 4, 5
)

select * from final


