{% macro order_priority_label(priority_code) -%}
    case {{ priority_code }}
        when '1-URGENT' then 'P0'
        when '2-HIGH' then 'P1'
        when '3-MEDIUM' then 'P2'
        when '5-LOW' then 'P4'
        when '4-NOT SPECIFIED' then null
        else null
    end
{%- endmacro %}

