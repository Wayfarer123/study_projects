		/*SELECT-Ы*/	
	
	1. /*количество дней когда механики отсутствовали на работе*/
SELECT employee_absence.employee_id, SUM(DATEDIFF(dd, start, ending)) 
FROM employee_absence, mechanics 	
WHERE employee_absence.employee_id = mechanics.employee_id
GROUP BY employee_absence.employee_id;


	2. /*Механик(и), работавшие с в сумме самыми дорогими заказами на единственную машину марки lexus от клиентов с фамилией на "У"*/

WITH vehicles_orders AS (
SELECT order_id, vehicle_id 
FROM subservices_orders_vehicles
GROUP BY order_id, vehicle_id
),

orders_vehicles_count AS(
SELECT order_id, COUNT (*) 
AS quantity FROM vehicles_orders
GROUP BY order_id
), 

distinct_vehicle_orders AS(
SELECT orders_vehicles_count.order_id, vehicle_id 
FROM orders_vehicles_count 
JOIN subservices_orders_vehicles ON orders_vehicles_count.order_id = subservices_orders_vehicles. order_id
WHERE orders_vehicles_count.quantity = 1
GROUP BY orders_vehicles_count.order_id, vehicle_id
),

orders_lexus_sum (order_id, total, client_id) AS (
SELECT distinct_vehicle_orders.order_id, total_cost, orders.client_id FROM orders 
JOIN distinct_vehicle_orders ON orders.order_id = distinct_vehicle_orders.order_id
JOIN client_vehicles ON client_vehicles.vehicle_id = distinct_vehicle_orders.vehicle_id
JOIN vehicles ON client_vehicles.model_id = vehicles.model_id
WHERE vehicles.model_name LIKE('%lexus%')
GROUP BY distinct_vehicle_orders.order_id, total_cost, orders.client_id
)

SELECT TOP 1 WITH TIES employee.employee_id, employee.last_name, 
SUM(orders_lexus_sum.total) AS orders_total 
FROM orders_lexus_sum 
JOIN mechanics_orders ON orders_lexus_sum.order_id = mechanics_orders.order_id
JOIN employee ON mechanics_orders.mechanic_id = employee.employee_id
JOIN clients ON orders_lexus_sum.client_id = clients.client_id
WHERE clients.last_name LIKE('У%')
GROUP BY employee.employee_id, employee.last_name
ORDER BY orders_total DESC


	3. /*запчасти использованные в последних 5-ти заказах*/

WITH last_orders AS(
SELECT TOP 5 WITH TIES orders.order_id, orders.accepted FROM orders
ORDER BY orders.accepted
)

SELECT last_orders.order_id, subservices_specs.part_id, subservices_specs.quantity FROM subservices_specs 
JOIN subservices ON subservices_specs.subservice_id = subservices.subservice_id
JOIN subservices_orders_vehicles ON subservices.subservice_id = subservices_orders_vehicles.subservice_id
JOIN last_orders ON subservices_orders_vehicles.order_id = last_orders.order_id
GROUP BY last_orders.order_id, subservices_specs.part_id, subservices_specs.quantity


	4. /*механики по количеству выполненных подуслуг за последний год*/

WITH mechanics_orders_lastyear AS(
SELECT mechanic_id, mechanics_orders.order_id
FROM mechanics_orders
JOIN orders ON mechanics_orders.order_id = orders.order_id 
WHERE DATEDIFF(MONTH, accepted, CAST(GETDATE() AS DATE)) < 12
),

mechanics_subservices_lastyear AS(
SELECT mechanics_orders_lastyear.mechanic_id, subservices_orders_vehicles.subservice_id 
FROM mechanics_orders_lastyear
JOIN subservices_orders_vehicles ON mechanics_orders_lastyear.order_id = subservices_orders_vehicles.order_id
GROUP BY subservices_orders_vehicles.subservice_id, mechanics_orders_lastyear.mechanic_id
)

SELECT mechanics_subservices_lastyear.mechanic_id, last_name, COUNT(*) AS subservices_quantity
FROM mechanics_subservices_lastyear
JOIN mechanics ON mechanics_subservices_lastyear.mechanic_id = mechanics.employee_id
JOIN subservices ON mechanics_subservices_lastyear.subservice_id = subservices.subservice_id
GROUP BY mechanics_subservices_lastyear.mechanic_id, last_name
ORDER BY subservices_quantity DESC

	5. /*фамилия хозяина, чаще всего посещающего мастерскую и имеющего автомобиль марки mercedes*/

WITH clients_mercedes AS(
SELECT clients.client_id, last_name 
FROM clients
JOIN client_vehicles ON clients.client_id = client_vehicles.client_id 
JOIN vehicles ON vehicles.model_id = client_vehicles.model_id
WHERE vehicles.model_name LIKE('%mercedes%')
)

SELECT TOP 1 WITH TIES clients_mercedes.client_id, clients_mercedes.last_name, COUNT(*) as quantity 
FROM clients_mercedes 
JOIN clients ON clients_mercedes.client_id = clients.client_id
GROUP BY clients_mercedes.client_id, clients_mercedes.last_name 
ORDER BY quantity

	6. /*средняя сумма заказов по механикам, в которых одна из услуг - кузовной ремонт, принятых в феврале-марте*/


SELECT mechanics.last_name, AVG(orders.total_cost) AS average_cost 
FROM mechanics LEFT JOIN mechanics_orders ON mechanics.employee_id = mechanics_orders.mechanic_id
JOIN orders ON orders.order_id = mechanics_orders.order_id
JOIN service_orders ON orders.order_id = service_orders.order_id
JOIN services ON service_orders.service_id = services.service_id 
WHERE service LIKE('%кузовной ремонт%') 
AND orders.accepted > '2020.01.31' 
AND orders.accepted < '2020.04.01'
GROUP BY mechanics.last_name 


		/*DELETE-Ы*/

	1. /*удаление информации о заказах завершенных раньше февраля механиками первой категории*/

DELETE orders FROM orders
JOIN mechanics_orders ON orders.order_id = orders.order_id
JOIN mechanics ON mechanics_orders.mechanic_id = mechanics.employee_id
WHERE mechanics.category = '1' AND real_end <'2020.02.02'

	2./*удаление информации из родительской таблицы employee, вызывающее срабатывание ограничения внешнего ключа таблицы orders*/

DELETE FROM employee WHERE salary < 100000

	3. /*удаление из таблицы работников всех механиков второй категории, отсутствовавших на работе больше 10 дней и выполнивших заказов меньше чем на 10000*/

DELETE employee 
FROM employee 
JOIN mechanics ON employee.employee_id = mechanics.employee_id
JOIN employee_absence ON employee.employee_id = employee_absence.employee_id
JOIN mechanics_orders ON mechanics.employee_id = mechanics_orders.mechanic_id
JOIN (
SELECT employee_id, SUM(DATEDIFF(DAY, start, ending)) as absence
FROM employee_absence GROUP BY employee_id
) AS t1 ON t1.employee_id = employee.employee_id
JOIN (
SELECT mechanic_id, SUM(total_cost) AS total 
FROM mechanics_orders 
JOIN orders ON mechanics_orders.order_id = orders.order_id
GROUP BY mechanic_id
) AS t2 ON t2.mechanic_id = employee.employee_id
WHERE t2.total < 50000 
AND t1.absence < 30 
AND mechanics.category = 2

		/*UPDATE-Ы*/
	1. /*повышение зарплаты механикам 2 категории с суммой заказов больше 20000 и первой - больше 30000 на 20%*/

WITH mechanics_additional AS(
SELECT SUM(total_cost) AS total, mechanics.employee_id, category 
FROM mechanics
JOIN mechanics_orders ON mechanics.employee_id = mechanics_orders.mechanic_id
JOIN orders ON mechanics_orders.order_id = orders.order_id
GROUP BY mechanics.employee_id, category
)

UPDATE employee
SET salary = salary*1.2 
WHERE (
(SELECT total FROM mechanics_additional
WHERE employee.employee_id = mechanics_additional.employee_id
AND category = 1
AND employee_id = mechanics_additional.employee_id
) >= 30000
)
OR (
(SELECT total FROM mechanics_additional
WHERE employee.employee_id = mechanics_additional.employee_id
AND category = 2
AND employee_id = mechanics_additional.employee_id
) >= 20000 
)

	2. /*изменение id механиков, ссылающегося на родительскую таблицу с работниками, вызывающее нарушение целостности*/

UPDATE mechanics
SET employee_id = employee_id + 11100 - (SELECT TOP 1 employee_id FROM mechanics)


	3. /*изменения вида id заказа с 5**** на  17*** */

UPDATE orders
SET order_id = order_id + 17001 - (SELECT TOP 1 order_id FROM orders)
