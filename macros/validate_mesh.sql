{% macro validate_mesh(
    products_project=none,
    domain_project=none,
    selected_only=true,
    selected_ids=none,
    require_products_model=false
) %}

    {# Avoid evaluating selected_resources during parse. #}
    {% if not execute %}
        {{ return('') }}
    {% endif %}

    {% set products_project = products_project
        or var('mesh_products_project', 'dna_data_products') %}
    {% set domain_project = domain_project
        or var('mesh_domain_project', 'dna_data_domain') %}

    {#
      selected_ids is useful for tests or explicit run-operation calls.
      In an on-run-start hook, selected_resources is populated by dbt.
    #}
    {% set active_selected_ids = [] %}

    {% if selected_ids is not none %}
        {% set active_selected_ids = selected_ids %}
    {% elif selected_resources is defined %}
        {% set active_selected_ids = selected_resources %}
    {% endif %}

    {% if selected_only and active_selected_ids | length == 0 %}
        {{ exceptions.raise_compiler_error(
            "validate_mesh could not determine selected resources. "
            ~ "Run it from on-run-start or pass selected_ids explicitly."
        ) }}
    {% endif %}

    {% set violations = [] %}
    {% set selected_products_model_count = namespace(value=0) %}

    {% for node_id, node in graph.nodes.items() %}

        {% if node.get('resource_type') == 'model'
              and (
                  not selected_only
                  or node_id in active_selected_ids
              )
        %}

            {% set package_name = node.get('package_name') %}
            {% set config = node.get('config', {}) %}
            {% set contract = node.get('contract', {}) %}
            {% set access = config.get('access', 'protected') %}
            {% set group = config.get('group') %}
            {% set path = (
                node.get('original_file_path')
                or node.get('path')
                or ''
            ) | replace('\\', '/') %}
            {% set path_parts = path.split('/') %}
            {% set layer = namespace(value='') %}
            {% set dependencies = node.get(
                'depends_on', {}
            ).get('nodes', []) %}

            {% for path_part in path_parts %}
                {% if path_part in ['stage', 'int', 'mart'] %}
                    {% set layer.value = path_part %}
                {% endif %}
            {% endfor %}

            {% if package_name == products_project %}

                {% set selected_products_model_count.value =
                    selected_products_model_count.value + 1 %}

                {% if layer.value == '' %}
                    {% do violations.append(
                        node_id
                        ~ ': Gold model path must contain stage, int, or mart'
                    ) %}
                {% endif %}

                {% if layer.value in ['stage', 'int']
                      and access == 'public' %}
                    {% do violations.append(
                        node_id
                        ~ ': Gold stage/int model must not be public'
                    ) %}
                {% endif %}

                {% if layer.value == 'mart'
                      and access != 'public' %}
                    {% do violations.append(
                        node_id
                        ~ ': Gold mart must be public'
                    ) %}
                {% endif %}

                {% for dependency in dependencies %}
                    {% if dependency.startswith('source.') %}
                        {% do violations.append(
                            node_id
                            ~ ': Gold model depends directly on a source'
                        ) %}
                    {% endif %}
                {% endfor %}

                {% if layer.value == 'stage' %}
                    {% for dependency in dependencies %}
                        {% if dependency.startswith('model.')
                              and not dependency.startswith(
                                  'model.' ~ domain_project ~ '.'
                              )
                        %}
                            {% do violations.append(
                                node_id
                                ~ ': Gold stage may depend only on published '
                                ~ domain_project
                                ~ ' models; found '
                                ~ dependency
                            ) %}
                        {% endif %}
                    {% endfor %}
                {% endif %}

                {% if layer.value == 'mart'
                      and access == 'public' %}

                    {% if not group %}
                        {% do violations.append(
                            node_id ~ ': public Gold mart has no group owner'
                        ) %}
                    {% endif %}

                    {% if not contract.get('enforced', false) %}
                        {% do violations.append(
                            node_id
                            ~ ': public Gold mart contract is not enforced'
                        ) %}
                    {% endif %}

                    {% set has_test = namespace(value=false) %}

                    {% for test_id, test_node in graph.nodes.items() %}
                        {% if test_node.get('resource_type') == 'test'
                              and node_id in test_node.get(
                                  'depends_on', {}
                              ).get('nodes', [])
                        %}
                            {% set has_test.value = true %}
                        {% endif %}
                    {% endfor %}

                    {% if not has_test.value %}
                        {% do violations.append(
                            node_id ~ ': public Gold mart has no attached test'
                        ) %}
                    {% endif %}

                {% endif %}

            {% endif %}

            {% if package_name == domain_project
                  and 'mart' in path_parts
                  and access == 'public' %}

                {% if not group %}
                    {% do violations.append(
                        node_id ~ ': public Silver mart has no group owner'
                    ) %}
                {% endif %}

                {% if not contract.get('enforced', false) %}
                    {% do violations.append(
                        node_id
                        ~ ': public Silver mart contract is not enforced'
                    ) %}
                {% endif %}

            {% endif %}

        {% endif %}

    {% endfor %}

    {% if require_products_model
          and selected_products_model_count.value == 0 %}
        {% do violations.append(
            'No selected models found for products project '
            ~ products_project
        ) %}
    {% endif %}

    {% if violations | length > 0 %}

        {% for violation in violations %}
            {{ log('MESH VIOLATION: ' ~ violation, info=true) }}
        {% endfor %}

        {{ exceptions.raise_compiler_error(
            violations | length
            ~ ' dbt Mesh violation(s) found'
        ) }}

    {% else %}

        {{ log(
            'dbt Mesh audit passed for '
            ~ (active_selected_ids | length)
            ~ ' selected resource(s)',
            info=true
        ) }}

    {% endif %}

{% endmacro %}
