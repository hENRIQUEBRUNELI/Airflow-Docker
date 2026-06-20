-- dim_territorio: upsert incremental (dimensão estável).
INSERT INTO dim_territorio (nk_territorio, nome_territorio, pais, grupo)
SELECT territoryid, name, countryregioncode, grupo
FROM oltp.salesterritory
WHERE modifieddate > (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='dim_territorio')
ON CONFLICT (nk_territorio) DO UPDATE
   SET nome_territorio = excluded.nome_territorio,
       pais            = excluded.pais,
       grupo           = excluded.grupo;

UPDATE etl_controle
   SET ultima_execucao = now(),
       ultimo_registro = GREATEST(ultimo_registro,
                                  COALESCE((SELECT max(modifieddate) FROM oltp.salesterritory), ultimo_registro))
 WHERE nome_processo = 'dim_territorio';
