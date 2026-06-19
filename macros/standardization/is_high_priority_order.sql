{% macro is_high_priority_order(priority_code) -%}
    case
        when {{ priority_code }} in ('1-URGENT', '2-HIGH') then true
        when {{ priority_code }} is null then null
        else false
    end
{%- endmacro %}
