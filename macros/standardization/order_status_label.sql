{% macro order_status_label(status_code) -%}
    case {{ status_code }}
        when 'O' then 'open'
        when 'F' then 'fulfilled'
        else 'unknown'
    end
{%- endmacro %}
