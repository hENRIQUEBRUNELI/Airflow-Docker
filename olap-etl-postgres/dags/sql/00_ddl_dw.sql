-- ============================================================
-- DATA WAREHOUSE - AdventureWorks Sales
-- Modelo Estrela (Star Schema) - PostgreSQL
-- Executado de forma idempotente pela DAG (CREATE IF NOT EXISTS).
-- ============================================================

-- ============================================================
-- DIMENSÕES
-- ============================================================

CREATE TABLE IF NOT EXISTS dim_tempo (
    sk_tempo        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data_completa   DATE        NOT NULL,
    ano             INT         NOT NULL,
    trimestre       INT         NOT NULL,
    mes             INT         NOT NULL,
    nome_mes        VARCHAR(20) NOT NULL,
    semana_ano      INT         NOT NULL,
    dia             INT         NOT NULL,
    dia_semana      VARCHAR(10) NOT NULL,
    eh_fim_semana   BOOLEAN     NOT NULL,
    CONSTRAINT uq_dim_tempo_data UNIQUE (data_completa)
);

CREATE TABLE IF NOT EXISTS dim_produto (
    sk_produto      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nk_produto      INT NOT NULL,                 -- ProductID (OLTP)
    nome_produto    VARCHAR(100) NOT NULL,
    numero_produto  VARCHAR(50),
    cor             VARCHAR(30),
    tamanho         VARCHAR(10),
    peso            DECIMAL(10,4),
    preco_lista     DECIMAL(19,4),
    custo_padrao    DECIMAL(19,4),
    subcategoria    VARCHAR(100),
    categoria       VARCHAR(100),
    classe          VARCHAR(10),
    linha_produto   VARCHAR(10),
    data_inicio     DATE,
    data_fim        DATE,
    registro_atual  BOOLEAN DEFAULT TRUE,
    CONSTRAINT uq_dim_produto_nk UNIQUE (nk_produto, registro_atual)
);

CREATE TABLE IF NOT EXISTS dim_cliente (
    sk_cliente      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nk_cliente      INT NOT NULL,                 -- CustomerID (OLTP)
    nome_completo   VARCHAR(200),
    tipo_cliente    VARCHAR(20),                  -- 'Individual' ou 'Loja'
    nome_loja       VARCHAR(100),
    email           VARCHAR(100),
    telefone        VARCHAR(25),
    territorio      VARCHAR(100),
    regiao          VARCHAR(100),
    pais            VARCHAR(10),
    estado          VARCHAR(100),
    cidade          VARCHAR(100),
    cep             VARCHAR(20),
    data_inicio     DATE,
    data_fim        DATE,
    registro_atual  BOOLEAN DEFAULT TRUE,
    CONSTRAINT uq_dim_cliente_nk UNIQUE (nk_cliente, registro_atual)
);

CREATE TABLE IF NOT EXISTS dim_vendedor (
    sk_vendedor     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nk_vendedor     INT NOT NULL,                 -- SalesPersonID (OLTP)
    nome_completo   VARCHAR(200),
    cargo           VARCHAR(100),
    territorio      VARCHAR(100),
    regiao          VARCHAR(100),
    pais            VARCHAR(10),
    cota_anual      DECIMAL(19,4),
    bonus_ytd       DECIMAL(19,4),
    comissao_pct    DECIMAL(5,4),
    data_inicio     DATE,
    data_fim        DATE,
    registro_atual  BOOLEAN DEFAULT TRUE,
    CONSTRAINT uq_dim_vendedor_nk UNIQUE (nk_vendedor, registro_atual)
);

CREATE TABLE IF NOT EXISTS dim_territorio (
    sk_territorio   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nk_territorio   INT NOT NULL,                 -- TerritoryID (OLTP)
    nome_territorio VARCHAR(100) NOT NULL,
    pais            VARCHAR(10),
    grupo           VARCHAR(100),
    CONSTRAINT uq_dim_territorio_nk UNIQUE (nk_territorio)
);

CREATE TABLE IF NOT EXISTS dim_promocao (
    sk_promocao         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nk_promocao         INT NOT NULL,             -- SpecialOfferID (OLTP)
    descricao           VARCHAR(255),
    tipo_desconto       VARCHAR(100),
    categoria           VARCHAR(100),
    percentual_desconto DECIMAL(5,4),
    quantidade_min      INT,
    quantidade_max      INT,
    data_inicio         TIMESTAMP,
    data_fim            TIMESTAMP,
    CONSTRAINT uq_dim_promocao_nk UNIQUE (nk_promocao)
);

-- ============================================================
-- TABELA FATO
-- Grão: 1 linha por item de pedido (SalesOrderDetailID)
-- ============================================================

CREATE TABLE IF NOT EXISTS fato_vendas (
    sk_venda            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nk_pedido           INT NOT NULL,             -- SalesOrderID
    nk_detalhe          INT NOT NULL,             -- SalesOrderDetailID
    sk_tempo            INT NOT NULL REFERENCES dim_tempo(sk_tempo),
    sk_produto          INT NOT NULL REFERENCES dim_produto(sk_produto),
    sk_cliente          INT NOT NULL REFERENCES dim_cliente(sk_cliente),
    sk_vendedor         INT REFERENCES dim_vendedor(sk_vendedor),
    sk_territorio       INT REFERENCES dim_territorio(sk_territorio),
    sk_promocao         INT REFERENCES dim_promocao(sk_promocao),
    -- Métricas
    quantidade          INT NOT NULL,
    preco_unitario      DECIMAL(19,4) NOT NULL,
    desconto_unitario   DECIMAL(19,4) NOT NULL DEFAULT 0,
    custo_padrao        DECIMAL(19,4),
    receita_bruta       DECIMAL(19,4) NOT NULL,
    receita_liquida     DECIMAL(19,4) NOT NULL,
    custo_total         DECIMAL(19,4),
    lucro_bruto         DECIMAL(19,4),
    margem_percentual   DECIMAL(10,4),
    frete_rateado       DECIMAL(19,4),
    imposto_rateado     DECIMAL(19,4),
    -- Controle ETL
    data_carga          TIMESTAMP DEFAULT now(),
    data_atualizacao    TIMESTAMP DEFAULT now(),
    CONSTRAINT uq_fato_vendas_detalhe UNIQUE (nk_detalhe)
);

-- ============================================================
-- CONTROLE DE CARGA INCREMENTAL (marca d'água por processo)
-- ============================================================

CREATE TABLE IF NOT EXISTS etl_controle (
    nome_processo         VARCHAR(50) PRIMARY KEY,
    ultima_execucao       TIMESTAMP,
    ultimo_registro       TIMESTAMP,
    registros_inseridos   INT DEFAULT 0,
    registros_atualizados INT DEFAULT 0,
    status                VARCHAR(20) DEFAULT 'OK',
    mensagem              TEXT
);

INSERT INTO etl_controle (nome_processo, ultima_execucao, ultimo_registro)
VALUES
    ('dim_tempo',      '1900-01-01', '1900-01-01'),
    ('dim_produto',    '1900-01-01', '1900-01-01'),
    ('dim_cliente',    '1900-01-01', '1900-01-01'),
    ('dim_vendedor',   '1900-01-01', '1900-01-01'),
    ('dim_territorio', '1900-01-01', '1900-01-01'),
    ('dim_promocao',   '1900-01-01', '1900-01-01'),
    ('fato_vendas',    '1900-01-01', '1900-01-01')
ON CONFLICT (nome_processo) DO NOTHING;

-- ============================================================
-- ÍNDICES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_fato_tempo      ON fato_vendas(sk_tempo);
CREATE INDEX IF NOT EXISTS idx_fato_produto    ON fato_vendas(sk_produto);
CREATE INDEX IF NOT EXISTS idx_fato_cliente    ON fato_vendas(sk_cliente);
CREATE INDEX IF NOT EXISTS idx_fato_vendedor   ON fato_vendas(sk_vendedor);
CREATE INDEX IF NOT EXISTS idx_fato_territorio ON fato_vendas(sk_territorio);
CREATE INDEX IF NOT EXISTS idx_dim_tempo_ano   ON dim_tempo(ano, mes);
CREATE INDEX IF NOT EXISTS idx_dim_produto_nk  ON dim_produto(nk_produto, registro_atual);
CREATE INDEX IF NOT EXISTS idx_dim_cliente_nk  ON dim_cliente(nk_cliente, registro_atual);
CREATE INDEX IF NOT EXISTS idx_dim_vendedor_nk ON dim_vendedor(nk_vendedor, registro_atual);
