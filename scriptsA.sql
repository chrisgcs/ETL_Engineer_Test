-- Creacion de la tabla solicitada

CREATE TABLE solution(
	fecha DATE,
    semana INT,
    tienda VARCHAR(50),
    branch_tienda VARCHAR(50),
    average_dist FLOAT,
    median_dist FLOAT,
    0to10 FLOAT,
    10to15 FLOAT,
    15to20 FLOAT,
    20plus FLOAT,
    PRIMARY KEY(fecha, tienda)
);
        
-- Calculo de la distancia Manhattan realizando la conversion de latitud y longitud a KM
-- https://www.databasejournal.com/features/mysql/mysql-calculating-distance-based-on-latitude-and-longitude.html

CREATE VIEW manhattan_distance as
	SELECT fecha, WEEKOFYEAR(fecha) as semana, store, store_branch_id, shopper_id ,manhattan as distance
				FROM (SELECT (6367 * acos( cos( radians(orders.lat) ) 
					* cos( radians(storebranch.lat) ) 
					* cos( radians(storebranch.lng) - radians(orders.lng)) + sin(radians(orders.lat))
					* sin( radians(storebranch.lat) ))) as manhattan,
					DATE(promised_time) as fecha, orders.store_branch_id, shopper_id,store
					FROM orders
					JOIN storebranch ON orders.store_branch_id = storebranch.store_branch_id) as tabla_manhattan;
                    
                    
-- Calculo del rango al de distancia en KM al que pertenece cada shopper segun las ordenes realizadas.
-- Se calcula el promedio de la distancia del dia en caso que el shopper haya realizado mas una orden el mismo dia.
CREATE VIEW avg_shopper_dist as
	SELECT  count(case when avg_dist<10 then 1 else null end)/count(*) as 0to10,
			count(case when avg_dist>10 and avg_dist<15 then 1 else null end)/count(*) as 10to15,
			count(case when avg_dist>15 and avg_dist<20 then 1 else null end)/count(*) as 15to20,
			count(case when avg_dist>20 then 1 else null end)/count(*) as 20plus,
			shopper_id ,fecha, WEEKOFYEAR(fecha) as semana, store, avg_dist
			FROM (SELECT fecha, store, shopper_id, avg(distance) as avg_dist FROM manhattan_distance GROUP BY shopper_id) as avg_shopper
			GROUP BY shopper_id;

SELECT DATE(t11.fecha) as fecha, t11.semana, t11.store, t11.store_branch_id, t11.promedio, t22.median_val, to10, to15, to20, plus20
 FROM (((SELECT fecha, semana, store, store_branch_id, AVG(distance) as promedio from manhattan_distance group by fecha,store) as t11
 JOIN (SELECT fecha, store, sum(0to10)/count(*) as to10, sum(10to15)/count(*) as to15 , sum(15to20)/count(*) as to20, sum(20plus)/count(*)as plus20 FROM avg_shopper_dist GROUP BY fecha,store) as t33
 ON t11.fecha = t33.fecha AND t11.store = t33.store)
 JOIN ( 
 -- Calculo de la mediana agruapada por fecha y tienda
		SELECT fecha, store, avg(distance) as median_val FROM (
		SELECT t1.row_number, t1.distance, t1.fecha, t1.store FROM(
		SELECT IF(@prev1!=d.store OR @prev2!=d.fecha, @rownum:=1, @rownum:=@rownum+1) as `row_number`, d.distance, @prev1:=d.store as store, @prev2:=d.fecha AS fecha
		FROM manhattan_distance d, (SELECT @rownum:=0, @prev:=NULL) r
		ORDER BY fecha, store, distance
		) as t1 INNER JOIN  
		(
		  SELECT count(*) as total_rows, store 
		  FROM manhattan_distance d
		  GROUP BY fecha,store
		) as t2
		ON t1.store = t2.store
		WHERE 1=1
		AND t1.row_number>=t2.total_rows/2 and t1.row_number<=t2.total_rows/2+1
		)sq
		group by fecha, store) as t22 ON t11.fecha =t22.fecha AND t11.store = t22.store);


-- Insert de la data calculada en la tabla solicitada
-- Al ejecutar me arrojo warnings debido a la declaracion de variables dentro
-- 		de la consulta, pero no me fue posible hacer el calculo de la mediana de otra forma
INSERT INTO solution
	SELECT DATE(t11.fecha) as fecha, t11.semana, t11.store, t11.store_branch_id, t11.promedio, t22.median_val, to10, to15, to20, plus20
	 FROM (((SELECT fecha, semana, store, store_branch_id, AVG(distance) as promedio from manhattan_distance group by fecha,store) as t11
	 JOIN (SELECT fecha, store, sum(0to10)/count(*) as to10, sum(10to15)/count(*) as to15 , sum(15to20)/count(*) as to20, sum(20plus)/count(*)as plus20 FROM avg_shopper_dist GROUP BY fecha,store) as t33
	 ON t11.fecha = t33.fecha AND t11.store = t33.store)
	 JOIN ( 
	 -- Calculo de la mediana agruapada por fecha y tienda
			SELECT fecha, store, avg(distance) as median_val FROM (
			SELECT t1.row_number, t1.distance, t1.fecha, t1.store FROM(
			SELECT IF(@prev!=d.store, @rownum:=1, @rownum:=@rownum+1) as `row_number`, d.distance, @prev:=d.fecha as fecha, @prev:=d.store AS store
			FROM manhattan_distance d, (SELECT @rownum:=0, @prev:=NULL) r
			ORDER BY fecha, store, distance
			) as t1 INNER JOIN  
			(
			  SELECT count(*) as total_rows, store 
			  FROM manhattan_distance d
			  GROUP BY store
			) as t2
			ON t1.store = t2.store
			WHERE 1=1
			AND t1.row_number>=t2.total_rows/2 and t1.row_number<=t2.total_rows/2+1
			)sq
			group by fecha, store) as t22 ON t11.fecha =t22.fecha AND t11.store = t22.store);