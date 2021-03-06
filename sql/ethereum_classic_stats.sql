CREATE MATERIALIZED VIEW ethereum_classic_stats AS (
  WITH
    blocks AS (SELECT
      DATE_TRUNC('day', TO_TIMESTAMP(block."timestamp")) "date",
      5 :: NUMERIC * POWER(0.8 :: NUMERIC, FLOOR((block."number" - 1) / 5000000)) "reward",
      block."number" "number",
      block."difficulty" "difficulty",
      block."size" "size",
      ARRAY_LENGTH(block."transactions", 1) "tx_cnt",
      block."uncles" "uncles"
      FROM ethereum_classic block),
    txs AS (SELECT
      DATE_TRUNC('day', TO_TIMESTAMP(block."timestamp")) "date",
      tx."value" :: NUMERIC * 1e-18 "value",
      tx."gasUsed" :: NUMERIC * tx."gasPrice" :: NUMERIC * 1e-18 "totalGasPrice",
      tx."from" "from",
      tx."to" "to",
      tx."contractAddress" "contractAddress"
      FROM ethereum_classic block, UNNEST(block.transactions) tx),
    blocks_stats AS (SELECT
      block."date" "date",
      AVG(block."difficulty") "avg_difficulty",
      SUM(block."size") / SUM(block."tx_cnt") "avg_tx_size",
      COUNT(*) "cnt",
      SUM(block."size") "sum_size",
      SUM(block."reward") "reward"
      FROM blocks block GROUP BY block."date"),
    uncles_stats AS (SELECT
      block."date" "date",
      SUM(CASE WHEN block."number" <= 5000000 THEN ((uncle."number" - block."number") :: NUMERIC) * 0.125 + 1.03125 ELSE 0.0625 :: NUMERIC END * block."reward") "reward"
      FROM blocks block, UNNEST(block."uncles") uncle GROUP BY block."date"),
    txs_stats AS (SELECT
      tx."date" "date",
      COUNT(*) "cnt",
      SUM(tx."value") "sum_value",
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tx."value") "med_value",
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tx."totalGasPrice") "med_fee",
      SUM(tx."totalGasPrice") "sum_fee",
      COUNT(DISTINCT tx."from") "from_cnt",
      COUNT(DISTINCT tx."to") "to_cnt"
      FROM txs tx GROUP BY tx."date"),
    payments_stats AS (SELECT
      tx."date" "date",
      COUNT(*) "cnt"
      FROM txs tx LEFT JOIN txs contract ON tx."to" = contract."contractAddress"
      WHERE tx."to" IS NOT NULL AND contract."contractAddress" IS NULL
      GROUP BY tx."date"),
    addr_stats AS (SELECT
      t."date" "date",
      COUNT(DISTINCT t."addr") "cnt"
      FROM (
        SELECT
          txs."date" "date",
          txs."from" "addr"
          FROM txs
        UNION ALL
        SELECT
          txs."date" "date",
          txs."to" "addr"
          FROM txs
        ) t
      GROUP BY t."date")
    SELECT
      block."date" "date",
      tx."cnt" "tx_cnt",
      payment."cnt" "payment_cnt",
      tx."sum_value" "sum_value",
      tx."med_value" "med_value",
      block."avg_difficulty" "avg_difficulty",
      block."avg_tx_size" "avg_tx_size",
      tx."sum_fee" "sum_fee",
      block."cnt" "block_cnt",
      block."sum_size" "sum_size",
      tx."med_fee" "med_fee",
      block."reward" + uncle."reward" "reward",
      tx."from_cnt" "from_cnt",
      tx."to_cnt" "to_cnt",
      addr."cnt" "addr_cnt"
    FROM blocks_stats block
    LEFT JOIN uncles_stats uncle ON block."date" = uncle."date"
    LEFT JOIN txs_stats tx ON block."date" = tx."date"
    LEFT JOIN payments_stats payment ON block."date" = payment."date"
    LEFT JOIN addr_stats addr ON block."date" = addr."date"
    ORDER BY "date"
  ) WITH NO DATA;
