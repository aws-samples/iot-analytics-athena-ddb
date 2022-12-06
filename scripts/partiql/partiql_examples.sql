/*
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0
*/

--  Querying the hourly kWh consumed by customer with ID 10027610, 
--  on 2022-01-05, from 6h00 PM until 11h00 PM:
-- **************************************************************
SELECT "CustomerID", "SensorID-Period", "kWh-Amount"
	FROM "ElectricityMeteredByPeriod" 
    WHERE "CustomerID" = 10027610
      AND "SensorID-Period" BETWEEN '51246501#2022-01-05T18' AND '51246501#2022-01-05T23'

/*
#### Items returned ####

CustomerID	SensorID-Period	        kWh-Amount
----------  ----------------------  ----------
10027610	51246501#2022-01-05T18	0.28
10027610	51246501#2022-01-05T19	0.29
10027610	51246501#2022-01-05T20	0.3
10027610	51246501#2022-01-05T21	0.3
10027610	51246501#2022-01-05T22	0.29
10027610	51246501#2022-01-05T23	0.27
*/


--  Querying the total kWh consumed by customer with ID 10027615 
--  on 2022-01-22:
-- **************************************************************
SELECT "CustomerID", "SensorID-Period", "kWh-Amount"
	FROM "ElectricityMeteredByPeriod" 
    WHERE "CustomerID" = 10027615
      AND "SensorID-Period" = '51246506#2022-01-22'

/*
#### Items returned ####

CustomerID	SensorID-Period	        kWh-Amount
----------  ----------------------  ----------
10027615	51246506#2022-01-22	    5.77
*/


--  Querying the daily kWh consumed by customer with ID 10027615 
--  on the first week of January/2022 (2022-01-02 to 2022-01-08):
-- **************************************************************
SELECT "CustomerID", "SensorID-Period", "kWh-Amount"
	FROM "ElectricityMeteredByPeriod" 
    WHERE "CustomerID" = 10027615
      AND "SensorID-Period" BETWEEN '51246506#2022-01-02' AND '51246506#2022-01-08'
      AND NOT contains("SensorID-Period", 'T')

/*
#### Items returned ####

CustomerID	SensorID-Period	        kWh-Amount
----------  ----------------------  ----------
10027615	51246506#2022-01-02	    5.77
10027615	51246506#2022-01-03	    5.77
10027615	51246506#2022-01-04	    5.77
10027615	51246506#2022-01-05	    5.77
10027615	51246506#2022-01-06	    5.77
10027615	51246506#2022-01-07	    5.77
10027615	51246506#2022-01-08	    5.77
*/


--  Querying the monthly kWh consumed by specific customers 
--  in "January/2022"
--  (This specific query should be run by the Energy company):
-- **************************************************************
SELECT "CustomerID", "SensorID-Period", "kWh-Amount"
	FROM "ElectricityMeteredByPeriod" 
    WHERE "CustomerID" IN [10027610, 10027612, 10027614, 10027616, 10027618]
      AND contains("SensorID-Period", '#2022-01')
      AND NOT contains("SensorID-Period", '#2022-01-')

/*
#### Items returned ####

CustomerID	SensorID-Period	        kWh-Amount
----------  ----------------------  ----------
10027610	51246501#2022-01	    192.51
10027612	51246503#2022-01	    166.78
10027614	51246505#2022-01	    176.08
10027616	51246507#2022-01	    163.06
10027618	51246509#2022-01	    339.76
*/
