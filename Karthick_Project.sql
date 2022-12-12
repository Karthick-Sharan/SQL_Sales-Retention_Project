create schema dbms2_2;
use dbms2_2;

select * from cust_dimen;
select * from market_fact;
select * from orders_dimen;
select * from prod_dimen;
select * from shipping_dimen;

## 1.	Join all the tables and create a new table called combined_table. (market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)

create table combined_table
select m.*, o.order_id, order_date, order_priority, ship_mode, ship_date, customer_name, province, region, customer_segment, product_category, product_sub_category 
from market_fact m
join shipping_dimen s
on m.ship_id = s.ship_id
join cust_dimen c
on m.cust_id = c.cust_id
join orders_dimen o
on m.ord_id = o.ord_id
join prod_dimen p
on m.prod_id = p.prod_id;

select * from combined_table;


## 2.	Find the top 3 customers who have the maximum number of orders

select * from
(select *, dense_rank()over(order by `No. of orders` desc) as Order_Rank from 
(select *, count(*)over(partition by cust_id) as 'No. of orders' from market_fact) t
group by cust_id) t2
where order_rank < 4;                 # using dense_rank here since multiple customers can have same no. of orders so it's unfair to pick one amongst them.


## 3.	Create a new column DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.

select ord_id, Prod_id, Ship_id, Cust_id, customer_name, sales, order_date, ship_date, datediff(str_to_date((ship_date), '%d-%m-%Y'),str_to_date((order_date), '%d-%m-%Y')) as 'Days for delivery'
from combined_table;


## 4.	Find the customer whose order took the maximum time to get delivered.

with t as 
(select ord_id, Prod_id, Ship_id, Cust_id, customer_name, sales, order_date, ship_date, datediff(str_to_date((ship_date), '%d-%m-%Y'),str_to_date((order_date), '%d-%m-%Y')) as 'Days for delivery'
from combined_table  
)
select * from t where `Days for delivery`  = (select max(`days for delivery`) from t);



## 5.	Retrieve total sales made by each product from the data (use Windows function)

select * from 
(select prod_id, product_category, sum(sales)over(partition by prod_id) as 'product sales' from combined_table)t
group by prod_id order by `product sales` desc;


## 6.	Retrieve total profit made from each product from the data (use windows function)

select * from 
(select prod_id, product_category, sum(profit)over(partition by prod_id) as 'product sales' from combined_table)t
group by prod_id order by `product sales` desc;



## 7.	Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

create view cust_month 
as 
select cust_id, order_date, month(str_to_date((order_date), '%d-%m-%Y')) as 'ord_month' from combined_table where year(str_to_date((order_date), '%d-%m-%Y'))=2011
group by cust_id, order_date;                                                 #creating view with only relevant details

select 'Unique customers in Jan 2011' as 'Type of customers', count(*) as 'No. of Customers' from
(select * from cust_month where ord_month=1 group by cust_id) t2
union
select 'Customers returning every month', count(*) from
(select cust_id, `months visited` from
(select *, count(*)over(partition by cust_id) as 'months visited' from
(select * 
from cust_month group by cust_id order by cust_id ) t) t2
where `months visited` = 12 ) t3 ;                          #if customer visited evry month he'll have 12 diff entries, hence count(*) should be 12


/* --------------  2nd method where instead of count(*), lead() is used to find repeating customers :   ---------------  */


select 'Unique customers in Jan 2011' as 'Type of customers', count(*) as 'No. of Customers' from
(select * from cust_month where ord_month=1 group by cust_id ) t2
union
select 'Customers returning every month', count(*) from
(select *, sum(diff)over(partition by cust_id) as 'sum' from
(select *, lead(ord_month)over(partition by cust_id order by str_to_date((order_date), '%d-%m-%Y')) as 'next purchase month', lead(ord_month)over(partition by cust_id)-ord_month as 'diff'
from cust_month order by cust_id ) t
where diff =1 )t1
where sum = 11;      # here only records where month diff is 1 is taken and summed, sum should be 11 if customer visited every month hence we're checking for that condition.



## 8.	Retrieve month-by-month customer retention rate since the start of the business.(using views)

drop view cust_retn;

create view cust_retn
as
select customer_name, cust_id, str_to_date((order_date), '%d-%m-%Y') as ord_date, month(str_to_date((order_date), '%d-%m-%Y')) as month from combined_table group by customer_name, ord_date;

select * from cust_retn;

select *, customers/`total customers (monthwise)`*100 as 'Rate of retention(%)' from
(select *, sum(customers)over(partition by `month of year`) as 'Total Customers (Monthwise)' from 
(select date_format(ord_date, '%Y-%m') as 'Month of Year' , `Retention type` , count(*) as 'Customers' from
(select *, case when months_diff=1 then 'Retained' when months_diff >1 then 'Irregular' else 'Churned' end as 'Retention type' from
(select *, period_diff(date_format(`next visit`, '%Y%m'), date_format(ord_date, '%Y%m')) as months_diff from 
(select *, lead(ord_date)over(partition by cust_id order by ord_date) as 'next visit' from cust_retn ) t ) t2 where months_diff != 0 )t3
group by `Month of year`, `retention type`  order by `month of year` ) t4) t5 where `retention type` = 'retained';

 # customers are divided into 3 categories 'Retained', 'Irregular', 'Churned' 
 # count, percentage of each category is calculated and displayed monthwise since store opening