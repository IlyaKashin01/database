CREATE DEFINER=`mysql`@`localhost` PROCEDURE `create_order`(
	IN `cargo_name` VARCHAR(50),
	IN `weight_cargo` INT,
	IN `type_cargo` VARCHAR(50),

	IN `dist_km` INT,
	IN `arriv_date` DATE,
	IN `a_point` VARCHAR(50),
	IN `b_point` VARCHAR(50),

	IN `name_of_the_customer` VARCHAR(50),
	IN `pay_method` VARCHAR(20),
	IN `acc_num_client` INT
)
BEGIN
	DECLARE cargo_id, routes_id, refill_id, decoration_id, fare_id, payment_id, transport_id, num_driver INT;
	DECLARE refill_cost, res_cost DECIMAL(10,2);
	DECLARE depart_date DATE;
	DECLARE t_refill DATETIME;
	
	INSERT INTO cargo (name_cargo, cargo_weight, cargo_type) VALUES (cargo_name, weight_cargo, type_cargo);
	SET cargo_id = (SELECT LAST_INSERT_ID());

   SET transport_id = (SELECT id FROM transport WHERE  (location = 'Свободен') AND (weight_cargo >= load_capacity) LIMIT	1);
	SET num_driver = (SELECT id FROM drivers WHERE number_transport  =  transport_id);
	SET depart_date = (arriv_date - INTERVAL(ROUND(dist_km / 70,0)) DAY);   
	
	INSERT INTO routes (number_driver, distance_km, departure_date, arrival_date, departure_point, arrival_point, cargo) VALUES (num_driver, dist_km, depart_date, arriv_date, a_point, b_point, cargo_id);
	SET routes_id = (SELECT LAST_INSERT_ID());
	
	SET refill_cost = ROUND(dist_km / 100 * (SELECT fuel_consumption FROM transport WHERE id = transport_id ), 0) * (SELECT price FROM fuel WHERE brand = (SELECT brand_fuel FROM transport WHERE id = transport_id));
	SET t_refill =(SELECT DATE_FORMAT(FROM_UNIXTIME(RAND() * (UNIX_TIMESTAMP(depart_date) - UNIX_TIMESTAMP(depart_date - INTERVAL 1 DAY)) + UNIX_TIMESTAMP(depart_date - INTERVAL 1 DAY)), '%Y-%m-%d %h:%m')) ;
	
	INSERT INTO refill (brand_fuel, price, count_fuel, number_receipt, time_refill, total_cost) VALUES (br_fuel, cost, quantity_fuel, FLOOR(RAND()*(1000-1)), t_refill, refill_cost);
	SET refill_id = (SELECT LAST_INSERT_ID());

	UPDATE routes SET refueling_the_car = refill_id WHERE id = routes_id;

	SET fare_id = (SELECT id FROM `fares` WHERE weight_from <= weight_cargo AND weight_to >= weight_cargo);
   SET res_cost = refill_cost + (dist_km * (SELECT fare_cost FROM `fares` WHERE weight_from <= weight_cargo AND weight_to >= weight_cargo));
   
	INSERT INTO decoration (name_of_the_customer, transport, payment_method, cargo, route, car_refueling, fare, total_cost) VALUES (name_of_the_customer, transport_id, pay_method, cargo_id, routes_id, refill_id, fare_id, res_cost);
	SET decoration_id = (SELECT LAST_INSERT_ID());
	
	INSERT INTO payment (account_number_client, account_number_businesses, payment_method, amount_to_be_paid) VALUES (acc_num_client, 3154978565876588, pay_method, res_cost);
	SET payment_id = (SELECT LAST_INSERT_ID());

   UPDATE decoration SET receipt_number = payment_id WHERE id = decoration_id;
   UPDATE cargo, payment, refill, routes SET cargo.id_decoration = decoration_id, payment.id_decoration = decoration_id, refill.id_decoration = decoration_id, routes.id_decoration = decoration_id;
END;
