{% macro fact_daily_uniswap_v2_fork_tvl(token_address, chain, app) %}
    with recursive
        pools as (
            select
                decoded_log:"pair"::string as pool,
                decoded_log:"token0"::string as token0,
                decoded_log:"token1"::string as token1
            from {{ chain }}_flipside.core.ez_decoded_event_logs
            where
                lower(contract_address) = lower('{{ token_address }}')
                and event_name = 'PairCreated'
        ),
        all_pool_events as (
            select
                t1.event_name,
                t2.*,
                t1.tx_hash,
                t1.block_number,
                t1.decoded_log,
                t1.block_timestamp
            from {{ chain }}_flipside.core.ez_decoded_event_logs t1
            inner join pools t2 on lower(t1.contract_address) = lower(t2.pool)
            where t1.event_name in ('Mint', 'Burn', 'Swap')
        ),
        mint_and_burn_and_swap_liquidity as (
            select
                trunc(block_timestamp, 'day') as date,
                tx_hash,
                event_name,
                pool,
                token0,
                case
                    when event_name = 'Burn'
                    then - decoded_log:"amount0"::float
                    when event_name = 'Swap'
                    then
                        decoded_log:"amount0In"::float - decoded_log:"amount0Out"::float
                    else decoded_log:"amount0"::float
                end as token0_amount,
                token1,
                case
                    when event_name = 'Burn'
                    then - decoded_log:"amount1"::float
                    when event_name = 'Swap'
                    then
                        decoded_log:"amount1In"::float - decoded_log:"amount1Out"::float
                    else decoded_log:"amount1"::float
                end as token1_amount
            from all_pool_events
        ),
        adjusted_mint_and_burn_and_swap_liquidity as (
            select
                t1.date,
                t1.tx_hash,
                t1.event_name,
                t1.pool,

                t1.token0,
                t1.token0_amount,
                t2.decimals as token0_decimals,
                t1.token0_amount / pow(10, token0_decimals) as token0_amount_adj,

                t1.token1,
                t1.token1_amount,
                t3.decimals as token1_decimals,
                t1.token1_amount / pow(10, token1_decimals) as token1_amount_adj
            from mint_and_burn_and_swap_liquidity t1
            left join
                {{ chain }}_flipside.core.dim_contracts t2
                on lower(t1.token0) = lower(t2.address)
            left join
                {{ chain }}_flipside.core.dim_contracts t3
                on lower(t1.token1) = lower(t3.address)
            where token0_decimals != 0 and token1_decimals != 0
        ),
        token_changes_per_pool_per_day as (
            select
                date,
                pool,
                token0,
                sum(token0_amount_adj) as token0_amount_per_day,
                token1,
                sum(token1_amount_adj) as token1_amount_per_day
            from adjusted_mint_and_burn_and_swap_liquidity
            group by date, pool, token0, token1
        ),
        min_date as (
            select min(date) as date, pool, token0, token1
            from token_changes_per_pool_per_day
            group by pool, token0, token1
        ),
        date_range as (
            select
                date,
                pool,
                token0,
                0 as token0_amount_per_day,
                token1,
                0 as token1_amount_per_day
            from min_date
            union all
            select
                dateadd(day, 1, date),
                pool,
                token0,
                token0_amount_per_day,
                token1,
                token1_amount_per_day
            from date_range
            where date < to_date(sysdate())
        ),
        token_changes_per_pool_per_day_every_day as (
            select *
            from date_range
            union all
            select *
            from token_changes_per_pool_per_day
        ),
        token_cumulative_per_day_raw as (
            select
                date,
                pool,
                token0,
                sum(token0_amount_per_day) over (
                    partition by pool order by date
                ) as token0_cumulative,
                token1,
                sum(token1_amount_per_day) over (
                    partition by pool order by date
                ) as token1_cumulative
            from token_changes_per_pool_per_day_every_day
        ),
        token_cumulative_per_day as (
            select *
            from token_cumulative_per_day_raw
            group by date, pool, token0, token0_cumulative, token1, token1_cumulative
        ),
        average_token_price_per_day as (
            select trunc(hour, 'day') as date, token_address, avg(price) as price
            from {{ chain }}_flipside.price.ez_hourly_token_prices
            group by date, token_address
        ),
        with_price as (
            select
                t1.date,
                pool,
                token0,
                coalesce(t2.price, 0) as token0_price,
                token0_cumulative,
                token0_cumulative * token0_price as token0_amount_usd,
                token1,
                coalesce(t3.price, 0) as token1_price,
                token1_cumulative,
                token1_cumulative * token1_price as token1_amount_usd
            from token_cumulative_per_day t1
            left join
                average_token_price_per_day t2
                on t1.date = t2.date
                and lower(t1.token0) = lower(t2.token_address)
            left join
                average_token_price_per_day t3
                on t1.date = t3.date
                and lower(t1.token1) = lower(t3.token_address)
        ),
        viable_pools as (
            select date, pool, token0_amount_usd + token1_amount_usd as tvl
            from with_price
            where
                abs(
                    ln(abs(coalesce(nullif(token0_amount_usd, 0), 1))) / ln(10)
                    - ln(abs(coalesce(nullif(token1_amount_usd, 0), 1))) / ln(10)
                )
                < 2
        ),
        tvl_daily_sum as (
            select date, sum(tvl) as tvl
            from viable_pools
            where date is not null
            group by date
        )
    select
        date, '{{ chain }}' as chain, '{{ app }}' as app, 'DeFi' as category, tvl as tvl
    from tvl_daily_sum
    where date is not null

{% endmacro %}
