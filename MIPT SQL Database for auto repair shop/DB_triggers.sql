 exec sp_configure 'nested triggers', 0
 reconfigure;


 DROP TRIGGER IF EXISTS exp_ins_upd_MO
 DROP TRIGGER IF EXISTS exp_del_MO
 DROP TRIGGER IF EXISTS exp_upd_M

 
/*Пересчет стажа как разности между первым и последним заказом после добавления или обновления строк*/

CREATE TRIGGER exp_ins_upd_MO ON mechanics_orders
	AFTER INSERT, UPDATE
	AS
				update mechanics
				SET mechanics.experience_months = 
				(
					SELECT DATEDIFF
				(
					DAY, 
				(
					SELECT MIN(accepted) FROM orders JOIN
					mechanics_orders ON orders.order_id = mechanics_orders.order_id JOIN
					mechanics ON mechanics_orders.mechanic_id = mechanics.employee_id JOIN
					inserted ON inserted.mechanic_id = mechanics.employee_id
				), 
				(	
					SELECT MAX(real_end) FROM orders JOIN
					mechanics_orders ON orders.order_id = mechanics_orders.order_id JOIN
					mechanics ON mechanics_orders.mechanic_id = mechanics.employee_id JOIN
					inserted ON inserted.mechanic_id = mechanics.employee_id
				)
				)/30 
				)
				WHERE mechanics.employee_id IN (SELECT mechanic_id from inserted) 
				
/*ПРОВЕРКА*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
BEGIN TRANSACTION
	SELECT * FROM mechanics
	INSERT INTO orders VALUES (50025, 10020, 40009, 115111, '2020-01-20','2020-01-01','2020-03-29')
	INSERT INTO orders VALUES (50026, 10020, 40009, 115111, '2020-01-20','2020-01-01','2020-03-29')
	INSERT INTO orders VALUES (50027, 10020, 40009, 115111, '2020-01-20','2020-01-01','2020-03-29')
	INSERT INTO mechanics_orders VALUES(40002,50025)
		INSERT INTO mechanics_orders VALUES(40003,50026)
			INSERT INTO mechanics_orders VALUES(40004,50027)
	SELECT * FROM mechanics
rollback;


/*Аналогичный триггер, срабатывающий при удалении строк*/

CREATE TRIGGER exp_del_MO ON mechanics_orders
	AFTER DELETE
	AS
			update mechanics
			SET mechanics.experience_months = 
			(
				SELECT DATEDIFF
			(
				DAY, 
			(
				SELECT MIN(accepted) FROM orders JOIN
				mechanics_orders ON orders.order_id = mechanics_orders.order_id JOIN
				mechanics ON mechanics_orders.mechanic_id = mechanics.employee_id
			),
			(	
				SELECT MAX(real_end) FROM orders JOIN
				mechanics_orders ON orders.order_id = mechanics_orders.order_id JOIN
				mechanics ON mechanics_orders.mechanic_id = mechanics.employee_id
			)
			)/30 
			)
			WHERE mechanics.employee_id IN (SELECT  mechanic_id from deleted) 

/*ПРОВЕРКА*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
BEGIN TRAN
SELECT * FROM mechanics_orders
select * from mechanics

delete from mechanics_orders where order_id in (select top 25 order_id from mechanics_orders)

select * from mechanics_orders
select * from mechanics
ROLLBACK


/*триггер, не позволяющий напрямую обновить стаж, но позволяющий обновлять остальные поля таблицы mechanics*/

CREATE TRIGGER exp_upd_M ON mechanics
	AFTER UPDATE 
		AS 
			IF ((SELECT TOP 1 experience_months FROM deleted) IS NOT NULL)
				BEGIN
					
						UPDATE mechanics 
						SET mechanics.experience_months = 
						(
						SELECT experience_months FROM deleted WHERE mechanics.employee_id = deleted.employee_id
						) 
						WHERE mechanics.employee_id IN (SELECT employee_id from deleted) 
						
					PRINT 'INCORRECT UPDATE. Experince has been kept as the difference between the first and the last order'
				END

/*ПРОВЕРКА*/ 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
BEGIN TRANSACTION
	SELECT * FROM mechanics
	update mechanics
	set experience_months = 10, category=10 WHERE mechanics.employee_id = (select top 1 employee_id from mechanics)
	SELECT * FROM mechanics
rollback
