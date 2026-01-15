-- Macro to prevent COMMON_ schema prefix from being added to Bronze, Silver and Gold schemas
{% macro generate_schema_name(custom_schema_name, node) %}
  {{ custom_schema_name }}
{% endmacro %}