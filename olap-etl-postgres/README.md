# ETL Incremental AdventureWorks → Data Warehouse (Star Schema)

Projeto da disciplina de **Data Warehousing — Unisales**. Implementa um Data Warehouse
de vendas a partir do **AdventureWorks (OLTP)**, com modelagem **Star Schema**, carga
**ETL incremental** orquestrada por **Apache Airflow 3.x** e tudo em **PostgreSQL**,
containerizado com Docker.

## Arquitetura

```
AdventureWorks (OLTP)  --postgres_fdw-->  Data Warehouse (Star Schema)
   banco: adventureworks                     banco: adventureworks_dw
        (appdb container)                          (appdb container)
                         \                        /
                          Apache Airflow (LocalExecutor)
                          DAG: etl_adventureworks_dw
```

- **Origem e destino** rodam no mesmo PostgreSQL (serviço `appdb`). A origem é populada
  automaticamente no primeiro boot pelo dump em `seed/adventureworks_full.sql.gz`.
- O DW lê a origem via **`postgres_fdw`** (schema `oltp`), o que torna o ETL **set-based**
  (INSERT … SELECT) e fácil de auditar.
- A **carga incremental** usa a tabela `etl_controle` como marca d'água: cada tarefa
  processa apenas registros com `ModifiedDate` posterior ao último processado.

## Modelo dimensional

- **Fato:** `fato_vendas` — grão de **1 linha por item de pedido** (`SalesOrderDetailID`).
- **Dimensões:** `dim_tempo`, `dim_produto`, `dim_cliente`, `dim_vendedor`,
  `dim_territorio`, `dim_promocao`.
- `dim_produto`, `dim_cliente` e `dim_vendedor` aplicam **SCD Tipo 2**.
- Diagrama em `docs/modelo_estrela.puml`; dicionário em `docs/dicionario_de_dados.md`.

## Como executar

1. Copie o arquivo de variáveis e gere um segredo JWT:
   ```bash
   cp .env.sample .env
   # edite AIRFLOW__API_AUTH__JWT_SECRET com um valor aleatório
   ```
2. Suba a stack:
   ```bash
   docker compose up -d
   ```
   No primeiro boot o `appdb` carrega o AdventureWorks (~84 MB) e cria o banco
   `adventureworks_dw`. Aguarde o healthcheck do `appdb` ficar saudável.
3. Acesse a UI do Airflow em **http://localhost:8080** (usuário/senha: `airflow`/`airflow`).
4. Ative e dispare a DAG **`etl_adventureworks_dw`**.

## Estrutura da DAG

```
setup_dw → setup_fdw → [ dim_tempo | dim_territorio | dim_promocao |
                         dim_produto | dim_cliente | dim_vendedor ] → fato_vendas
```

| Tarefa | Arquivo SQL | Papel |
|---|---|---|
| setup_dw | `00_ddl_dw.sql` | Cria as tabelas do DW (idempotente) |
| setup_fdw | `01_setup_fdw.sql` | Cria as tabelas externas (origem) via postgres_fdw |
| dim_* | `02`–`07_*.sql` | Carga incremental das dimensões (SCD2 onde aplicável) |
| fato_vendas | `08_fato_vendas.sql` | Carga incremental do fato, resolvendo as surrogate keys |

## KPIs

Os 10 indicadores estão em `dags/sql/kpis_dw.sql`. Para executá-los:

```bash
docker exec -it <appdb_container> psql -U airflow -d adventureworks_dw -f /caminho/kpis_dw.sql
```

1. Receita total por período  2. Ticket médio por pedido  3. Margem por categoria
4. Ranking de produtos  5. Vendedores vs. cota  6. Receita por território
7. Impacto de descontos  8. Crescimento YoY  9. RFM de clientes  10. Sazonalidade trimestral

## Volumes esperados (carga completa)

| Tabela | Linhas |
|---|---|
| fato_vendas | 121.317 |
| dim_cliente | 19.820 |
| dim_produto | 504 |
| dim_tempo | 1.277 |
| dim_vendedor | 17 |
| dim_promocao | 16 |
| dim_territorio | 10 |

## Estrutura de pastas

```
.
├── docker-compose.yaml        # Airflow 3.x (LocalExecutor) + 2x PostgreSQL
├── .env.sample
├── dags/
│   ├── etl_adventureworks.py  # DAG (TaskFlow API)
│   └── sql/                   # DDL, setup FDW, ETL por tabela, KPIs
├── seed/                      # dump da origem + criação do DW (init do appdb)
└── docs/                      # diagrama estrela (PlantUML) + dicionário de dados
```
