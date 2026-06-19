{% macro standard_account_fields(relation_alias=None) %}

{%- set return_fields = [
    "gross_item_sales_amount",
    "item_discount_amount",
    "item_tax_amount",
    "net_item_sales_amount"
] -%}

{%- for field in return_fields -%}
    {%- if relation_alias -%}{{ relation_alias }}.{%- endif -%}{{ field }}{% if not loop.last %}, {% endif %}
{%- endfor -%}

{% endmacro %}
