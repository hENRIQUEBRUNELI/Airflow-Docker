-- dim_promocao: upsert incremental.
INSERT INTO dim_promocao (nk_promocao, descricao, tipo_desconto, categoria,
                          percentual_desconto, quantidade_min, quantidade_max,
                          data_inicio, data_fim)
SELECT specialofferid, description, type, category,
       discountpct, minqty, maxqty, startdate, enddate
FROM oltp.specialoffer
WHERE modifieddate > (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='dim_promocao')
ON CONFLICT (nk_promocao) DO UPDATE
   SET descricao           = excluded.descricao,
       percentual_desconto = excluded.percentual_desconto;

UPDATE etl_controle
   SET ultima_execucao = now(),
       ultimo_registro = GREATEST(ultimo_registro,
                                  COALESCE((SELECT max(modifieddate) FROM oltp.specialoffer), ultimo_registro))
 WHERE nome_processo = 'dim_promocao';
