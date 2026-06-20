-- dim_produto: SCD Tipo 2 incremental.
-- (1) fecha a versão atual dos produtos alterados; (2) insere a nova versão.
UPDATE dim_produto d
   SET data_fim = current_date, registro_atual = FALSE
  FROM oltp.product s
 WHERE d.nk_produto = s.productid
   AND d.registro_atual = TRUE
   AND s.modifieddate > (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='dim_produto');

INSERT INTO dim_produto (nk_produto, nome_produto, numero_produto, cor, tamanho,
                         peso, preco_lista, custo_padrao, subcategoria, categoria,
                         classe, linha_produto, data_inicio, data_fim, registro_atual)
SELECT s.productid, s.name, s.productnumber,
       COALESCE(s.color,'N/A'), COALESCE(s.size,'N/A'),
       s.weight, s.listprice, s.standardcost,
       COALESCE(ps.name,'Sem Subcategoria'), COALESCE(pc.name,'Sem Categoria'),
       COALESCE(s.class,'N/A'), COALESCE(s.productline,'N/A'),
       s.sellstartdate::date, NULL, TRUE
FROM oltp.product s
LEFT JOIN oltp.productsubcategory ps ON s.productsubcategoryid = ps.productsubcategoryid
LEFT JOIN oltp.productcategory    pc ON ps.productcategoryid    = pc.productcategoryid
WHERE s.modifieddate > (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='dim_produto');

UPDATE etl_controle
   SET ultima_execucao = now(),
       ultimo_registro = GREATEST(ultimo_registro,
                                  COALESCE((SELECT max(modifieddate) FROM oltp.product), ultimo_registro))
 WHERE nome_processo = 'dim_produto';
