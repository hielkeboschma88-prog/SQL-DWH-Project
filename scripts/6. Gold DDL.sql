/* Dit script maakt de Gold Layer aan. 
   Deze bestaat uit views die worden gemaakt vanuit de Silver tabellen.
   Deze data wordt uit deze tabellen gehaald, met elkaar verrijkt en is hapklaar voor analyse-doelen. */

/* ========== Maken van Dim.Customers ========== */

/* Meerdere kolommen voor Gender. 
   Businessrule: CRM systeem is leidend. */

CREATE VIEW gold.dim_customers AS 

		SELECT
			ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
			t1.cst_id AS customer_id,
			t1.cst_key AS customer_number,
			t1.cst_firstname AS first_name,
			t1.cst_lastname AS last_name,
			t3.cntry AS country,
			t1.cst_marital_status AS marital_status,
			-- Alle mogelijke situaties worden hiermee afgehandeld, waarmee voorrang wordt gegeven aan de data uit de CRM
				CASE
					WHEN t1.cst_gndr != 'Unknown' THEN t1.cst_gndr
					ELSE COALESCE(t2.gen, 'Unknown')
				END AS gender,
			t2.bdate AS birthdate,
			t1.cst_create_date AS create_date

		FROM silver.crm_cust_info t1
			LEFT JOIN silver.erp_cust_az12 t2 ON
			t1.cst_key = t2.custCID
			LEFT JOIN silver.erp_loc_a101 t3 ON
			t1.cst_key = t3.cid

/* =========== Maken van Dim.Products ========== */

CREATE VIEW gold.dim_products AS

	SELECT 
		ROW_NUMBER() OVER (ORDER BY start_date, product_id ) AS product_key,
		product_id,
		product_name,
		product_number,
		category,
		subcategory,
		maintenance,
		product_line,
		cost,
		start_date

	FROM (
		SELECT
			t1.prd_id AS product_id,
			-- Voor de business een productverie gemaakt. Het hoogste cijfer is de meest recente versie
			ROW_NUMBER() OVER (PARTITION BY t1.prd_key ORDER BY t1.prd_start_dt ASC) AS product_version,
			t1.prd_nm AS product_name,
			t1.prd_line AS product_line,
			t1.prd_key AS product_number,
			t2.cat AS category,
			t2.subcat AS subcategory,
			t2.Maintenance AS maintenance,
			t1.prd_cost AS cost,
			t1.prd_start_dt AS start_date,
			t1.prd_end_dt AS end_date
			
		FROM silver.crm_prd_info t1 
			LEFT JOIN silver.erp_px_cat_g1v2 t2 ON
			t1.cat_id = t2.id) t

	WHERE product_version = 1

/* =========== Maken van Fact.Sales ========== */

CREATE VIEW gold.fact_sales AS

SELECT 
	sd.sls_ord_num AS order_number,
	-- Surrogate key hier nemen van gold.dim_products
	dp.product_key AS product_key,
	-- Surrogate key hier nemen van gold.dim_customers
	dc.customer_key AS customer_key,
	sd.sls_order_dt AS order_date,
	sd.sls_ship_dt AS shipping_date,
	sd.sls_due_dt AS due_date,
	sd.sls_sales AS sales_amount,
	sd.sls_quantity AS quantity,
	sd.sls_price AS price
FROM silver.crm_sales_details sd
	LEFT JOIN gold.Dim_Products dp ON
	sd.sls_prd_key = dp.product_number
	LEFT JOIN gold.Dim_Customers dc ON
	sd.sls_cust_id = dc.customer_id















SELECT *
FROM silver.crm_prd_info

SELECT *
FROM silver.erp_px_cat_g1v2
 


	



