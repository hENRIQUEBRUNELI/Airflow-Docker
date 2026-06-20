# Dicionário de Dados — Data Warehouse de Vendas (AdventureWorks)

Modelo multidimensional em padrão **Star Schema**, implementado em PostgreSQL.
Granularidade da tabela fato: **uma linha por item de pedido** (`SalesOrderDetailID` da origem).

Convenções: `sk_` = *surrogate key* (chave artificial do DW); `nk_` = *natural key* (chave de
negócio vinda do OLTP). Dimensões `dim_produto`, `dim_cliente` e `dim_vendedor` aplicam
**SCD Tipo 2** (histórico via `registro_atual`, `data_inicio`, `data_fim`).

## Tabela Fato — `fato_vendas`

| Coluna | Tipo | Descrição |
|---|---|---|
| sk_venda | INT (PK) | Chave artificial da linha de venda |
| nk_pedido | INT | SalesOrderID (origem) |
| nk_detalhe | INT | SalesOrderDetailID — define o grão; UNIQUE |
| sk_tempo | INT (FK) | Referência para `dim_tempo` |
| sk_produto | INT (FK) | Referência para `dim_produto` |
| sk_cliente | INT (FK) | Referência para `dim_cliente` |
| sk_vendedor | INT (FK) | Referência para `dim_vendedor` (pode ser nulo) |
| sk_territorio | INT (FK) | Referência para `dim_territorio` (pode ser nulo) |
| sk_promocao | INT (FK) | Referência para `dim_promocao` (pode ser nulo) |
| quantidade | INT | Quantidade vendida (OrderQty) |
| preco_unitario | DECIMAL(19,4) | Preço unitário (UnitPrice) |
| desconto_unitario | DECIMAL(19,4) | Percentual de desconto aplicado |
| custo_padrao | DECIMAL(19,4) | Custo padrão do produto |
| receita_bruta | DECIMAL(19,4) | quantidade × preço_unitário |
| receita_liquida | DECIMAL(19,4) | quantidade × preço × (1 − desconto) |
| custo_total | DECIMAL(19,4) | quantidade × custo_padrão |
| lucro_bruto | DECIMAL(19,4) | receita_líquida − custo_total |
| margem_percentual | DECIMAL(10,4) | lucro_bruto / receita_líquida |
| frete_rateado | DECIMAL(19,4) | Frete do pedido rateado pelo item |
| imposto_rateado | DECIMAL(19,4) | Imposto do pedido rateado pelo item |
| data_carga | TIMESTAMP | Quando a linha foi inserida no DW |
| data_atualizacao | TIMESTAMP | Última atualização da linha |

## `dim_tempo`

| Coluna | Tipo | Descrição |
|---|---|---|
| sk_tempo | INT (PK) | Chave artificial |
| data_completa | DATE | Data (UNIQUE) |
| ano, trimestre, mes | INT | Componentes da data |
| nome_mes | VARCHAR | Nome do mês (PT-BR) |
| semana_ano | INT | Semana ISO do ano |
| dia | INT | Dia do mês |
| dia_semana | VARCHAR | Nome do dia (PT-BR) |
| eh_fim_semana | BOOLEAN | Sábado/domingo |

## `dim_produto` (SCD2)

| Coluna | Tipo | Descrição |
|---|---|---|
| sk_produto | INT (PK) | Chave artificial |
| nk_produto | INT | ProductID (origem) |
| nome_produto, numero_produto | VARCHAR | Identificação do produto |
| cor, tamanho, classe, linha_produto | VARCHAR | Atributos descritivos |
| peso, preco_lista, custo_padrao | DECIMAL | Atributos numéricos |
| categoria, subcategoria | VARCHAR | Hierarquia de produto |
| data_inicio, data_fim | DATE | Vigência da versão (SCD2) |
| registro_atual | BOOLEAN | Marca a versão vigente |

## `dim_cliente` (SCD2)

| Coluna | Tipo | Descrição |
|---|---|---|
| sk_cliente | INT (PK) | Chave artificial |
| nk_cliente | INT | CustomerID (origem) |
| nome_completo, tipo_cliente, nome_loja | VARCHAR | Identificação |
| email, telefone | VARCHAR | Contato |
| territorio, regiao, pais, estado, cidade, cep | VARCHAR | Localização |
| data_inicio, data_fim, registro_atual | — | Controle SCD2 |

## `dim_vendedor` (SCD2)

| Coluna | Tipo | Descrição |
|---|---|---|
| sk_vendedor | INT (PK) | Chave artificial |
| nk_vendedor | INT | SalesPersonID (origem) |
| nome_completo, cargo | VARCHAR | Identificação |
| territorio, regiao, pais | VARCHAR | Localização |
| cota_anual, bonus_ytd, comissao_pct | DECIMAL | Metas/remuneração |
| data_inicio, data_fim, registro_atual | — | Controle SCD2 |

## `dim_territorio`

| Coluna | Tipo | Descrição |
|---|---|---|
| sk_territorio | INT (PK) | Chave artificial |
| nk_territorio | INT | TerritoryID (origem) |
| nome_territorio | VARCHAR | Nome do território |
| pais | VARCHAR | Código do país |
| grupo | VARCHAR | Grupo/região macro |

## `dim_promocao`

| Coluna | Tipo | Descrição |
|---|---|---|
| sk_promocao | INT (PK) | Chave artificial |
| nk_promocao | INT | SpecialOfferID (origem) |
| descricao | VARCHAR | Descrição da promoção |
| tipo_desconto, categoria | VARCHAR | Classificação |
| percentual_desconto | DECIMAL | Percentual do desconto |
| quantidade_min, quantidade_max | INT | Faixa de quantidade |
| data_inicio, data_fim | TIMESTAMP | Vigência da promoção |

## `etl_controle` (apoio à carga incremental)

| Coluna | Tipo | Descrição |
|---|---|---|
| nome_processo | VARCHAR (PK) | Nome da tarefa de ETL |
| ultima_execucao | TIMESTAMP | Quando rodou pela última vez |
| ultimo_registro | TIMESTAMP | **Marca d'água**: maior ModifiedDate já processado |
| registros_inseridos / registros_atualizados | INT | Contadores |
| status, mensagem | — | Resultado da execução |
