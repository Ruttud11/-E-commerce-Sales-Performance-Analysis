-- Ecommerce Project

-- Goal: Analyse the sales performance of products, categories, and regions.
-- Database Schema Overview: We have 5 tables:
-- Customers
-- Products
-- Orders
-- OrderDetails
-- Regions

-- Questions:
show tables;
select * from customers;
select * from orderdetails;
select * from orders;
select * from regions;
select * from products;
-- General Sales Insights
-- 1)What is the total revenue generated over the entire period? (quantity * price)
select * from products;
select sum(o.quantity *p.price) as total_revenue
from products as p
join orderdetails as o
on o.productid = p.productid;
-- The TOTAL REVENUE generated over the entire period is 2757346.10

-- 2)Revenue Excluding Returned Orders
select sum(p.price * od.quantity) as Returned_Rev_Excluded
from orders o
join orderdetails od
on o.orderid = od.orderid
join products p
on od.productid = p.productid
where o.isreturned = 0;

-- 3)Total Revenue per Year / Month
select year(o.OrderDate) as Year,
	   month(o.OrderDate) as Month,
       sum(p.Price * od.Quantity) as Returned_Rev_Excluded
from orders o
join orderdetails od
on o.OrderID = od.OrderID
join Products p
on od.Productid = p.Productid
group by Year , Month
order  by Year , Month;

-- 4)Revenue by Product / Category
select p.Category, 
       p.ProductName,
       sum(p.Price* od.Quantity ) as Total_revenue_by_Cat_ProdName
from products as p
join orderdetails as od
on p.ProductId = od.ProductId
group by p.Category, 
         p.ProductName
order by p.Category,
		 Total_revenue_by_Cat_ProdName DESC ;

-- 5) What is the average order value (AOV) across all orders? (AOV = Total Revenue/number of orders)

select avg(total_revenue) from(
select o.OrderID,sum(o.quantity *p.price) as total_revenue
from products as p
join orderdetails as o
on o.productid = p.productid
group by o.OrderId) as T;

-- 6) AOV per Year / Month
select  year(OrderDate) as Year,
        month(OrderDate) as Month,
        avg(total_revenue) from(
select o.OrderID,o.OrderDate,sum(od.quantity * p.price) as total_revenue
from products as p
join orderdetails as od
on od.productid = p.productid
join orders o
on od.OrderID = o.OrderID
group by o.OrderId) as T
group by year,month
order by year,month;

-- 7) What is the average order size by region?
select *
from customers;
select * from orders;

select RegionName, avg(Total_Order_Size)as Avg_Order_Size from
(select o.orderID, C.RegionID, sum(od.quantity) as Total_Order_Size
from orderdetails od
join orders o
on od.OrderID = o.OrderID
join customers c
on o.CustomerID = c.CustomerID
group by o.OrderID) OrderSize
join Regions r
on r.RegionId = OrderSize.RegionId
group  by RegionName
order by Avg_Order_Size DESC;

 

-- Customer Insights
-- 1) Who are the top 10 customers by total revenue spent?
select c.CustomerID, c.CustomerName, sum(p.Price * od.Quantity) as Total_Revenue
from products p
join orderdetails od
on p.ProductID = od.ProductID
join orders o 
on od.OrderID = o.OrderID
join  customers c 
on o.CustomerID = c.CustomerID
Group By c.CustomerID
Order By Total_Revenue DESC
Limit 10;
-- 2) What is the repeat customer rate?
-- Repeat Customer = Customer with more than 1 order/ Customer with atleast 1 Order
select round(count(distinct case when ordercount > 1 Then CustomerId END)/ 
count(distinct CustomerID),2) as Repeated_Cust
from(
select CustomerID, count(OrderId) as ordercount 
from Orders
group by CustomerID)as T;
select round(191/199,2);

-- 3) What is the average time between two consecutive orders for the same customer Region-wise?
-- 31:00
with RankedOrders as(
     SELECT O.customerId, O.OrderDate, C.RegionId,
             Row_Number() over (Partition BY O.CustomerID ORDER BY O.OrderDate) AS rn
	FROM Orders O
    Join customers C ON C.CustomerID = O.CustomerID
), 
OrderPairs AS (
SELECT curr.CustomerID, curr.RegionID, DATEDIFF(curr.OrderDate, previous.OrderDate) AS DaysBetween
FROM RankedOrders as curr
JOIN RankedOrders as previous 
on curr.CustomerID = previous.CustomerID and curr.rn = previous.rn+1
),
RegionName as (
      SELECT CustomerID, RegionName,DaysBetween
      From OrderPairs OP
      JOIN regions R on R.RegionID = OP.RegionID
      )
Select RegionName, ROUND(AVG(DaysBetween),2) AS AVGDaysBetween
FROM regions
Group BY RegionName
ORDER BY AVGDaysBetween;

-- 4) Customer Segment (based on total spend)
-- Platinum: Total Spend > 1500
-- Gold: 1000–1500
-- Silver: 500–999
-- Bronze: < 500
with CustomerSpent As(
 select O.CustomerId, sum(OD.Quantity * P.Price) AS TotalSpend
 From orders O
 Join orderdetails OD
 ON OD.OrderID = O.OrderID
 Join Products P 
 on P.ProductID = OD.ProductID
 Group BY O.CustomerID
 )
 SELECT CustomerName,
          case 
           WHEN TotalSpend > 1500 THEN 'Platinum'
           WHEN TotalSpend BETWEEN 1000 AND 1500 THEN 'GOLD'
           WHEN TotalSpend BETWEEN 500 AND 999 THEN 'Silver'
            WHEN TotalSpend < 500 THEN 'Bronze'
	END As Segment
 From CustomerSpent CS
 Join Customers C on C.CustomerID = CS.CustomerID;

-- 5) What is the customer lifetime value (CLV)?
-- (CLV CUSTOMER LIFETIME VALUE --> Total RVENUE Per CUSTOMER)
select c.CustomerID, c.CustomerName, sum(OD.Quantity*P.Price) as CLV
From Customers C
JOIN Orders O 
ON O.CustomerID = C.CustomerID
JOIN orderdetails OD
on OD.OrderID = O.OrderID
Join Products P
on p.PRoductID = OD.ProductID
Group by c.CustomerID, C.CustomerName
Order BY CLV DESC;

-- Product & Order Insights
-- 1.What are the top 10 most sold products (by quantity)?
SELECT P.ProductID, P.ProductName, sum(OD.Quantity ) as TotalQty
From Orderdetails OD
Join Products P 
on P.ProductID = OD.PRoductID
Group BY P.ProductID, P.ProductName
Order BY TotalQty DESc
Limit 10;
-- 2.What are the top 10 most sold products (by revenue)?
SELECT P.ProductID, P.ProductName, sum(OD.Quantity * P.Price) as TotalRevenue
From Orderdetails OD
Join Products P 
on P.ProductID = OD.PRoductID
Group BY P.ProductID, P.ProductName
Order BY TotalRevenue DESc
Limit 10;
-- 3.Which products have the highest return rate? [Return Rate = Returned QTY /TOTAl Quantity]
with Sold AS(
SELECT ProductID, Sum(Quantity) AS TotalQty
From orderdetails 
Group by ProductID
),
Returned AS(
    SELECT ProductID, Sum(Quantity) AS TotalQtyReturned
	From orderdetails OD
    Join orders as O
    ON O.OrderID = OD.OrderID
    Where isReturned = 1
	Group by ProductID
    )
SELECT ProductName, Round((TotalQtyReturned / TotalQty ),2) As ReturnRate
From Products P
Join Sold S on S.ProductId = P.ProductID
Join Returned R on R.ProductId = P.ProductId
Order By ReturnRate DESC
Limit 1;

-- 4.Return Rate by Category
with Sold AS(
SELECT Category, Sum(Quantity) AS TotalQty
From orderdetails  OD
Join Products P 
On P.PRoductID = OD.ProductID
Group by Category
),
Returned AS(
    SELECT Category, Sum(Quantity) AS TotalQtyReturned
	From orderdetails OD
    Join orders as O
    ON O.OrderID = OD.OrderID
    Join Products P 
    On P.PRoductID = OD.ProductID
    Where isReturned = 1
	Group by Category
    )
SELECT S.Category, Round((TotalQtyReturned / TotalQty ),2) As ReturnRate
From Sold S
Join Returned R on R.Category = S.Category
Order By ReturnRate DESC
Limit 10;

-- 5.What is the average price of products per region?
Select RegionName, Round(SUM(OD.Quantity* P.Price)/ SUM(OD.Quantity),2) AS AvgPrice
From orders O
Join Customers C On C.CustomerID = O.CustomerID
Join Regions R on R.RegionID  = C.RegionID
Join orderdetails OD on OD.OrderID = O.OrderID
Join products P on P.ProductID = OD.ProductID
Group BY RegionName
Order BY AvgPrice DESC;

-- 6.What is the sales trend for each product category?
SELECT DATE_FORMAT(OrderDate, "%Y-%m") as Period, Category, SUM(OD.Quantity*P.Price) As Revenue
From Orders O 
Join orderdetails OD 
ON Od.OrderId = O.OrderID
Join Products P
On P.ProductID = OD.ProductID
Group BY Period,Category
Order BY Period, Category, Revenue DESC;
-- 4)Temporal Trends
-- 4.1.What are the monthly sales trends over the past year?
SELECT Year(OrderDate) as Yr,
        Month(OrderDate) as Mth,
        sum(OD.Quantity * P.Price) AS Revenue
From Orders O 
Join OrderDetails OD on OD.OrderID = O.OrderID
Join Products P on P.ProductID = OD.ProductID
WHERE OrderDate >= Current_Date() - Interval 12 Month
Group by Yr, Mth
Order BY Yr, Mth;

-- 4.2.How does the average order value (AOV) change by month or week?
SELECT DATE_Format(OrderDate, "%Y-%m") AS Period,
       ROUND(SUM(OD.Quantity * P.Price)/ COunt(Distinct O.OrderID),2) As AOV
From Orders O
Join OrderDetails OD on OD.OrderID = O.OrderID
Join Products P on P.ProductID = OD.ProductID 
Group by Period
Order by Period;
-- Regional Insights
-- Which regions have the highest order volume and which have the lowest?
Select RegionName, count(OrderID) As OrderVolume
From Orders O 
JOIN customers C on C.CustomerID = O.CustomerID
Join Regions R on R.RegionId = C.RegionId
Group BY RegionName
Order by OrderVolume DESC;

-- What is the revenue per region and how does it compare across different regions?
Select RegionName, sum(OD.Quantity * P.Price) As TotalRevenue
From Orders O 
JOIN customers C on C.CustomerID = O.CustomerID
Join Regions R on R.RegionId = C.RegionId
Join OrderDetails OD on OD.OrderID = O.OrderID
Join Products P on P.ProductID = OD.ProductID
Group BY RegionName
Order by TotalRevenue DESC;

with T1 AS(Select RegionName, count(OrderID) As OrderVolume
From Orders O 
JOIN customers C on C.CustomerID = O.CustomerID
Join Regions R on R.RegionId = C.RegionId
Group BY RegionName
Order by OrderVolume DESC),
T2 AS(Select RegionName, sum(OD.Quantity * P.Price) As TotalRevenue
From Orders O 
JOIN customers C on C.CustomerID = O.CustomerID
Join Regions R on R.RegionId = C.RegionId
Join OrderDetails OD on OD.OrderID = O.OrderID
Join Products P on P.ProductID = OD.ProductID
Group BY RegionName
Order by TotalRevenue DESC)
SELECT t1.RegionName, OrderVolume, TotalRevenue
From T1
Join T2
On T2.RegionName = T1. RegionName;

-- Return & Refund Insights
-- What is the overall return rate by product category?
SELECT Category,
      Round(Sum(Case WHEN IsReturned =1 THEN 1 ELSE 0 End)/count(O.OrderId),2) AS ReturnRate
From Orders O
Join orderdetails OD on OD.OrderID = O.OrderID
Join Products P on P.ProductID = OD.ProductID
Group By Category
Order BY ReturnRate DESC;
-- What is the overall return rate by region?
SELECT RegionName,
      Round(Sum(Case WHEN IsReturned =1 THEN 1 ELSE 0 End)/count(O.OrderId),2) AS ReturnRate
From Orders O
Join Customers C on C.CustomerID = O.CustomerID
Join Regions R on R.RegionID = C.RegionID
Group By RegionName
Order BY ReturnRate DESC;
-- Which customers are making frequent returns?
 SELECT C.CustomerID, CustomerName, Count(O.OrderId) as ReturnCount
 From Orders O 
 Join Customers C on C.CustomerId = O.CustomerID
 Where IsReturned = 1
 Group BY C.CustomerID, CustomerName
 Order BY ReturnCount DESC
 LIMIT 10;




