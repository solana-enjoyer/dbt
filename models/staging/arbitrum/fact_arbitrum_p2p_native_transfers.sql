{{
    config(
        materialized="table",
        unique_key=["tx_hash", "index"],
        snowflake_warehouse="ARBITRUM",
    )
}}

{{ p2p_native_transfers("arbitrum") }}