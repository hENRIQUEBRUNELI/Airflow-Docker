-- dim_tempo: espinha de datas (gerada), cobre o intervalo de pedidos do OLTP.
-- Idempotente via ON CONFLICT; nomes em PT-BR independentes do locale do servidor.
INSERT INTO dim_tempo (data_completa, ano, trimestre, mes, nome_mes,
                       semana_ano, dia, dia_semana, eh_fim_semana)
SELECT g::date,
       extract(year    from g)::int,
       extract(quarter from g)::int,
       extract(month   from g)::int,
       CASE extract(month from g)
            WHEN 1 THEN 'Janeiro'  WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Março'
            WHEN 4 THEN 'Abril'    WHEN 5 THEN 'Maio'       WHEN 6 THEN 'Junho'
            WHEN 7 THEN 'Julho'    WHEN 8 THEN 'Agosto'     WHEN 9 THEN 'Setembro'
            WHEN 10 THEN 'Outubro' WHEN 11 THEN 'Novembro'  ELSE 'Dezembro' END,
       extract(week from g)::int,
       extract(day  from g)::int,
       CASE extract(isodow from g)
            WHEN 1 THEN 'Segunda' WHEN 2 THEN 'Terça'  WHEN 3 THEN 'Quarta'
            WHEN 4 THEN 'Quinta'  WHEN 5 THEN 'Sexta'  WHEN 6 THEN 'Sábado'
            ELSE 'Domingo' END,
       extract(isodow from g) >= 6
FROM generate_series(
        (SELECT date_trunc('year', min(orderdate)) FROM oltp.salesorderheader),
        (SELECT max(orderdate) FROM oltp.salesorderheader),
        interval '1 day') AS g
ON CONFLICT (data_completa) DO NOTHING;

UPDATE etl_controle SET ultima_execucao = now() WHERE nome_processo = 'dim_tempo';
