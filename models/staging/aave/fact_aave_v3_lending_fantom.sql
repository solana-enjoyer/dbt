{{ config(materialized="table", snowflake_warehouse="AAVE") }}
    fact_aave_fork_lending(
        "raw_aave_v3_fantom_borrows_deposits_revenue", "fantom", "aave_v3"
    )
}}
