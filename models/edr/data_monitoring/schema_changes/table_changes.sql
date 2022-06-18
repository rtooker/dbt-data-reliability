{{
  config(
    materialized = 'incremental',
    unique_key = 'change_id'
  )
}}

with cur as (

    select * from {{ ref('current_schema_tables')}}

),

pre as (

    select * from {{ ref('previous_schema_tables')}}

),

table_added as (

    select
        full_table_name,
        'table_added' as change,
        detected_at
    from cur
    where is_new = true

),

table_removed as (

    select
        pre.full_table_name,
        'table_removed' as change,
        pre.detected_at as detected_at
    from pre left join cur
        on (cur.full_table_name = pre.full_table_name and cur.full_schema_name = pre.full_schema_name)
    where cur.full_table_name is null
    and pre.full_schema_name in {{ elementary.get_schemas_for_tests_from_graph_as_tuple() }}

),

all_table_changes as (

    select * from table_removed
    union all
    select * from table_added

),

table_changes_desc as (

    select
        {{ dbt_utils.surrogate_key(['full_table_name', 'change', 'detected_at']) }} as change_id,
        {{ elementary.full_name_split('database_name') }},
        {{ elementary.full_name_split('schema_name') }},
        {{ elementary.full_name_split('table_name') }},
        {{ elementary.run_start_column() }} as detected_at,
        change,
        case
            when change='table_added'
                then 'The table "' || full_table_name || '" was added'
            when change='table_removed'
                then 'The table "' || full_table_name || '" was removed'
            else NULL
        end as change_description
    from all_table_changes

)

select
    {{ elementary.cast_as_string('change_id') }} as change_id,
    {{ elementary.cast_as_string('database_name') }} as database_name,
    {{ elementary.cast_as_string('schema_name') }} as schema_name,
    {{ elementary.cast_as_string('table_name') }} as table_name,
    {{ elementary.cast_as_timestamp('detected_at') }} as detected_at,
    {{ elementary.cast_as_string('change') }} as change,
    {{ elementary.cast_as_long_string('change_description') }} as change_description
from table_changes_desc
{{ dbt_utils.group_by(7) }}