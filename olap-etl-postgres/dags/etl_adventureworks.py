"""
DAG: ETL Incremental AdventureWorks -> Data Warehouse (Star Schema)
Disciplina de Data Warehousing - Unisales

Orquestra a carga incremental do DW de vendas a partir do AdventureWorks (OLTP).
O DW lê a origem via postgres_fdw (schema "oltp"), então todo o ETL é set-based
e roda na conexão do DW (conn_id="dw_conn").

Fluxo:
    setup_dw -> setup_fdw -> [6 dimensões em paralelo] -> fato_vendas

A carga é incremental: cada tarefa processa apenas registros com ModifiedDate
posterior à marca d'água registrada na tabela etl_controle.
"""

import datetime

from airflow.sdk import dag
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

DW = "dw_conn"  # conexão Postgres -> banco adventureworks_dw


def _sql_task(task_id: str, arquivo: str) -> SQLExecuteQueryOperator:
    """Cria uma tarefa que executa um arquivo .sql na conexão do DW."""
    return SQLExecuteQueryOperator(
        task_id=task_id,
        conn_id=DW,
        sql=f"sql/{arquivo}",
        split_statements=True,
        autocommit=True,
    )


@dag(
    dag_id="etl_adventureworks_dw",
    start_date=datetime.datetime(2024, 1, 1),
    schedule="@daily",
    catchup=False,
    tags=["adventureworks", "etl", "dw", "star-schema", "unisales"],
    default_args={
        "retries": 1,
        "retry_delay": datetime.timedelta(minutes=2),
    },
    doc_md=__doc__,
)
def etl_adventureworks_dw():
    # 1. Estrutura do DW (idempotente) e ponte FDW com a origem
    setup_dw = _sql_task("setup_dw", "00_ddl_dw.sql")
    setup_fdw = _sql_task("setup_fdw", "01_setup_fdw.sql")

    # 2. Dimensões (processadas em paralelo)
    dim_tempo = _sql_task("dim_tempo", "02_dim_tempo.sql")
    dim_territorio = _sql_task("dim_territorio", "03_dim_territorio.sql")
    dim_promocao = _sql_task("dim_promocao", "04_dim_promocao.sql")
    dim_produto = _sql_task("dim_produto", "05_dim_produto.sql")
    dim_cliente = _sql_task("dim_cliente", "06_dim_cliente.sql")
    dim_vendedor = _sql_task("dim_vendedor", "07_dim_vendedor.sql")

    # 3. Tabela fato (depende de todas as dimensões para resolver as SKs)
    fato_vendas = _sql_task("fato_vendas", "08_fato_vendas.sql")

    dimensoes = [
        dim_tempo,
        dim_territorio,
        dim_promocao,
        dim_produto,
        dim_cliente,
        dim_vendedor,
    ]

    setup_dw >> setup_fdw >> dimensoes >> fato_vendas


etl_adventureworks_dw()
