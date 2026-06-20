-- ============================================================
-- INTEGRAÇÃO OLTP -> DW via postgres_fdw
-- Define tabelas externas (schema "oltp") apontando para o
-- AdventureWorks, viabilizando um ETL set-based e incremental.
-- Tabelas declaradas manualmente (somente colunas usadas) para
-- não depender dos tipos-domínio customizados do porte de origem.
-- Idempotente.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = 'oltp_srv') THEN
        CREATE SERVER oltp_srv
            FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host '127.0.0.1', port '5432', dbname 'adventureworks');
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_user_mappings
        WHERE srvname = 'oltp_srv' AND (usename = CURRENT_USER OR usename IS NULL)
    ) THEN
        EXECUTE format(
            'CREATE USER MAPPING FOR %I SERVER oltp_srv OPTIONS (user %L, password %L)',
            CURRENT_USER, 'airflow', 'airflow');
    END IF;
END $$;

DROP SCHEMA IF EXISTS oltp CASCADE;
CREATE SCHEMA oltp;

CREATE FOREIGN TABLE oltp.product (
    productid int, name varchar, productnumber varchar, color varchar,
    size varchar, weight numeric, listprice numeric, standardcost numeric,
    class varchar, productline varchar, sellstartdate timestamp,
    sellenddate timestamp, productsubcategoryid int, modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'production', table_name 'product');

CREATE FOREIGN TABLE oltp.productsubcategory (
    productsubcategoryid int, productcategoryid int, name varchar
) SERVER oltp_srv OPTIONS (schema_name 'production', table_name 'productsubcategory');

CREATE FOREIGN TABLE oltp.productcategory (
    productcategoryid int, name varchar
) SERVER oltp_srv OPTIONS (schema_name 'production', table_name 'productcategory');

CREATE FOREIGN TABLE oltp.customer (
    customerid int, personid int, storeid int, territoryid int, modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'sales', table_name 'customer');

CREATE FOREIGN TABLE oltp.store (
    businessentityid int, name varchar, modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'sales', table_name 'store');

CREATE FOREIGN TABLE oltp.salesterritory (
    territoryid int, name varchar, countryregioncode varchar,
    grupo varchar OPTIONS (column_name 'group'), modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'sales', table_name 'salesterritory');

CREATE FOREIGN TABLE oltp.salesperson (
    businessentityid int, territoryid int, salesquota numeric, bonus numeric,
    commissionpct numeric, modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'sales', table_name 'salesperson');

CREATE FOREIGN TABLE oltp.specialoffer (
    specialofferid int, description varchar, discountpct numeric, type varchar,
    category varchar, startdate timestamp, enddate timestamp,
    minqty int, maxqty int, modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'sales', table_name 'specialoffer');

CREATE FOREIGN TABLE oltp.salesorderheader (
    salesorderid int, orderdate timestamp, customerid int, salespersonid int,
    territoryid int, subtotal numeric, taxamt numeric, freight numeric,
    modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'sales', table_name 'salesorderheader');

CREATE FOREIGN TABLE oltp.salesorderdetail (
    salesorderid int, salesorderdetailid int, orderqty int, productid int,
    specialofferid int, unitprice numeric, unitpricediscount numeric,
    modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'sales', table_name 'salesorderdetail');

CREATE FOREIGN TABLE oltp.person (
    businessentityid int, firstname varchar, lastname varchar, modifieddate timestamp
) SERVER oltp_srv OPTIONS (schema_name 'person', table_name 'person');

CREATE FOREIGN TABLE oltp.emailaddress (
    businessentityid int, emailaddress varchar
) SERVER oltp_srv OPTIONS (schema_name 'person', table_name 'emailaddress');

CREATE FOREIGN TABLE oltp.personphone (
    businessentityid int, phonenumber varchar
) SERVER oltp_srv OPTIONS (schema_name 'person', table_name 'personphone');

CREATE FOREIGN TABLE oltp.businessentityaddress (
    businessentityid int, addressid int
) SERVER oltp_srv OPTIONS (schema_name 'person', table_name 'businessentityaddress');

CREATE FOREIGN TABLE oltp.address (
    addressid int, city varchar, postalcode varchar, stateprovinceid int
) SERVER oltp_srv OPTIONS (schema_name 'person', table_name 'address');

CREATE FOREIGN TABLE oltp.stateprovince (
    stateprovinceid int, name varchar
) SERVER oltp_srv OPTIONS (schema_name 'person', table_name 'stateprovince');

CREATE FOREIGN TABLE oltp.employee (
    businessentityid int, jobtitle varchar
) SERVER oltp_srv OPTIONS (schema_name 'humanresources', table_name 'employee');
