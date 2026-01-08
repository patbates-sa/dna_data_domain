{% test greater_than_or_equal_to_zero(model, column_name) %}

    {{ log("Running greater_than_or_equal_to_zero test on " ~ model ~ "." ~ column_name, info=True) }}

    select *
    from {{ model }}
    where {{ column_name }} < 0

{% endtest %}

