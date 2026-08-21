{#
  dbt Hub-and-Spoke Mesh audit.

  Intended execution:
    dbt parse
    dbt run-operation validate_mesh

  The macro validates graph-visible rules. Strict source-text validation of
  version-pinned cross-project ref() syntax should be implemented separately.
#}
{% macro validate_mesh() %}

  {% set products_project = var('mesh_products_project', 'dna_data_products') %}
  {% set domain_project = var('mesh_domain_project', 'dna_data_domain') %}
  {% set violations = [] %}
  {% set products_model_count = namespace(value=0) %}

  {% for node_id, node in graph.nodes.items() %}

    {% if node.get('resource_type') == 'model' %}

      {% set package_name = node.get('package_name') %}
      {% set config = node.get('config', {}) %}
      {% set contract = node.get('contract', {}) %}
      {% set access = config.get('access', 'protected') %}
      {% set group = config.get('group') %}
      {% set path = (node.get('original_file_path') or node.get('path') or '') | replace('\\', '/') %}
      {% set path_parts = path.split('/') %}
      {% set layer = namespace(value='') %}

      {% for path_part in path_parts %}
        {% if path_part in ['stage', 'int', 'mart'] %}
          {% set layer.value = path_part %}
        {% endif %}
      {% endfor %}

      {% set dependencies = node.get('depends_on', {}).get('nodes', []) %}

      {# Validate Gold/product models. #}
      {% if package_name == products_project %}

        {% set products_model_count.value = products_model_count.value + 1 %}

        {% if layer.value == '' %}
          {% do violations.append(
            node.get('name') ~ ': Gold model path must contain stage, int, or mart'
          ) %}
        {% endif %}

        {% if layer.value in ['stage', 'int'] and access == 'public' %}
          {% do violations.append(
            node.get('name') ~ ': Gold stage/int model must not be public'
          ) %}
        {% endif %}

        {% if layer.value == 'mart' and access != 'public' %}
          {% do violations.append(
            node.get('name') ~ ': Gold mart must be public'
          ) %}
        {% endif %}

        {# Gold models must never depend directly on source() nodes. #}
        {% for dependency in dependencies %}
          {% if dependency.startswith('source.') %}
            {% do violations.append(
              node.get('name') ~ ': Gold model depends directly on a source'
            ) %}
          {% endif %}
        {% endfor %}

        {# Gold stage may depend only on published Silver/domain models. #}
        {% if layer.value == 'stage' %}
          {% for dependency in dependencies %}
            {% if dependency.startswith('model.')
                  and not dependency.startswith('model.' ~ domain_project ~ '.') %}
              {% do violations.append(
                node.get('name') ~ ': Gold stage may depend only on published '
                ~ domain_project ~ ' models; found ' ~ dependency
              ) %}
            {% endif %}
          {% endfor %}
        {% endif %}

        {# Public Gold marts require group ownership, contracts, and tests. #}
        {% if layer.value == 'mart' and access == 'public' %}

          {% if not group %}
            {% do violations.append(
              node.get('name') ~ ': public Gold mart has no group owner'
            ) %}
          {% endif %}

          {% if not contract.get('enforced', false) %}
            {% do violations.append(
              node.get('name') ~ ': public Gold mart contract is not enforced'
            ) %}
          {% endif %}

          {% set has_test = namespace(value=false) %}
          {% for test_id, test_node in graph.nodes.items() %}
            {% if test_node.get('resource_type') == 'test'
                  and node_id in test_node.get('depends_on', {}).get('nodes', []) %}
              {% set has_test.value = true %}
            {% endif %}
          {% endfor %}

          {% if not has_test.value %}
            {% do violations.append(
              node.get('name') ~ ': public Gold mart has no attached test'
            ) %}
          {% endif %}

        {% endif %}

      {% endif %}

      {# Validate published Silver/domain marts when they are present in graph. #}
      {% if package_name == domain_project and 'mart' in path_parts and access == 'public' %}

        {% if not group %}
          {% do violations.append(
            node.get('name') ~ ': public Silver mart has no group owner'
          ) %}
        {% endif %}

        {% if not contract.get('enforced', false) %}
          {% do violations.append(
            node.get('name') ~ ': public Silver mart contract is not enforced'
          ) %}
        {% endif %}

      {% endif %}

    {% endif %}

  {% endfor %}

  {% if products_model_count.value == 0 %}
    {% do violations.append(
      'No models found for products project ' ~ products_project
      ~ '; verify mesh_products_project'
    ) %}
  {% endif %}

  {% if violations | length > 0 %}
    {% for violation in violations %}
      {{ log('MESH VIOLATION: ' ~ violation, info=True) }}
    {% endfor %}

    {{ exceptions.raise_compiler_error(
      violations | length ~ ' dbt Mesh violation(s) found'
    ) }}
  {% else %}
    {{ log('dbt Mesh audit passed', info=True) }}
  {% endif %}

{% endmacro %}
