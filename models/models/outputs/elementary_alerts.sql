{{
  config(
    materialized = 'incremental',
    unique_key = 'alert_id'
  )
}}


with tables_for_alerts as (

    select * from {{ ref('config_alerts__tables') }}
    where alert_on_schema_changes = true

),

columns_for_alerts as (

    select * from {{ ref('config_alerts__columns') }}
    where alert_on_schema_changes = true

),

tables_changes as (

    select * from {{ ref('tables_changes_description') }}

),

columns_changes as (

    select * from {{ ref('columns_changes_description') }}

),

alerts_tables_changes as (

    select
        tables_changes.change_id as alert_id,
        tables_changes.detected_at,
        tables_changes.full_table_name,
        'table_schema_change' as alert_type,
        tables_changes.change as alert_reason,
        tables_changes.change_description as alert_reason_value,
        array_construct('change_info') as alert_details_keys,
        array_construct(tables_changes.change_info) as alert_details_values
    from tables_for_alerts as monitored_tables
    inner join tables_changes as tables_changes
        on (monitored_tables.full_table_name = tables_changes.full_table_name)

),

alerts_columns_changes as (

    select
        columns_changes.change_id as alert_id,
        columns_changes.detected_at,
        columns_changes.full_table_name,
        'column_schema_change' as alert_type,
        columns_changes.change as alert_reason,
        columns_changes.change_description as alert_reason_value,
        array_construct('change_info') as alert_details_keys,
        array_construct(columns_changes.change_info) as alert_details_values
    from columns_for_alerts as monitored_columns
    inner join columns_changes
        on (monitored_columns.full_table_name = columns_changes.full_table_name
        and monitored_columns.column_name = columns_changes.column_name)

),

union_alerts as (

    select * from alerts_tables_changes
        union all
    select * from alerts_columns_changes
),

alerts as (

    select
        *,
        {{ dbt_utils.current_timestamp() }} as alert_created_at
    from union_alerts

)

select * from alerts