	1. /*представления для заказов*/

DROP VIEW IF EXISTS orders_clients_vehicles;
GO
CREATE VIEW orders_clients_vehicles AS 

	WITH vehicles_orders AS (
	SELECT subservices_orders_vehicles.order_id, vehicles.model_name AS vehicle 
	FROM subservices_orders_vehicles 
	JOIN client_vehicles ON subservices_orders_vehicles.vehicle_id = client_vehicles.vehicle_id
	JOIN vehicles ON client_vehicles.model_id = vehicles.model_id
	GROUP BY subservices_orders_vehicles.order_id, vehicles.model_name
	)

	SELECT vehicles_orders.order_id, clients.last_name, clients.phone, STRING_AGG(vehicles_orders.vehicle, ', ') AS VehiclesInOrder, orders.total_cost
	FROM vehicles_orders 
	JOIN orders ON vehicles_orders.order_id = orders.order_id
	JOIN clients ON clients.client_id = orders.client_id
	GROUP BY vehicles_orders.order_id, clients.last_name, clients.phone, orders.total_cost
GO
select * from orders_clients_vehicles 
WHERE VehiclesInOrder LIKE('%Mercedes%')


	2. /*представление для владельца, всех его автомобилей и сумарной стоимости и времени ремонта*/

DROP VIEW IF EXISTS clients_vehicles_total;
GO

CREATE VIEW clients_vehicles_total AS

WITH c_v AS(
SELECT client_vehicles.client_id, STRING_AGG(vehicles.model_name, ', ') AS vehicles
FROM client_vehicles 
JOIN vehicles ON client_vehicles.model_id = vehicles.model_id
GROUP BY client_vehicles.client_id
)

SELECT clients.last_name, c_v.vehicles, 
SUM(total_cost) AS total, 
SUM(DATEDIFF(DAY, accepted, real_end)) AS total_time
FROM 
c_v 
JOIN clients ON c_v.client_id = clients.client_id 
JOIN orders ON c_v.client_id = orders.client_id
GROUP BY clients.last_name, c_v.vehicles
GO 

SELECT last_name FROM clients_vehicles_total WHERE total > 5000


	3. /*автомеханик, дней работы над заказами начатыми в феврале и их общая стоимость*/

DROP VIEW IF EXISTS M;
GO
CREATE VIEW  M AS 

SELECT mechanics.last_name, mechanics.category, 
SUM(DATEDIFF(day, accepted, real_end)) AS time, SUM(total_cost) AS total
FROM mechanics_orders 
JOIN mechanics ON mechanics.employee_id = mechanics_orders.mechanic_id
JOIN orders ON orders.order_id = mechanics_orders.order_id
WHERE DATEPART(MONTH, accepted)='02'
GROUP BY last_name, mechanics.category
GO

SELECT STRING_AGG(last_name, ', ') AS mechanics, 
SUM(time) AS total_time, 
SUM(total) AS total
FROM M WHERE category=1 


	4. /*модель, все владельцы, число раз, когда время ремонта превышало 3 дня*/

DROP VIEW IF EXISTS C;
GO
CREATE VIEW C AS

WITH v_c AS(
SELECT vehicles.model_name, vehicles.model_id, STRING_AGG(clients.last_name,  ', ') AS owners
FROM vehicles 
JOIN client_vehicles ON vehicles.model_id = client_vehicles.model_id
JOIN clients ON clients.client_id = client_vehicles.client_id
GROUP BY vehicles.model_name, vehicles.model_id
),

o_m AS(
SELECT orders.order_id, client_vehicles.model_id, 
DATEDIFF(DAY, accepted, real_end) AS time
FROM orders
JOIN clients ON orders.client_id = clients.client_id
JOIN client_vehicles ON clients.client_id = client_vehicles.client_id
GROUP BY order_id, client_vehicles.model_id, accepted, real_end
)

SELECT v_c.model_name, v_c.owners, COUNT(*) as times
FROM o_m 
JOIN v_c ON o_m.model_id = v_c.model_id
WHERE time>3
GROUP BY v_c.model_name, v_c.owners
GO
SELECT * FROM C WHERE model_name LIKE('%toyota%') AND times > 2