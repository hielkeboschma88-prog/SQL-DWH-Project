
/*
===============================================================================
Kwaliteitscontroles
===============================================================================
Doel van dit script:
    Dit script controleert de kwaliteit van de gegevens in de Gold Layer.
    Hierbij wordt gecontroleerd op:
    - Dubbele sleutels in de dimensietabellen.
    - Ontbrekende koppelingen tussen feitentabellen en dimensietabellen.
    - Juiste relaties tussen de tabellen voor analyses.

Gebruik:
    Onderzoek en los eventuele fouten op die uit de controles naar voren komen.
===============================================================================
*/

-- ====================================================================
-- Controle van 'gold.dim_customers'
-- ====================================================================
-- Controleer of elke klant een unieke sleutel heeft.
-- Verwachting: Geen resultaten (geen dubbele sleutels).

SELECT 
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


-- ====================================================================
-- Controle van 'gold.dim_products'
-- ====================================================================
-- Controleer of elk product een unieke sleutel heeft.
-- Verwachting: Geen resultaten (geen dubbele sleutels).

SELECT 
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- ====================================================================
-- Controle van 'gold.fact_sales'
-- ====================================================================
-- Controleer of elke verkoopregel gekoppeld kan worden aan een bestaande
-- klant en een bestaand product.
-- Verwachting: Geen resultaten (alle koppelingen zijn aanwezig).

SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL 
   OR c.customer_key IS NULL;
