--Revenue: Total realized revenue

select sum(revenue_realized) as total_revenue from fact_bookings;

--Total Bookings: The total number of bookings

select count(1) from fact_bookings;

--Total Capacity: Overall room capacity of hotels.

select sum(capacity) as total_capacity from fact_aggregated_bookings;

--Total Successful Bookings: Successful bookings across all hotels.

select sum(successful_bookings) as total_successful_bookings
from fact_aggregated_bookings;

--Occupancy %: Ratio of successful bookings to total room capacity.

select format(round(sum(successful_bookings)*100.0/sum(capacity),2),'N2') as Occupancy_percentage from fact_aggregated_bookings;

--Average Rating: Average customer ratings.

select format(round(avg(ratings_given*1.0),2),'N2') as average_ratings from fact_bookings;

--No of days: Total number of days in the dataset.

select datediff(dd,min(date),max(date))+1 as number_of_days from dim_date;

--Total Cancelled Bookings: Number of bookings marked as "Cancelled".

select * from fact_bookings
where booking_status = 'Cancelled';

----Cancellation %: Percentage of cancellations.

select format(round(count(case when booking_status = 'Cancelled' then 1 end)*100.0/count(1),2),'N2') as Cancelled_booking_percentage
from fact_bookings;

--Total Checked Out: Successful 'Checked out' bookings.

select * from fact_bookings
where booking_status = 'Checked Out'

--No Show rate %: Percentage of no-show bookings.

select * from fact_bookings
where booking_status = 'No Show'

select format(round(count(case when booking_status = 'No Show' then 1 end)*100.0/count(1),2),'N2') as no_show_percentage
from fact_bookings;

--Booking % by Platform: Contribution percentage of each booking platform.

--1) By counts
select booking_platform,format(round(count(1)*100.0/(select count(1) from fact_bookings),2),'N2') as platform_contribution
from fact_bookings
group by booking_platform;

--2) By revenue

select booking_platform,format(round(sum(revenue_realized)*100.0/(select sum(revenue_realized) from fact_bookings),2),'N2') as platform_contribution
from fact_bookings
group by booking_platform;

--Booking % by Room Class: Contribution percentage of each room class.
--1)By Count
select room_class,format(round(count(1)*100.0/(select count(1) from fact_bookings),2),'N2') as room_class_contri 
from fact_bookings b
inner join dim_rooms r on b.room_category = r.room_id
group by room_class
order by room_class_contri desc;

--2)By Revenue
select room_class,format(round(sum(revenue_realized)*100.0/(select sum(revenue_realized) from fact_bookings),2),'N2') as room_class_contri 
from fact_bookings b
inner join dim_rooms r on b.room_category = r.room_id
group by room_class
order by room_class_contri desc;


--ADR (Average Daily Rate): Average payment per sold room.

select format(round(sum(revenue_realized)*1.0/count(1),2),'N2') as Average_Daily_rate
from fact_bookings;

--Realisation %: Percentage of successful "Checked out" bookings.

--1)Upon revenue
select format(round(sum(case when booking_status = 'checked out' then revenue_realized end)*100.0/sum(revenue_realized),2),'N2') as Realisation_Percentage
from fact_bookings;

--1)Upon count
select format(round(count(case when booking_status = 'checked out' then 1 end)*100.0/count(1),2),'N2') as Realisation_Percentage
from fact_bookings;

--RevPAR (Revenue Per Available Room): Revenue generated per available room.

select format(round((select sum(revenue_realized) from fact_bookings)*1.0/sum(capacity),2),'N2') as RevPAR
from fact_aggregated_bookings;

--DBRN (Daily Booked Room Nights): Average daily booked room nights.

select sum(successful_bookings)/(select datediff(D,min(date),max(date))+1 from dim_date) as DBRN
from fact_aggregated_bookings;

--DSRN (Daily Sellable Room Nights): Average daily sellable room nights.

select sum(capacity)/(select datediff(D,min(date),max(date))+1 from dim_date) as DSRN
from fact_aggregated_bookings;

--DURN (Daily Utilized Room Nights): Average daily utilized room nights.

select count(case when booking_status = 'Checked out' then 1 end)/(select datediff(D,min(date),max(date))+1 from dim_date) as DSRN
from fact_bookings;

--Revenue WoW change %: Week over week revenue change percentage.
-- Considering only bookings after the month of May

with weekly_table as
(select datepart(WEEK,booking_date) as week ,sum(revenue_realized) as revcw
from fact_bookings
where booking_date>=(select min(date) from dim_date)
group by datepart(WEEK,booking_date))
select week,revcw
,lag(revcw,1,0) over(order by week) as revpw
,isnull(format(round((revcw-lag(revcw,1,0) over(order by week))*100.0/nullif(lag(revcw,1,0) over(order by week),0),2),'N2'),0)+'%' as rev_wow_chng
from weekly_table;

--Occupancy WoW change %: Week over week occupancy change percentage.

with weekly_table as
(select datepart(week,check_in_date) as week,sum(successful_bookings)*100.0/sum(capacity) as occu_cw 
from fact_aggregated_bookings
group by DATEPART(week,check_in_date))
select week,format(round(occu_cw,2),'N2') as occu_cw
,format(round(lag(occu_cw,1,0) over(order by week),2),'N2') as occu_pw
,isnull(format(round((occu_cw-lag(occu_cw,1,0) over(order by week))*100.0/nullif(lag(occu_cw,1,0) over(order by week),0),2),'N2'),0)+'%' as occu_wow_chng
from weekly_table;

--ADR WoW change %: Week over week ADR change percentage.

with weekly_table as
(select datepart(week,check_in_date) as week,sum(revenue_realized)*1.0/count(1)as adrcw
from fact_bookings
group by datepart(week,check_in_date))
select week,format(round(adrcw,2),'N2') as adrcw
,format(round(lag(adrcw,1,0) over(order by week),2),'N2') as adrpw
,isnull(format(round((adrcw-lag(adrcw,1,0) over(order by week))*100.0/nullif(lag(adrcw,1,0) over(order by week),0),2),'N2'),0)+'%' as adr_wow_chng
from weekly_table;

--RevPAR WoW change %: Week over week RevPAR change percentage.

with weekly_rev as
(select datepart(week,check_in_date) as week,sum(revenue_realized) as weekly_rev from fact_bookings
group by datepart(week,check_in_date))
,weekly_capacity as 
(select datepart(week,check_in_date) as week,sum(capacity) as weekly_cap from fact_aggregated_bookings
group by datepart(week,check_in_date))
,weekly_table as
(select wc.week,weekly_rev*1.0/weekly_cap as RevPARcw
from weekly_capacity wc
inner join weekly_rev wr on wc.week = wr.week)
select week,format(round(RevPARcw,2),'N2') as RevPARcw
,format(round(lag(RevPARcw,1,0) over(order by week),2),'N2') as RevPARpw
,isnull(format(round((RevPARcw-lag(RevPARcw,1,0) over(order by week))*100.0/nullif(lag(RevPARcw,1,0) over(order by week),0),2),'N2'),0)+'%' as RevPAR_wow_chng
from weekly_table;

--Realisation WoW change %: Week over week realisation change percentage.

--1)Upon revenue
with weekly_table as
(select datepart(week,check_in_date) as week,sum(case when booking_status = 'checked out' then revenue_realized end)*100.0/sum(revenue_realized) as Realisationcw
from fact_bookings
group by datepart(week,check_in_date))
select week,format(round(Realisationcw,2),'N2') as Realisationcw
,format(round(lag(Realisationcw,1,0) over(order by week),2),'N2') as Realisationpw
,isnull(format(round((Realisationcw-lag(Realisationcw,1,0) over(order by week))*100.0/nullif(lag(Realisationcw,1,0) over(order by week),0),2),'N2'),0)+'%' as Realisation_wow_chng
from weekly_table;

--1)Upon count
with weekly_table as
(select datepart(week,check_in_date) as week,count(case when booking_status = 'checked out' then revenue_realized end)*100.0/count(1) as Realisationcw
from fact_bookings
group by datepart(week,check_in_date))
select week,format(round(Realisationcw,2),'N2') as Realisationcw
,format(round(lag(Realisationcw,1,0) over(order by week),2),'N2') as Realisationpw
,isnull(format(round((Realisationcw-lag(Realisationcw,1,0) over(order by week))*100.0/nullif(lag(Realisationcw,1,0) over(order by week),0),2),'N2'),0)+'%' as Realisation_wow_chng
from weekly_table;

--DSRN WoW change %: Week over week DSRN change percentage.

with weekly_table as
(select datepart(week,check_in_date) as week,
sum(capacity)/(select datediff(D,min(date),max(date))+1 from dim_date) as DSRN
from fact_aggregated_bookings
group by datepart(week,check_in_date))
select week,format(round(DSRN,2),'N2') as DSRNcw
,format(round(lag(DSRN,1,0) over(order by week),2),'N2') as DSRNpw
,isnull(format(round((DSRN-lag(DSRN,1,0) over(order by week))*100.0/nullif(lag(DSRN,1,0) over(order by week),0),2),'N2'),0)+'%' as DSRN_wow_chng
from weekly_table;
