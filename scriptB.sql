-- Creacion de la tabla solciitada como solución
CREATE TABLE solution_b(
	fecha DATE,
    semana INT,
    tienda VARCHAR(50),
    branch_tienda VARCHAR(50),
    median_time FLOAT,
    average_time FLOAT,
    0to25_quant_total FLOAT,
    25to40_quant_total FLOAT,
    40to60_quant_total FLOAT,
    60plus_quant_total FLOAT,
    0to25_unique_prod FLOAT,
    25to40_unique_prod FLOAT,
    40to60_unique_prod FLOAT,
    60plus_unique_prod FLOAT,
    PRIMARY KEY(fecha, tienda)
);

-- Vista usada para acceder a los datos que se utilizaran en los calculos
CREATE VIEW store_order_products as
	SELECT DATE(promised_time) as fecha, WEEK(promised_time) as semana, store, orders.store_branch_id, total_minutes
	FROM (orders
	JOIN order_products ON orders.order_id = order_products.order_id)
	JOIN storebranch ON orders.store_branch_id = storebranch.store_branch_id;
    

-- Vista que se utiliza para obtener el promedio de los productos unicos y promedio del total de productos.
-- Se crean las 8 columnas solicitadas
CREATE VIEW unique_and_total_prod as
SELECT avg(case when tiempo<25 then quant_total else null end) as 0to25_quant_total,
		avg(case when tiempo>25 and tiempo<40 then quant_total else null end) as 25to40_quant_total,
		avg(case when tiempo>40 and tiempo<60 then quant_total else null end) as 40to60_quant_total,
		avg(case when tiempo>60 then quant_total else null end) as 60plus_quant_total,
		fecha, store,
        count(case when tiempo<25 then unique_prod else null end)/count(order_id) as 0to25_unique_prod,
		count(case when tiempo>25 and tiempo<40 then unique_prod else null end)/count(order_id) as 25to40_unique_prod,
		count(case when tiempo>40 and tiempo<60 then unique_prod else null end)/count(order_id) as 40to60_unique_prod,
		count(case when tiempo>60 then unique_prod else null end)/count(order_id) as 60plus_unique_prod
		FROM (
				SELECT DATE(promised_time) as fecha, store, orders.order_id, product_id, sum(quantity) as quant_total,1 as unique_prod, AVG(total_minutes) as tiempo
					FROM (orders
					JOIN order_products ON orders.order_id = order_products.order_id)
					JOIN storebranch ON orders.store_branch_id = storebranch.store_branch_id
					group by order_id, product_id) as tt1
		group by fecha,store;


-- Consulta que se encarga del calculo de la mediana
SELECT fecha, store, avg(total_minutes) as median_val FROM (
	SELECT t1.row_number, t1.total_minutes, t1.fecha, t1.store FROM(
	SELECT IF(@prev1!=d.store OR @prev2!=d.fecha , @rownum:=1, @rownum:=@rownum+1) as `row_number`, d.total_minutes, @prev1:=d.store as store, @prev2:=d.fecha AS fecha
	FROM store_order_products d, (SELECT @rownum:=0, @prev:=NULL) r
	ORDER BY fecha, store, total_minutes
	) as t1 INNER JOIN  
	(
	  SELECT count(*) as total_rows, store 
	  FROM store_order_products d
	  GROUP BY fecha,store
	) as t2
	ON t1.store = t2.store
	WHERE 1=1
	AND t1.row_number>=t2.total_rows/2 and t1.row_number<=t2.total_rows/2+1
	)sq
	group by fecha, store;

-- Consulta que se encarga del calculo del promedio.
SELECT fecha, store, AVG(total_minutes) from store_order_products group by fecha,store;


-- Consolidado de todas las consultas y vistas previas que permiten hacer el SELECT que contendrá los datos a insertar en la tabla solicitada.
INSERT INTO solution_b
	SELECT t3.fecha,t3.semana, t3.store, t3.store_branch_id, median_val, promedio,
			0to25_quant_total, 25to40_quant_total, 40to60_quant_total, 60plus_quant_total,
			0to25_unique_prod, 25to40_unique_prod, 40to60_unique_prod, 60plus_unique_prod
	FROM  ((SELECT fecha, store, avg(total_minutes) as median_val FROM (
			SELECT t1.row_number, t1.total_minutes, t1.fecha, t1.store FROM(
			SELECT IF(@prev1!=d.store OR @prev2!=d.fecha , @rownum:=1, @rownum:=@rownum+1) as `row_number`, d.total_minutes, @prev1:=d.store as store, @prev2:=d.fecha AS fecha
			FROM store_order_products d, (SELECT @rownum:=0, @prev:=NULL) r
			ORDER BY fecha, store, total_minutes
			) as t1 INNER JOIN  
			(
			  SELECT count(*) as total_rows, store 
			  FROM store_order_products d
			  GROUP BY fecha,store
			) as t2
			ON t1.store = t2.store
			WHERE 1=1
			AND t1.row_number>=t2.total_rows/2 and t1.row_number<=t2.total_rows/2+1
			)sq
			group by fecha, store) as t1
		JOIN (SELECT fecha, semana, store, store_branch_id, AVG(total_minutes) as promedio from store_order_products group by fecha,store) as t3
		ON t1.fecha = t3.fecha AND t1.store = t3.store)
		JOIN unique_and_total_prod as t4 ON t1.fecha = t4.fecha AND t1.store = t4.store

