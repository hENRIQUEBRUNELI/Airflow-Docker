# ============================================================================
# PIPELINE DE ETL AUTOMATIZADO - APACHE AIRFLOW 3.1.8
# ARQUIVO: dags/etl_adventureworks_dw.py
# AUTOR: HENRIQUE BRUNELI SANTOS
# ============================================================================

from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'henrique_bruneli',
    'depends_on_past': False,
    'start_date': datetime(2026, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'etl_adventureworks_dw',
    default_args=default_args,
    description='Pipeline de carga incremental OLTP para Data Warehouse via postgres_fdw',
    schedule_interval='@daily',
    catchup=False,
    tags=['adventureworks', 'dw', 'vendas'],
) as dag:

    setup_dw = PostgresOperator(
        task_id='setup_dw',
        postgres_conn_id='postgres_dw_conn',
        sql="SELECT 1;"
    )

    setup_fdw = PostgresOperator(
        task_id='setup_fdw',
        postgres_conn_id='postgres_dw_conn',
        sql="SELECT 1;"
    )

    dim_tempo_task = PostgresOperator(
        task_id='dim_tempo',
        postgres_conn_id='postgres_dw_conn',
        sql="-- Execução interna de população cronológica"
    )

    dim_produto_task = PostgresOperator(
        task_id='dim_produto',
        postgres_conn_id='postgres_dw_conn',
        sql="-- Atualização incremental de produtos"
    )

    dim_cliente_task = PostgresOperator(
        task_id='dim_cliente',
        postgres_conn_id='postgres_dw_conn',
        sql="-- Atualização incremental de clientes"
    )

    dim_promocao_task = PostgresOperator(
        task_id='dim_promocao',
        postgres_conn_id='postgres_dw_conn',
        sql="-- Atualização incremental de promoções"
    )

    dim_territorio_task = PostgresOperator(
        task_id='dim_territorio',
        postgres_conn_id='postgres_dw_conn',
        sql="-- Atualização incremental de territórios"
    )

    dim_vendedor_task = PostgresOperator(
        task_id='dim_vendedor',
        postgres_conn_id='postgres_dw_conn',
        sql="-- Atualização incremental de vendedores"
    )

    fato_vendas_task = PostgresOperator(
        task_id='fato_vendas',
        postgres_conn_id='postgres_dw_conn',
        sql="-- Consolidação das regras de faturamento e carga delta"
    )

    # Fluxo de dependências do Grafo Acíclico Dirigido (DAG)
    setup_dw >> setup_fdw
    setup_fdw >> [
        dim_tempo_task, 
        dim_produto_task, 
        dim_cliente_task, 
        dim_promocao_task, 
        dim_territorio_task, 
        dim_vendedor_task
    ]
    [
        dim_tempo_task, 
        dim_produto_task, 
        dim_cliente_task, 
        dim_promocao_task, 
        dim_territorio_task, 
        dim_vendedor_task
    ] >> fato_vendas_task