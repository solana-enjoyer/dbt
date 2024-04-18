-- depends_on: {{ ref('fact_blast_stablecoin_contracts') }}
-- depends_on: {{ ref('fact_blast_address_balances_by_token') }}
{{ config(materialized="table", snowflake_warehouse="STABLECOIN_LG_2") }}
{{ agg_chain_stablecoin_breakdown("blast", "day") }}
