{{ config(materialized="table", snowflake_warehouse="AAVE") }}
{{
    fact_aave_fork_lending(
        "raw_aave_v3_optimism_borrows_deposits_revenue", "optimism", "aave_v3"
    )
}}
