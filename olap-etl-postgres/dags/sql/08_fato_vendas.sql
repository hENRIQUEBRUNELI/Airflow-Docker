-- fato_vendas: carga incremental por ModifiedDate (header ou detail).
-- Resolve as surrogate keys via JOIN com as dimensões e calcula as métricas.
WITH base AS (
    SELECT
        soh.salesorderid                 AS nk_pedido,
        sod.salesorderdetailid           AS nk_detalhe,
        dt.sk_tempo, dp.sk_produto, dc.sk_cliente,
        dv.sk_vendedor, dter.sk_territorio, dpr.sk_promocao,
        sod.orderqty                     AS quantidade,
        sod.unitprice                    AS preco_unitario,
        sod.unitpricediscount            AS desconto_unitario,
        prod.standardcost                AS custo_padrao,
        (sod.orderqty * sod.unitprice)                                   AS receita_bruta,
        (sod.orderqty * sod.unitprice * (1 - sod.unitpricediscount))     AS receita_liquida,
        (sod.orderqty * prod.standardcost)                               AS custo_total,
        soh.freight AS freight, soh.taxamt AS taxamt, soh.subtotal AS subtotal,
        GREATEST(soh.modifieddate, sod.modifieddate)                     AS modified_date
    FROM oltp.salesorderheader soh
    JOIN oltp.salesorderdetail sod ON soh.salesorderid = sod.salesorderid
    JOIN oltp.product         prod ON sod.productid    = prod.productid
    JOIN dim_tempo   dt   ON dt.data_completa = soh.orderdate::date
    JOIN dim_produto dp   ON dp.nk_produto    = sod.productid  AND dp.registro_atual = TRUE
    JOIN dim_cliente dc   ON dc.nk_cliente    = soh.customerid AND dc.registro_atual = TRUE
    LEFT JOIN dim_vendedor   dv   ON dv.nk_vendedor   = soh.salespersonid AND dv.registro_atual = TRUE
    LEFT JOIN dim_territorio dter ON dter.nk_territorio = soh.territoryid
    LEFT JOIN dim_promocao   dpr  ON dpr.nk_promocao    = sod.specialofferid
    WHERE GREATEST(soh.modifieddate, sod.modifieddate) >
          (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='fato_vendas')
)
INSERT INTO fato_vendas (nk_pedido, nk_detalhe, sk_tempo, sk_produto, sk_cliente,
                         sk_vendedor, sk_territorio, sk_promocao,
                         quantidade, preco_unitario, desconto_unitario, custo_padrao,
                         receita_bruta, receita_liquida, custo_total, lucro_bruto,
                         margem_percentual, frete_rateado, imposto_rateado, data_atualizacao)
SELECT nk_pedido, nk_detalhe, sk_tempo, sk_produto, sk_cliente,
       sk_vendedor, sk_territorio, sk_promocao,
       quantidade, preco_unitario, desconto_unitario, custo_padrao,
       receita_bruta, receita_liquida, custo_total,
       (receita_liquida - custo_total)                                   AS lucro_bruto,
       CASE WHEN receita_liquida > 0
            THEN (receita_liquida - custo_total) / receita_liquida ELSE 0 END AS margem_percentual,
       freight / NULLIF(subtotal,0) * receita_liquida                    AS frete_rateado,
       taxamt  / NULLIF(subtotal,0) * receita_liquida                    AS imposto_rateado,
       now()
FROM base
ON CONFLICT (nk_detalhe) DO UPDATE
   SET quantidade        = excluded.quantidade,
       preco_unitario    = excluded.preco_unitario,
       receita_bruta     = excluded.receita_bruta,
       receita_liquida   = excluded.receita_liquida,
       custo_total       = excluded.custo_total,
       lucro_bruto       = excluded.lucro_bruto,
       margem_percentual = excluded.margem_percentual,
       data_atualizacao  = now();

UPDATE etl_controle
   SET ultima_execucao = now(),
       ultimo_registro = GREATEST(ultimo_registro, COALESCE((
            SELECT max(GREATEST(soh.modifieddate, sod.modifieddate))
            FROM oltp.salesorderheader soh
            JOIN oltp.salesorderdetail sod ON soh.salesorderid=sod.salesorderid), ultimo_registro))
 WHERE nome_processo = 'fato_vendas';
