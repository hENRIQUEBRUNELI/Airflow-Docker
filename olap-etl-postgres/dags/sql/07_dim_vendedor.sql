-- dim_vendedor: SCD Tipo 2 incremental.
WITH src AS (
    SELECT sp.businessentityid AS nk_vendedor,
           p.firstname || ' ' || p.lastname AS nome_completo,
           e.jobtitle AS cargo,
           st.name AS territorio, st.grupo AS regiao, st.countryregioncode AS pais,
           sp.salesquota AS cota_anual, sp.bonus AS bonus_ytd, sp.commissionpct AS comissao_pct,
           GREATEST(sp.modifieddate, p.modifieddate) AS modified_date
    FROM oltp.salesperson sp
    JOIN oltp.person   p ON sp.businessentityid = p.businessentityid
    JOIN oltp.employee e ON sp.businessentityid = e.businessentityid
    LEFT JOIN oltp.salesterritory st ON sp.territoryid = st.territoryid
)
, fecha AS (
    UPDATE dim_vendedor d
       SET data_fim = current_date, registro_atual = FALSE
      FROM src
     WHERE d.nk_vendedor = src.nk_vendedor
       AND d.registro_atual = TRUE
       AND src.modified_date > (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='dim_vendedor')
    RETURNING 1
)
INSERT INTO dim_vendedor (nk_vendedor, nome_completo, cargo, territorio, regiao,
                          pais, cota_anual, bonus_ytd, comissao_pct,
                          data_inicio, data_fim, registro_atual)
SELECT nk_vendedor, nome_completo, cargo, territorio, regiao, pais,
       cota_anual, bonus_ytd, comissao_pct, current_date, NULL, TRUE
FROM src
WHERE modified_date > (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='dim_vendedor');

UPDATE etl_controle
   SET ultima_execucao = now(),
       ultimo_registro = GREATEST(ultimo_registro, COALESCE((
            SELECT max(GREATEST(sp.modifieddate, p.modifieddate))
            FROM oltp.salesperson sp
            JOIN oltp.person p ON sp.businessentityid=p.businessentityid), ultimo_registro))
 WHERE nome_processo = 'dim_vendedor';
