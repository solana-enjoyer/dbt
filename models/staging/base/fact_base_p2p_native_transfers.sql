{{
    config(
        materialized="table",
        unique_key=["tx_hash", "index"],
        snowflake_warehouse="BASE",
    )
}}

{{ p2p_native_transfers("base") }}