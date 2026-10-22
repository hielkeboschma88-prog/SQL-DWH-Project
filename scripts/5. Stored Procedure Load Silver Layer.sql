
/* 
===========================================================================================================
   Dit script laadt de Silver Layer. 
   Het zorgt er voor dat alle Bronze Layer data is gecontroleerd en geprepareerd is en laadt alle data in 
   Uitvoeren via: EXECUTE  silver.load_silver
=========================================================================================================== */

CREATE OR ALTER PROCEDURE silver.load_silver AS


BEGIN
	BEGIN TRY
		DECLARE @start_time DATETIME, @end_time DATETIME, @start_time_batch DATETIME, @end_time_batch DATETIME

		PRINT '===================================';
		PRINT 'Loading Silver Layer';
		PRINT '===================================';

		PRINT '-----------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '-----------------------------------';

		SET @start_time_batch = GETDATE()
		SET @start_time = GETDATE()
		-- main query voor silver.crm_cust_info:
		PRINT '>> Truncating table: silver.crm_cust_info'
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting data into silver.crm_cust_info'
		INSERT INTO silver.crm_cust_info (
			   [cst_id]
			  ,[cst_key]
			  ,[cst_firstname]
			  ,[cst_lastname]
			  ,[cst_marital_status]
			  ,[cst_gndr]
			  ,[cst_create_date])
		SELECT 
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname, -- Weghalen spaties
			TRIM(cst_lastname) AS cst_lastname, -- Weghalen spaties  
			CASE 
				WHEN UPPER(cst_marital_status) = 'S' THEN 'Single'
				WHEN UPPER(cst_marital_status) = 'M' THEN 'Married'
				ELSE 'Unknown'
			END AS cst_marital_status, -- Data normaliseren
			CASE 
				WHEN UPPER(cst_gndr) = 'M' THEN 'Male'
				WHEN UPPER(cst_gndr) = 'F' THEN 'Female'
				ELSE 'Unknown' -- Data normaliseren
			END AS cst_gndr,
			cst_create_date
		FROM 
			(SELECT 
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as cst_versions
			FROM bronze.crm_cust_info) a -- Meerdere versues op cst_id, sorteren op nieuwste versie
		WHERE 
			cst_versions = 1 AND
			cst_id IS NOT NULL; -- Alleen nieuwste versies selecteren

		SET @end_time = GETDATE ()
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @end_time, @start_time) AS NVARCHAR) + ' seconds'
		PRINT '-----------------------------------';

		/* ================================================================================================== */


		-- mainquery voor silver.crm_prd_info

		-- PK gecheckt, geen NULLS, geen duplicates
		-- Check op spaties op nvarchar columns
		-- Check op joins -> prd_key moet joinbaar zijn op: sales_details.prd_key en erp_px_cat_g1z2

		/* Veld prd_key moet daarom worden gesplitst. 
		   Eerste 5 tekens is voor de join op erp_px_cat_g1z2 en is cat_id
		   Vanaf teken 5 is prd_key */ 

		SET @start_time = GETDATE()
		PRINT '>> Truncating table: silver.crm_prd_info'
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting data into silver.crm_prd_info'
		INSERT INTO silver.crm_prd_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt)
		SELECT
			prd_id,
			/* In erp_px_cat_g1z2.id Zit een liggend _ ipv een - tussen de eerste 5 karakters  */
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
			/* Join sales_details.prd_key voorbereiden door prd_key te extracten. Met LEN functie + huidige kolom 
			  pakt hij altijd het juiste aantal tekens dat nodig is */
			SUBSTRING(prd_key,7 , LEN(prd_key)) AS prd_key,
			/* Testen of de join werkt via:
					SELECT * FROM bronze.crm_prd_info
					WHERE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') IN (
					SELECT distinct id
					FROM bronze.erp_px_cat_g1v2) 
			*/ 
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost, -- NULLS worden 0
			CASE
				WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
				WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
				WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
				WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
				ELSE 'Unknown'
			END AS prd_line,
			/* Checken op ongeldige tijdsvensters. Data prd_end_dt klopt niet. 
			   Zelf nieuwe tijdsvensters maken. De prd_end_dt is altijd de volgende versie van prd_start_dt  */
			CAST(prd_start_dt AS DATE) AS prd_start_dt,
			CAST(LEAD(prd_start_dt, 1) OVER (PARTITION BY prd_key ORDER BY prd_id) - 1 AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info;

		SET @end_time = GETDATE ()
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @end_time, @start_time) AS NVARCHAR) + ' seconds'
		PRINT '-----------------------------------';

		/* ======================================================================================================== */

		-- Stap 1 kijken of key uniek en niet NULL is: Er is geen unieke kolom. 
		-- Uitkomst: Meerdere regels per order, in mainquery een unieke regelnummer maken.

		-- stap 2: Checken op spaces in tekstkolommen
		-- Uitkomst: geen onnodige spaces.

		-- Stap 3: check alle kolommen op NULLS.
		-- Uitkomst: -- NULL op sls_sales en price

		/* Stap 4: Datumvelden datatypes kloppen niet. Moeten van INT naar DATE. 
				CAST werkt niet omdat er 0 waarden zijn. Eerst afhandelen naar 0.
				Ook checken of er wel 8 characters zijn, anders werkt CAST niet. */

		/* Stap 5: Joins van cust_id en prd_key controleren
		   Uitkomst: Joins werken als ik de keys vergelijk met de keys uit de silver layer. */

		/* Stap 6: Check op tijdsvensters. Gebeurtenissen in de toekomst mogen nooit voor eerdere gebeurtenissen zijn 
		   Uitkomst: Goed. Orders, Shipment en Due volgens in logische volgorde op elkaar */

		/* Stap 7: Controle op Sales, quantity en price op volgende elementen:
				- Mag geen NULL zijn > Niet correct voor Sales en Price
				- Mag niet negatief zijn >  Niet correct voor Sales en Price
				- Sales = Quantity * Price > Niet correct door Sales en Price

		   Business rules: 
				- Als Sales 0, negatief of NULL is dan afleiden van Quantity en Price
				- Als Price 0 of NULL is dan berkenen via Sales en Quantity
				- Als de prijs negatief is dan positief maken */

		-- Main Query
		SET @start_time = GETDATE()
		PRINT '>> Truncating table: silver.crm_sales_details'
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting data into silver.crm_sales_details'
		INSERT INTO silver.crm_sales_details (
			   [sls_ord_num]
			  ,[sls_prd_key]
			  ,[sls_cust_id]
			  ,[sls_order_dt]
			  ,[sls_ship_dt]
			  ,[sls_due_dt]
			  ,[sls_sales]
			  ,[sls_quantity]
			  ,[sls_price]
		)
		SELECT 
		-- Kolommen sls_prd_key en sls_ord_num as is overnemen.
			sls_prd_key,
			sls_ord_num,
			sls_cust_id,
		-- NULLS afhandelen en INT naar DATE casten. Ik doe dit voor alle date kolommen ook al is het nu niet nodig. Toekomstproof.
			CASE
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END AS sls_order_dt,
			CASE
				WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,
			CASE
				WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,
		-- Sales berekenen
			CASE
				WHEN sls_sales <= 0 OR 
					 sls_sales IS NULL OR 
					 sls_sales != sls_quantity * ABS(sls_price) 
				THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales	
			END AS sls_sales,
			sls_quantity,
		-- Price berekenen
			CASE
				WHEN sls_price < 0 THEN ABS(sls_price)
				WHEN sls_price = 0 OR sls_price IS NULL THEN NULLIF(sls_sales, 0) / sls_quantity
				ELSE sls_price
			END AS sls_price
		FROM bronze.crm_sales_details;

		SET @end_time = GETDATE ()
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @end_time, @start_time) AS NVARCHAR) + ' seconds'
		PRINT '-----------------------------------';

		/* ======================================================================================================== */

		PRINT '-----------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '-----------------------------------';

		/* Data quality checks op silver.erp_cust_az12 */

		-- Stap 1: Nulls -> -- Uitkomst: Alleen gen heeft Nulls
		-- Stap 2: Uniekheid custCID -> Geslaagd.
		-- Stap 3: Joinbaarheid custCID op silver.crm_cust_info -> Eerste 3 letters er af halen als er 'NAS' staat.
		-- Stap 4: Datatypes -> kloppen
		-- Stap 5: Spaties checken -> Klopt
		-- Stap 6: Check of categorieën gen kloppen -> lege strings, NULLS en letters ipv woorden. -> Aanpassen met logic.
		-- Stap 7: Check op onlogische bdate -> Er zijn toekomstige geboortedata. -> Normaliseren

		-- Conclusie:
		-- gen omvormen zodat er alleen Male of Female staat.
		-- Eerste 3 tekens weg bij custCID voor joinbaarheid silver.crm_cust_info
		-- Normaliseren van bdate die in toekomst ligt

		--Main query:
		SET @start_time = GETDATE()
		PRINT '>> Truncating table: silver.erp_cust_az12'
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting data into silver.erp_cust_az12'
		INSERT INTO silver.erp_cust_az12 (custCID, bdate, gen)
		SELECT 
			CASE	
				WHEN custCID LIKE 'NAS%' THEN SUBSTRING(custCID, 4,LEN(custCID)) 
				ELSE custCID
				END AS custCID,
			CASE 
				WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
			END AS bdate,
			CASE 
				WHEN gen IS NULL OR gen = '' THEN 'Unknown'
				WHEN UPPER(TRIM(gen)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(gen)) = 'M' THEN 'Male'
				ELSE gen
			END as gen
		FROM bronze.erp_cust_az12;

		SET @end_time = GETDATE ()
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @end_time, @start_time) AS NVARCHAR) + ' seconds'
		PRINT '-----------------------------------';

		/* ======================================================================================================== */

		-- Stap 1: Check op NULLS bij PK cid -> Geen Nulls
		-- Stap 2: Joinbaarheid op silver.crm_cust_info.cst_key -> Middenstreepje moet weg
		-- Stap 3: Join testen -> Werkt
		-- Stap 4: Check op kwaliteit bij cntry -> Nulls, lege velden, afkoringen ipv landen -> afhandelen

		-- Main query:
		SET @start_time = GETDATE()
		PRINT '>> Truncating table: silver.erp_loc_a101'
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting data into silver.erp_loc_a101'
		INSERT INTO silver.erp_loc_a101 (cid,cntry)
		SELECT 
			REPLACE(cid, '-', '') AS cid,
			CASE 
				WHEN TRIM(cntry) IS NULL OR cntry = ' ' THEN 'Onbekend'
				WHEN TRIM(cntry) = 'DE' THEN 'Germany'
				WHEN TRIM(cntry) IN ('USA', 'US') THEN 'United States'
				ELSE TRIM(cntry)
			END AS cntry
		FROM bronze.erp_loc_a101;

		SET @end_time = GETDATE ()
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @end_time, @start_time) AS NVARCHAR) + ' seconds'
		PRINT '-----------------------------------';

		/* ======================================================================================================== */

		-- Stap 1: Joinbaarheid id op silver.crm_prd_info.cat_id -> Geslaagd
		-- Stap 2: Onnodige spaties -> Geslaagd
		-- Stap 3: Check op categorieën -> Geslaagd

		SET @start_time = GETDATE()
		PRINT '>> Truncating table: silver.erp_px_cat_g1v2'
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting data into silver.erp_px_cat_g1v2'
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance)
		SELECT
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;

		SET @end_time = GETDATE ()
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @end_time, @start_time) AS NVARCHAR) + ' seconds'
		PRINT '-----------------------------------';
		SET @end_time_batch = GETDATE()
		PRINT 'Load duration Silver Layer: ' + CAST(DATEDIFF(second, @end_time_batch, @start_time_batch) AS NVARCHAR) + ' seconds'
		PRINT '-----------------------------------';
	END TRY

	BEGIN CATCH
		PRINT '==================================================';
		PRINT 'An error has occured during loading Silver Layer';
		PRINT '==================================================';
		PRINT ERROR_MESSAGE();
		PRINT ERROR_NUMBER();
		PRINT CAST(GETDATE() AS NVARCHAR);
	END CATCH
END







		







	









