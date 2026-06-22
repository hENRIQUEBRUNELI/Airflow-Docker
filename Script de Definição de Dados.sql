-- ============================================================================
-- SCRIPT DE CRIAÇÃO DO DATA WAREHOUSE (STAR SCHEMA) - POSTGRESQL
-- PROJETO: DATA WAREHOUSE ADVENTUREWORKS (VENDAS)
-- AUTOR: HENRIQUE BRUNELI SANTOS
-- ============================================================================

-- Criação da Tabela de Controle do ETL Incremental (Watermark)
CREATE TABLE IF NOT EXISTS etl_controle (
    tabela_destino VARCHAR(50) PRIMARY KEY,
    ultima_data_carga TIMESTAMP NOT NULL
);

-- Inicializa o controle de carga cronológica
INSERT INTO etl_controle (tabela_destino, ultima_data_carga)
VALUES ('fato_vendas', '2011-01-01 00:00:00')
ON CONFLICT (tabela_destino) DO NOTHING;

-- Dimensão Tempo
CREATE TABLE IF NOT EXISTS dim_tempo (
    sk_tempo INT PRIMARY KEY,
    data_completa DATE NOT NULL,
    ano INT NOT NULL,
    trimestre INT NOT NULL,
    mes INT NOT NULL,
    nome_mes VARCHAR(20) NOT NULL,
    dia INT NOT NULL,
    dia_semana INT NOT NULL,
    nome_dia_semana VARCHAR(20) NOT NULL
);

-- Dimensão Produto (Suporte a SCD Tipo 2)
CREATE TABLE IF NOT EXISTS dim_produto (
    sk_produto SERIAL PRIMARY KEY,
    nk_produto INT NOT NULL,
    nome_produto VARCHAR(100) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    subcategoria VARCHAR(50) NOT NULL,
    cor VARCHAR(30),
    data_inicio TIMESTAMP NOT NULL,
    data_fim TIMESTAMP,
    registro_atual BOOLEAN NOT NULL DEFAULT TRUE
);

-- Dimensão Cliente (Suporte a SCD Tipo 2)
CREATE TABLE IF NOT EXISTS dim_cliente (
    sk_cliente SERIAL PRIMARY KEY,
    nk_cliente INT NOT NULL,
    nome_completo VARCHAR(150) NOT NULL,
    tipo_cliente VARCHAR(20) NOT NULL,
    pais VARCHAR(50) NOT NULL,
    data_inicio TIMESTAMP NOT NULL,
    data_fim TIMESTAMP,
    registro_atual BOOLEAN NOT NULL DEFAULT TRUE
);

-- Dimensão Vendedor (Suporte a SCD Tipo 2)
CREATE TABLE IF NOT EXISTS dim_vendedor (
    sk_vendedor SERIAL PRIMARY KEY,
    nk_vendedor INT NOT NULL,
    nome_completo VARCHAR(150) NOT NULL,
    territorio VARCHAR(50),
    cota_anual DECIMAL(19,4),
    data_inicio TIMESTAMP NOT NULL,
    data_fim TIMESTAMP,
    registro_atual BOOLEAN NOT NULL DEFAULT TRUE
);

-- Dimensão Território (SCD Tipo 1)
CREATE TABLE IF NOT EXISTS dim_territorio (
    sk_territorio SERIAL PRIMARY KEY,
    nk_territorio INT NOT NULL,
    nome_territorio VARCHAR(50) NOT NULL,
    pais VARCHAR(50) NOT NULL,
    grupo VARCHAR(50) NOT NULL
);

-- Dimensão Promoção (SCD Tipo 1)
CREATE TABLE IF NOT EXISTS dim_promocao (
    sk_promocao SERIAL PRIMARY KEY,
    nk_promocao INT NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    percentual_desconto DECIMAL(10,4) NOT NULL,
    tipo_desconto VARCHAR(50) NOT NULL,
    categoria VARCHAR(50) NOT NULL
);

-- Tabela Fato Centralizada
CREATE TABLE IF NOT EXISTS fato_vendas (
    sk_venda SERIAL PRIMARY KEY,
    nk_pedido INT NOT NULL,
    nk_detalhe INT NOT NULL,
    sk_tempo INT NOT NULL,
    sk_produto INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_vendedor INT NOT NULL,
    sk_territorio INT NOT NULL,
    sk_promocao INT NOT NULL,
    quantidade INT NOT NULL,
    preco_unitario DECIMAL(19,4) NOT NULL,
    desconto_unitario DECIMAL(19,4) NOT NULL,
    custo_padrao DECIMAL(19,4) NOT NULL,
    receita_bruta DECIMAL(19,4) NOT NULL,
    receita_liquida DECIMAL(19,4) NOT NULL,
    custo_total DECIMAL(19,4) NOT NULL,
    lucro_bruto DECIMAL(19,4) NOT NULL,
    margem_percentual DECIMAL(10,4) NOT NULL,
    frete_rateado DECIMAL(19,4) NOT NULL,
    imposto_rateado DECIMAL(19,4) NOT NULL,
    data_carga TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_fato_tempo FOREIGN KEY (sk_tempo) REFERENCES dim_tempo (sk_tempo),
    CONSTRAINT fk_fato_produto FOREIGN KEY (sk_produto) REFERENCES dim_produto (sk_produto),
    CONSTRAINT fk_fato_cliente FOREIGN KEY (sk_cliente) REFERENCES dim_cliente (sk_cliente),
    CONSTRAINT fk_fato_vendedor FOREIGN KEY (sk_vendedor) REFERENCES dim_vendedor (sk_vendedor),
    CONSTRAINT fk_fato_territorio FOREIGN KEY (sk_territorio) REFERENCES dim_territorio (sk_territorio),
    CONSTRAINT fk_fato_promocao FOREIGN KEY (sk_promocao) REFERENCES dim_promocao (sk_promocao),
    CONSTRAINT uk_pedido_linha UNIQUE (nk_pedido, nk_detalhe)
);