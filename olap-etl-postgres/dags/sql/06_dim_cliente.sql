-- dim_cliente: SCD Tipo 2 incremental. DISTINCT ON garante 1 versão por cliente.
WITH src AS (
    SELECT DISTINCT ON (c.customerid)
           c.customerid AS nk_cliente,
           CASE WHEN c.personid IS NOT NULL THEN 'Individual' ELSE 'Loja' END AS tipo_cliente,
           COALESCE(s.name,'') AS nome_loja,
           COALESCE(p.firstname || ' ' || p.lastname, s.name, 'Desconhecido') AS nome_completo,
           ea.emailaddress AS email,
           pp.phonenumber  AS telefone,
           st.name AS territorio,
           st.grupo AS regiao,
           st.countryregioncode AS pais,
           sp.name AS estado,
           a.city  AS cidade,
           a.postalcode AS cep,
           GREATEST(c.modifieddate,
                    COALESCE(p.modifieddate,'1900-01-01'),
                    COALESCE(s.modifieddate,'1900-01-01')) AS modified_date
    FROM oltp.customer c
    LEFT JOIN oltp.person p  ON c.personid = p.businessentityid
    LEFT JOIN oltp.store  s  ON c.storeid  = s.businessentityid
    LEFT JOIN oltp.emailaddress ea ON p.businessentityid = ea.businessentityid
    LEFT JOIN oltp.personphone  pp ON p.businessentityid = pp.businessentityid
    LEFT JOIN oltp.salesterritory st ON c.territoryid = st.territoryid
    LEFT JOIN oltp.businessentityaddress bea ON c.customerid = bea.businessentityid
    LEFT JOIN oltp.address a  ON bea.addressid = a.addressid
    LEFT JOIN oltp.stateprovince sp ON a.stateprovinceid = sp.stateprovinceid
    ORDER BY c.customerid
)
, fecha AS (
    UPDATE dim_cliente d
       SET data_fim = current_date, registro_atual = FALSE
      FROM src
     WHERE d.nk_cliente = src.nk_cliente
       AND d.registro_atual = TRUE
       AND src.modified_date > (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='dim_cliente')
    RETURNING 1
)
INSERT INTO dim_cliente (nk_cliente, nome_completo, tipo_cliente, nome_loja, email,
                         telefone, territorio, regiao, pais, estado, cidade, cep,
                         data_inicio, data_fim, registro_atual)
SELECT nk_cliente, nome_completo, tipo_cliente, nome_loja, email,
       telefone, territorio, regiao, pais, estado, cidade, cep,
       current_date, NULL, TRUE
FROM src
WHERE modified_date > (SELECT ultimo_registro FROM etl_controle WHERE nome_processo='dim_cliente');

UPDATE etl_controle
   SET ultima_execucao = now(),
       ultimo_registro = GREATEST(ultimo_registro, COALESCE((
            SELECT max(GREATEST(c.modifieddate,
                                COALESCE(p.modifieddate,'1900-01-01'),
                                COALESCE(s.modifieddate,'1900-01-01')))
            FROM oltp.customer c
            LEFT JOIN oltp.person p ON c.personid=p.businessentityid
            LEFT JOIN oltp.store  s ON c.storeid =s.businessentityid), ultimo_registro))
 WHERE nome_processo = 'dim_cliente';
