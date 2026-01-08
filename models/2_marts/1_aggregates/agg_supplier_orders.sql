with fct_order_items as (
    select * from {{ ref('fct_order_items') }}
),

dim_suppliers as (
    select * from {{ ref('dim_suppliers') }}
),

final as (
    select
        dim_suppliers.supplier_key,
        dim_suppliers.supplier_name,
        dim_suppliers.nation,
        dim_suppliers.region,
        count(distinct fct_order_items.order_key) as total_orders,
        count(fct_order_items.order_item_key) as total_order_items,
        sum(fct_order_items.gross_item_sales_amount) as total_gross_sales,
        sum(fct_order_items.net_item_sales_amount) as total_net_sales,
        sum(fct_order_items.supplier_cost * fct_order_items.quantity) as total_supplier_cost,
        sum(fct_order_items.gross_item_sales_amount) - sum(fct_order_items.supplier_cost * fct_order_items.quantity) as gross_margin
    from fct_order_items
    inner join dim_suppliers
        on fct_order_items.supplier_key = dim_suppliers.supplier_key
    group by 1, 2, 3, 4
)

select * from final









