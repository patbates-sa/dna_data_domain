-- Daily time spine table for MetricFlow
-- Provides one row per day for time-based metric calculations and joins
-- Span is from 5 years ago to 30 days from today, as defined in the time_spine_hourly model
{{ log("Building daily time spine table for MetricFlow", info=True) }}

{{ 
    config(
        materialized = 'table',
    ) 
}}

select distinct
    cast(date_hour as date) as date_day
from {{ ref('time_spine_hourly') }}
