{% macro simulate_query_traffic(database_name=target.database, schema_name=target.schema) %}
  {% set models = [
    'stg_tpch_orders',
    'stg_tpch_customers',
    'stg_tpch_line_items',
    'stg_tpch_nations',
    'stg_tpch_parts',
    'stg_tpch_part_suppliers',
    'stg_tpch_regions',
    'stg_tpch_suppliers',
    'int_customer_flags',
    'int_customer_tier',
    'int_order_items',
    'int_part_suppliers',
    'fct_order_items',
    'fct_orders',
    'fct_agg_customer_orders',
    'fct_agg_monthly_gross_revenue',
    'fct_agg_returned_orders_by_month',
    'fct_agg_supplier_orders',
    'dim_customers_v1',
    'dim_customers_v2',
    'dim_parts',
    'dim_suppliers'
  ] %}

  {# Disable cached results #}
  {% set disable_cache_sql = "ALTER SESSION SET USE_CACHED_RESULT = FALSE" %}
  {% do run_query(disable_cache_sql) %}
  
  {# Set query tag #}
  {% set query_tag_sql = "ALTER SESSION SET QUERY_TAG = 'dbt_demo_simulate_query_traffic'" %}
  {% do run_query(query_tag_sql) %}

  {% set query_count = namespace(value=0) %}
  
  {% for model_name in models %}
    {# Random hits between 10 and 20 for each model #}
    {% set hits = range(10, 21) | list | random %}
    
    {% for i in range(hits) %}
      {# Random offset between 0 and 1000 #}
      {% set random_offset = range(0, 1001) | list | random %}
      
      {% set query_sql %}
        SELECT * 
        FROM "{{ database_name }}"."{{ schema_name }}".{{ model_name }} 
        ORDER BY 1 
        LIMIT 10 
        OFFSET {{ random_offset }}
      {% endset %}
      
      {% do run_query(query_sql) %}
      {% set query_count.value = query_count.value + 1 %}
    {% endfor %}
    
  {% endfor %}

  {% do log("Simulated query traffic complete. Executed " ~ query_count.value ~ " SELECTs.", info=True) %}
  
  {{ return("Simulated query traffic complete. Executed " ~ query_count.value ~ " SELECTs.") }}

{% endmacro %}

