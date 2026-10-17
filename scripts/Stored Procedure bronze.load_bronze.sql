/* 
===============================================================================================
Dit script vult alle tabellen uit de Bronze Layer in een Stored Procedure: bronze.load_bronze
===============================================================================================
*/

/* Aanzetten via: EXECUTE bronze.load_bronze */

ALTER PROCEDURE bronze.load_bronze AS

BEGIN
	/* Variabelen maken om te meten hoe lang een load duurt.
	   Via DATEDIFF @End_time - @start_time kunnen we straks de tijd meten. */
	DECLARE @start_time DATETIME, @end_time DATETIME, @start_time_batch DATETIME, @end_time_batch DATETIME;
	BEGIN TRY
		SET @start_time_batch = GETDATE();
		PRINT '===================================';
		PRINT 'Loading Bronze Layer';
		PRINT '===================================';

		PRINT '-----------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '-----------------------------------';


		SET @start_time = GETDATE();
	/* Eerst de bestaande tabel leegmaken om duplicates te voorkomen */
		PRINT '> Truncating Table: bronze.crm_cust_info';
		TRUNCATE TABLE bronze.crm_cust_info
		PRINT '> Inserting Data Into: bronze.crm_cust_info';
		BULK INSERT bronze.crm_cust_info
		FROM 'C:\Users\hielk\OneDrive\BI Projects\Data with Baraa\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
		WITH (
			/* Kijk in de .csv op welke regel de data begint. Hier staan op regel 1 de kolomnamen dus regel 2 begint met de echte data*/
				FIRSTROW = 2,
			/* Kijk wat de delimiter is */
				FIELDTERMINATOR = ',',
			/* Als je een snelle insert wilt de tabel blokkeren tijdens de insert */
				TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @End_time, @Start_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------------------------';

		SET @start_time = GETDATE();
		PRINT '> Truncating Table: bronze.crm_prd_info';
		TRUNCATE TABLE bronze.crm_prd_info
		PRINT '> Inserting Data Into: bronze.crm_prd_info';
		BULK INSERT bronze.crm_prd_info
		FROM 'C:\Users\hielk\OneDrive\BI Projects\Data with Baraa\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @End_time, @Start_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------------------------';

		SET @start_time = GETDATE();
		PRINT '> Truncating Table: bronze.crm_sales_details';
		TRUNCATE TABLE bronze.crm_sales_details
		PRINT '> Inserting Data Into: bronze.crm_sales_details';
		BULK INSERT bronze.crm_sales_details
		FROM 'C:\Users\hielk\OneDrive\BI Projects\Data with Baraa\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @End_time, @Start_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------------------------';

		PRINT '-----------------------------------';
		PRINT 'Loading ERM Tables';
		PRINT '-----------------------------------';

		SET @start_time = GETDATE();
		PRINT 'Truncating Table: bronze.erp_cust_az12';
		TRUNCATE TABLE bronze.erp_cust_az12
		PRINT 'Inserting Data Into: bronze.erp_cust_az12';
		BULK INSERT bronze.erp_cust_az12
		FROM 'C:\Users\hielk\OneDrive\BI Projects\Data with Baraa\sql-data-warehouse-project\datasets\source_erp\cust_az12.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @End_time, @Start_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------------------------';

		SET @start_time = GETDATE();
		PRINT 'Truncating Table: bronze.erp_loc_a101';
		TRUNCATE TABLE bronze.erp_loc_a101
		PRINT 'Inserting Data Into: bronze.erp_loc_a101';
		BULK INSERT bronze.erp_loc_a101
		FROM 'C:\Users\hielk\OneDrive\BI Projects\Data with Baraa\sql-data-warehouse-project\datasets\source_erp\loc_a101.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @End_time, @Start_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------------------------';

		SET @start_time = GETDATE();
		PRINT 'Truncating Table: bronze.erp_px_cat_g1v2';
		TRUNCATE TABLE bronze.erp_px_cat_g1v2
		PRINT 'Inserting Data Into: bronze.erp_px_cat_g1v2';
		BULK INSERT bronze.erp_px_cat_g1v2
		FROM 'C:\Users\hielk\OneDrive\BI Projects\Data with Baraa\sql-data-warehouse-project\datasets\source_erp\px_cat_g1v2.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load duration: ' + CAST(DATEDIFF(second, @End_time, @Start_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------------------------';

		PRINT '===================================';
		PRINT 'Loading Bronze Layer completed';
		PRINT '===================================';
		SET @end_time_batch = GETDATE();
		PRINT 'Load duration Bronze Layer: ' + CAST(DATEDIFF(second, @start_time_batch, @end_time_batch) AS NVARCHAR) + ' seconds';
	END TRY

	BEGIN CATCH
		PRINT '==================================================';
		PRINT 'An error has occured during loading Bronze Layer';
		PRINT '==================================================';
		PRINT ERROR_MESSAGE();
		PRINT ERROR_NUMBER();
		PRINT CAST(GETDATE() AS NVARCHAR);
	END CATCH
END

