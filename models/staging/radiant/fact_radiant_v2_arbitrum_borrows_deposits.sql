{{ config(materialized="table", snowflake_warehouse="RADIANT") }}
{{
    fact_aave_fork_lending(
        "raw_radiant_v2_arbitrum_borrows_deposits", "arbitrum", "radiant_v2"
    )
}}
