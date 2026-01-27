-- Hourly time spine table for MetricFlow
-- Provides one row per hour for time-based metric calculations and joins
{{ log("Building hourly time spine table for MetricFlow", info=True) }}

{{ 
    config(
        materialized = 'table',
    ) 
}}

with base_hours as (

    {{
        dbt.date_spine(
            'hour',
            "dateadd(year, -5, current_date())",
            "dateadd(day, 30, current_date())"
        )
    }}

)

select
    cast(date_hour as timestamp) as date_hour
from base_hours
