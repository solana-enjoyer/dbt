{{ 
    config(
        materialized="table",
        snowflake_warehouse="ETHEREUM"
    )
}}

{{distinct_contract_addresses("ethereum")}}