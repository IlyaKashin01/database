

DELIMITER //
--
-- Процедуры
--
CREATE PROCEDURE `add_driver` (IN `numberper` INT, IN `name_driver` VARCHAR(50), IN `date_of_receipt` DATE)  
BEGIN

DECLARE count_year , num_tr INT;
DECLARE payday, exp DECIMAL;

SET count_year = (YEAR(CURRENT_DATE) - YEAR(date_of_receipt)) - (DATE_FORMAT(CURRENT_DATE, '%m%d') < DATE_FORMAT(date_of_receipt, '%m%d'));

SET num_tr = (SELECT id FROM transport WHERE location = 'На стоянке' LIMIT 1); 
INSERT INTO drivers (full_name, date_of_receipt_driver_license, driving_experience, status_driver, number_transport, personal_number, salary) 
             VALUES (name_driver, date_of_receipt, count_year, 'Свободен', num_tr, numberper, 20000);
UPDATE transport SET location = 'Свободен' WHERE id = num_tr;

SET payday =  (SELECT salary AS `VALUE` FROM drivers WHERE id = (SELECT LAST_INSERT_ID()));
SET exp = (SELECT driving_experience AS `VALUE` FROM drivers WHERE id = (SELECT LAST_INSERT_ID()));

IF (SELECT driving_experience AS `VALUE` FROM drivers WHERE id = (SELECT LAST_INSERT_ID())) > 20 THEN 
	UPDATE drivers SET salary = (1000 * 20) + payday WHERE  id = (SELECT LAST_INSERT_ID());
ELSE

UPDATE drivers SET salary = ((1000*exp) + payday) WHERE id = (SELECT LAST_INSERT_ID());

END IF;
END; //

CREATE PROCEDURE `create_order` (
  IN `cargo_name` VARCHAR(50), 
  IN `weight_cargo` INT, 
  IN `type_cargo` VARCHAR(50), 
  IN `dist_km` INT, 
  IN `arriv_date` DATE, 
  IN `a_point` VARCHAR(50), 
  IN `b_point` VARCHAR(50), 
  IN `name_customer` VARCHAR(50), 
  IN `pay_method` VARCHAR(20), 
  IN `acc_num_client` INT)   
  BEGIN
	DECLARE cargo_id, routes_id, refill_id, decoration_id, fare_id, payment_id, transport_id, num_driver, id_f, count_f INT;
	DECLARE refill_cost, res_cost DECIMAL(10,2);
	DECLARE depart_date DATE;
	DECLARE t_refill DATETIME;
	
	INSERT INTO cargo (name_cargo, cargo_weight, cargo_type) VALUES (cargo_name, weight_cargo, type_cargo);
	SET cargo_id = (SELECT LAST_INSERT_ID());

  SET transport_id = (SELECT id FROM transport WHERE  (location = 'Свободен') AND (load_capacity >= weight_cargo) LIMIT 1);
	SET num_driver = (SELECT id FROM drivers WHERE number_transport  =  transport_id);
	SET depart_date = (arriv_date - INTERVAL(ROUND(dist_km / 70,0)) DAY);   
	
	INSERT INTO routes (number_driver, distance_km, departure_date, arrival_date, departure_point, arrival_point, cargo) VALUES (num_driver, dist_km, depart_date, arriv_date, a_point, b_point, cargo_id);
	SET routes_id = (SELECT LAST_INSERT_ID());
	
  SET id_f  = (SELECT brand_fuel FROM transport WHERE id = transport_id);
  SET count_f = ROUND(dist_km / 100 * (SELECT fuel_consumption FROM transport WHERE id = transport_id ), 0);
	SET refill_cost = count_f * (SELECT price FROM fuel WHERE id = (SELECT brand_fuel FROM transport WHERE id = transport_id));
	SET t_refill =(SELECT DATE_FORMAT(FROM_UNIXTIME(RAND() * (UNIX_TIMESTAMP(depart_date) - UNIX_TIMESTAMP(depart_date - INTERVAL 1 DAY)) + UNIX_TIMESTAMP(depart_date - INTERVAL 1 DAY)), '%Y-%m-%d %h:%m')) ;
	
	INSERT INTO refill (id_fuel, count_fuel, number_receipt, time_refill, total_cost) VALUES (id_f, count_f, FLOOR(RAND()*(1000-1)), t_refill, refill_cost);
	SET refill_id = (SELECT LAST_INSERT_ID());

	UPDATE routes SET refueling_the_car = refill_id WHERE id = routes_id;

	SET fare_id = (SELECT id FROM `fares` WHERE weight_from <= weight_cargo AND weight_to >= weight_cargo);
  SET res_cost = refill_cost + (dist_km * (SELECT fare_cost FROM `fares` WHERE weight_from <= weight_cargo AND weight_to >= weight_cargo));
   
	INSERT INTO decoration (name_of_the_customer, transport, payment_method, cargo, route, car_refueling, fare, total_cost) VALUES (name_customer, transport_id, pay_method, cargo_id, routes_id, refill_id, fare_id, res_cost);
	SET decoration_id = (SELECT LAST_INSERT_ID());
	
	INSERT INTO payment (account_number_client, account_number_businesses, payment_method, amount_to_be_paid) VALUES (acc_num_client, 1154978565, pay_method, res_cost);
	SET payment_id = (SELECT LAST_INSERT_ID());

  UPDATE decoration SET receipt_number = payment_id WHERE id = decoration_id;
  UPDATE cargo, payment, refill, routes SET cargo.id_decoration = decoration_id, payment.id_decoration = decoration_id, refill.id_decoration = decoration_id, routes.id_decoration = decoration_id;
	
END$$

CREATE DEFINER=`mysql`@`localhost` PROCEDURE `get_statistic` ()  BEGIN
 
SELECT
        drivers.full_name,
        drivers.id,
        COUNT(routes.id) AS routes_count
    FROM routes
    LEFT JOIN drivers ON drivers.id = routes.number_driver
    GROUP BY routes.number_driver;

SELECT brand, type_auto, Location FROM transport;

SELECT COUNT(receipt_number), SUM(total_cost) FROM decoration;

END$$

CREATE DEFINER=`mysql`@`localhost` PROCEDURE `search` (IN `name_for_search` VARCHAR(50))  BEGIN

SELECT * FROM decoration WHERE name_of_the_customer = name_for_search;

END$$

--
-- Функции
--
CREATE DEFINER=`mysql`@`localhost` FUNCTION `calcprofit` () RETURNS DECIMAL(10,2) NO SQL
    DETERMINISTIC
BEGIN 

DECLARE sum_sm , sum_salary, sum_order, profit DECIMAL(10,2);

SET sum_sm = (SELECT SUM(cost_of_work) FROM sm); 
SET sum_salary = (SELECT SUM(salary) FROM drivers);
SET sum_order = (SELECT SUM(total_cost) FROM decoration);

SET profit = sum_order - sum_sm - sum_salary;
RETURN profit;

END$$

CREATE DEFINER=`mysql`@`localhost` FUNCTION `calculate` () RETURNS VARCHAR(100) CHARSET utf8 NO SQL
BEGIN 

DECLARE res_info VARCHAR(100);
DECLARE count_cargo, total_weight, count_dec, max_path, total_km INT;

SET count_cargo = (SELECT COUNT(name_cargo) FROM cargo);
SET total_weight = (SELECT SUM(cargo_weight) FROM cargo);
SET count_dec = (SELECT COUNT(receipt_number) FROM decoration);
SET max_path = (SELECT MAX(distance_km) FROM routes);
SET total_km = (SELECT SUM(distance_km) FROM routes);

SET res_info = (SELECT CONCAT('count_cargo=', count_cargo, '; total_weight=', total_weight, '; count_dec=', count_dec, '; max_path=', max_path, '; =total_km', total_km)); 
RETURN res_info;

END$$

CREATE DEFINER=`mysql`@`localhost` FUNCTION `calc_new_salary` (`payday` DECIMAL(10,0)) RETURNS VARCHAR(50) CHARSET utf8 BEGIN 

UPDATE drivers SET salary = payday + (drivers.driving_experience * 1000) WHERE 1;


RETURN 'successfully';


END$$

CREATE DEFINER=`mysql`@`localhost` FUNCTION `delete_decoration` (`id_order` INT) RETURNS VARCHAR(50) CHARSET utf8 NO SQL
BEGIN 
DECLARE id_cargo, id_route, id_refill, id_payment INT; 
DECLARE res_delete VARCHAR(50); 

IF (SELECT id FROM decoration WHERE id = id_order) IS NULL  THEN 

SET res_delete = 'There is no such order'; 

ELSE 

DELETE FROM decoration WHERE id = id_order; 
 
SET res_delete = (SELECT concat( 'Order #', id_order, ' successfully deleted')); 

END IF; 
RETURN res_delete; 
END$$

DELIMITER ;


CREATE TABLE `cargo` (
  `id` int(11) NOT NULL,
  `Name_cargo` varchar(50) DEFAULT NULL,
  `Cargo_weight` int(11) DEFAULT NULL,
  `Cargo_type` varchar(50) DEFAULT NULL,
  `id_decoration` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `decoration` (
  `id` int(11) NOT NULL,
  `name_of_the_customer` varchar(50) DEFAULT NULL,
  `cargo` int(11) DEFAULT NULL,
  `transport` int(11) DEFAULT NULL,
  `route` int(11) DEFAULT NULL,
  `fare` int(11) DEFAULT NULL,
  `car_refueling` int(11) DEFAULT NULL,
  `total_cost` decimal(10,0) DEFAULT NULL,
  `payment_method` varchar(20) DEFAULT NULL,
  `receipt_number` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `drivers` (
  `id` int(11) NOT NULL,
  `full_name` varchar(50) DEFAULT NULL,
  `date_of_receipt_driver_license` date DEFAULT NULL,
  `driving_experience` int(11) DEFAULT NULL,
  `status_driver` varchar(20) DEFAULT NULL,
  `number_transport` int(11) DEFAULT NULL,
  `personal_number` int(11) DEFAULT NULL,
  `salary` decimal(10,0) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `fares` (
  `id` int(11) NOT NULL,
  `fares_name` varchar(50) NOT NULL,
  `weight_from` int(11) NOT NULL,
  `weight_to` int(11) NOT NULL,
  `fares_cost` decimal(10,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



CREATE TABLE `fuel` (
  `id` int(11) NOT NULL,
  `brand` varchar(10) NOT NULL,
  `price` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `payment` (
  `id` int(11) NOT NULL,
  `id_decoration` int(11) DEFAULT NULL,
  `payment_method` varchar(20) DEFAULT NULL,
  `account_number_client` int(11) DEFAULT NULL,
  `amount_to_be_paid` decimal(10,0) DEFAULT NULL,
  `account_number_businesses` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



CREATE TRIGGER `tr_for_payment` AFTER INSERT ON `payment` FOR EACH ROW BEGIN

DECLARE id_driver, id_transport INT(11);

SET id_driver = (SELECT number_driver FROM routes WHERE id = (SELECT route FROM decoration WHERE id = (SELECT id FROM payment WHERE id = (SELECT LAST_INSERT_ID())) ) );
SET id_transport = (SELECT transport FROM decoration WHERE id = (SELECT id FROM payment WHERE id = (SELECT LAST_INSERT_ID())) ) ;


UPDATE drivers SET status_driver = 'Занят' WHERE id = id_driver;
UPDATE transport SET location = 'В пути' WHERE id = id_transport;

END; 


CREATE TABLE `refill` (
  `id` int(11) NOT NULL,
  `Brand_fuel` varchar(20) DEFAULT NULL,
  `Price` decimal(10,2) DEFAULT NULL,
  `Time_refill` datetime DEFAULT NULL,
  `Count_fuel` int(11) DEFAULT NULL,
  `Total_cost` decimal(10,0) DEFAULT NULL,
  `Number_receipt` int(11) DEFAULT NULL,
  `id_decoration` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



CREATE TABLE `routes` (
  `id` int(11) NOT NULL,
  `number_driver` int(11) DEFAULT NULL,
  `departure_date` date DEFAULT NULL,
  `arrival_date` date DEFAULT NULL,
  `departure_point` varchar(50) DEFAULT NULL,
  `arrival_point` varchar(50) DEFAULT NULL,
  `distance_km` int(11) DEFAULT NULL,
  `refueling_the_car` int(11) DEFAULT NULL,
  `cargo` int(11) DEFAULT NULL,
  `id_decoration` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



CREATE TABLE `sm` (
  `id` int(11) NOT NULL,
  `Transport_id` int(11) DEFAULT NULL,
  `brand` varchar(20) DEFAULT NULL,
  `malfunction` varchar(50) DEFAULT NULL,
  `completed_works` varchar(50) DEFAULT NULL,
  `full_name_mechanic` varchar(50) DEFAULT NULL,
  `cost_of_work` decimal(10,0) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



CREATE TRIGGER `tr_for_sm` BEFORE INSERT ON `sm` FOR EACH ROW BEGIN

         UPDATE transport SET location = 'На ремонте', technical_condition = 'не исправное' WHERE id = NEW.transport_id;

END; 


CREATE TABLE `transport` (
  `id` int(11) NOT NULL,
  `Brand` varchar(20) DEFAULT NULL,
  `Load_capacity` int(11) DEFAULT NULL,
  `Type_auto` varchar(20) DEFAULT NULL,
  `Year_of_release` year(4) DEFAULT NULL,
  `VIN` varchar(17) DEFAULT NULL,
  `Number` varchar(9) DEFAULT NULL,
  `Technical_condition` varchar(50) DEFAULT NULL,
  `Number_garage` int(11) DEFAULT NULL,
  `Fuel_consumption` int(11) DEFAULT NULL,
  `Brand_fuel` int(11) DEFAULT NULL,
  `Location` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;




CREATE ALGORITHM=UNDEFINED DEFINER=`mysql`@`localhost` SQL SECURITY DEFINER VIEW `info`  AS SELECT `drivers`.`full_name` AS `full_name`, count(`routes`.`id`) AS `routes_count`, sum(`routes`.`distance_km`) AS `total_path`, `cargo`.`Name_cargo` AS `name_cargo`, sum(`cargo`.`Cargo_weight`) AS `total_weight`, count(`routes`.`cargo`) AS `cargo_count`, `transport`.`Type_auto` AS `type_auto`, `cargo`.`Cargo_type` AS `cargo_type` FROM (((`routes` left join `drivers` on(`drivers`.`id` = `routes`.`number_driver`)) left join `cargo` on(`cargo`.`id` = `routes`.`cargo`)) left join `transport` on(`transport`.`id` = `drivers`.`number_transport`)) GROUP BY `routes`.`number_driver` ;




ALTER TABLE `cargo`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_cargo_with_decoration` (`id_decoration`);


ALTER TABLE `decoration`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_decoration_with_transport` (`transport`),
  ADD KEY `fk_decoration_with_fares` (`fare`);


ALTER TABLE `drivers`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_drivers_with_transport` (`number_transport`);


ALTER TABLE `fares`
  ADD PRIMARY KEY (`id`);


ALTER TABLE `fuel`
  ADD PRIMARY KEY (`id`);


ALTER TABLE `payment`
 ADD PRIMARY KEY (`id`),
  ADD KEY `fk_payment_with_decoration` (`id_decoration`);

ALTER TABLE `refill`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_refill_with_decororation` (`id_decoration`);


ALTER TABLE `routes`
ADD PRIMARY KEY (`id`),
  ADD KEY `fk_routes_with_decoration` (`id_decoration`),
  ADD KEY `fk_routes_with_cargo` (`cargo`),
  ADD KEY `fk_routes_with_refill` (`refueling_the_car`),
  ADD KEY `fk_routes_with_drivers` (`number_driver`);

ALTER TABLE `sm`
ADD PRIMARY KEY (`id`),
  ADD KEY `fk_sm_with_transport` (`Transport_id`);


ALTER TABLE `transport`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_transport_with_fuel` (`Brand_fuel`);


ALTER TABLE `cargo`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;


ALTER TABLE `decoration`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;


ALTER TABLE `drivers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;


ALTER TABLE `fares`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `fuel`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;


ALTER TABLE `payment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;


ALTER TABLE `refill`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `routes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `sm`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `transport`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;



ALTER TABLE `cargo`
  ADD CONSTRAINT `fk_cargo_with_decoration` FOREIGN KEY (`id_decoration`) REFERENCES `decoration` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;


ALTER TABLE `decoration`
  ADD CONSTRAINT `fk_decoration_with_fares` FOREIGN KEY (`fare`) REFERENCES `fares` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_decoration_with_transport` FOREIGN KEY (`transport`) REFERENCES `transport` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `drivers`
  ADD CONSTRAINT `fk_drivers_with_transport` FOREIGN KEY (`number_transport`) REFERENCES `transport` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `payment`
  ADD CONSTRAINT `fk_payment_with_decoration` FOREIGN KEY (`id_decoration`) REFERENCES `decoration` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;


ALTER TABLE `refill`
  ADD CONSTRAINT `fk_refill_with_decororation` FOREIGN KEY (`id_decoration`) REFERENCES `decoration` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;


ALTER TABLE `routes`
  ADD CONSTRAINT `fk_routes_with_cargo` FOREIGN KEY (`cargo`) REFERENCES `cargo` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_routes_with_decoration` FOREIGN KEY (`id_decoration`) REFERENCES `decoration` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_routes_with_drivers` FOREIGN KEY (`number_driver`) REFERENCES `drivers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_routes_with_refill` FOREIGN KEY (`refueling_the_car`) REFERENCES `refill` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;


ALTER TABLE `sm`
  ADD CONSTRAINT `fk_sm_with_transport` FOREIGN KEY (`Transport_id`) REFERENCES `transport` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;


ALTER TABLE `transport`
  ADD CONSTRAINT `fk_transport_with_fuel` FOREIGN KEY (`Brand_fuel`) REFERENCES `fuel` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;


