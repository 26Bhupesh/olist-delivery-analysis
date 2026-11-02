
-- How big is the problem? — % of orders delivered after the estimated date,
-- and whether that's trending up or down month over month
-- Q1: date arithmetic on order_delivered_customer_date vs order_estimated_delivery_date,
-- a CASE WHEN to bucket late/on-time, GROUP BY month

with buckets as (
	select order_id, order_delivered_customer_date, order_estimated_delivery_date,
		case when date(order_delivered_customer_date) > date(order_estimated_delivery_date) then 'late'
			when date(order_delivered_customer_date) <= date(order_estimated_delivery_date) then 'on-time'
		End as bucket
	from orders
	where order_delivered_customer_date is not null and order_estimated_delivery_date is not null
), monthly_buckets as (
	select extract(year from order_estimated_delivery_date) as yy,
	extract(month from order_estimated_delivery_date) as mm, bucket, count(*) as orders
	from buckets
	group by extract(year from order_estimated_delivery_date), extract(month from order_estimated_delivery_date), bucket
), monthly_orders as (
	select *, sum(orders) over(partition by yy, mm order by yy, mm) as total_orders
	from monthly_buckets
)
select yy, mm, round(orders / total_orders * 100, 2) as late_order_percentage
from monthly_orders
where bucket = 'late' and total_orders > 100;


-- Where is it worst? — late-delivery rate by customer state
-- Q2: join orders → customers, GROUP BY customer_state, with a HAVING to drop states with too few orders to be meaningful

with delivery_state as (
	select customer_id,
		case when date(order_delivered_customer_date) > date(order_estimated_delivery_date) then 'late'
			when date(order_delivered_customer_date) <= date(order_estimated_delivery_date) then 'on-time'
		End as delivery
	from orders
	where order_delivered_customer_date is not null and order_estimated_delivery_date is not null
),  delivery_by_state as (
	select c.customer_state, d.delivery, count(*) as orders,
	sum(count(*)) over(partition by c.customer_state) as total_orders
	from delivery_state d
	inner join customers c on d.customer_id = c.customer_id
	group by c.customer_state, d.delivery
)
select customer_state, round(orders * 100 / total_orders, 2) as late_delivery_rate
from delivery_by_state
where delivery = 'late' and total_orders > 100
order by late_delivery_rate desc;


-- Does it actually move the review score? — average review score by delay bucket
-- (on-time / 1–3 days late / 4–7 days late / 8+ days late)
-- Q3: join orders → order_reviews, bucket delay with CASE WHEN, GROUP BY bucket, AVG(review_score)

with buckets as (
	select order_id, date(order_delivered_customer_date) - date(order_estimated_delivery_date) as order_delay,
		case when date(order_delivered_customer_date) - date(order_estimated_delivery_date) <= 0 then 'on-time'
			when date(order_delivered_customer_date) - date(order_estimated_delivery_date) between 1 and 3 then '1-3 days'
			when date(order_delivered_customer_date) - date(order_estimated_delivery_date) between 4 and 7 then '4-7 days'
			when date(order_delivered_customer_date) - date(order_estimated_delivery_date) >= 8 then '8+ days'
		end as delay_bucket
	from orders
	where order_delivered_customer_date is not null and order_estimated_delivery_date is not null
),
reviews as (
	select order_id, review_score
	from (
		select order_id, review_score, review_answer_timestamp,
		row_number() over(partition by order_id order by review_answer_timestamp desc) as rn
		from order_reviews
	)
	where rn = 1
)
select b.delay_bucket as delay, round(avg(o.review_score),2) as average_review_score,
	percentile_cont(0.5) within group (order by o.review_score) as median_review_score,
	mode() within group (order by o.review_score) as mode_review_score
from buckets b
inner join reviews o on b.order_id = o.order_id
group by b.delay_bucket
order by average_review_score desc;

-- What's driving it? — delay rate by product category, and by seller
-- Q4: join order_items → products (and separately → sellers), GROUP BY category and by seller;
-- try RANK() OVER (ORDER BY late_rate DESC) to surface the worst sellers

-- delay rate by prodcut category

with counts as (
	select p.product_category_name, b.bucket, count(*) as cnt, sum(count(*)) over(partition by p.product_category_name) as total_orders
	from (
		select order_id, order_delivered_customer_date, order_estimated_delivery_date,
			case when date(order_delivered_customer_date) > date(order_estimated_delivery_date) then 'late'
				when date(order_delivered_customer_date) <= date(order_estimated_delivery_date) then 'on-time'
			End as bucket
		from orders
		where order_delivered_customer_date is not null and order_estimated_delivery_date is not null
	) b inner join order_items o on b.order_id = o.order_id
	inner join products p on o.product_id = p.product_id
	where p.product_category_name is not null
	group by p.product_category_name, b.bucket
)
select product_category_name, cnt, total_orders, round(cnt * 100.0 / total_orders,2) as delay_rate,
	rank() over(order by cnt * 100.0 / total_orders desc) as worst_category_rank
from counts
where bucket = 'late' and total_orders > 100;

-- delay rate by seller

with counts as (
	select o.seller_id, b.bucket, count(*) as cnt, sum(count(*)) over(partition by o.seller_id) as total_sale
	from (
		select order_id, order_delivered_customer_date, order_estimated_delivery_date,
			case when date(order_delivered_customer_date) > date(order_estimated_delivery_date) then 'late'
				when date(order_delivered_customer_date) <= date(order_estimated_delivery_date) then 'on-time'
			End as bucket
		from orders
		where order_delivered_customer_date is not null and order_estimated_delivery_date is not null
	) b inner join order_items o on b.order_id = o.order_id
	group by seller_id, bucket
)
select seller_id, cnt, total_sale, round(cnt * 100.0 / total_sale, 2) as delay_rate, rank() over(order by cnt * 100.0 / total_sale desc) as worst_seller_rank
from counts
where bucket = 'late' and total_sale > 100;

-- Stretch: what's it costing? — total order value tied to orders that are both late and rated 2 stars or below
-- Q5: join orders → order_reviews → order_items, filter review_score <= 2 and late, SUM order value

with bucket as (
	select order_id, order_delivered_customer_date, order_estimated_delivery_date,
		case when date(order_delivered_customer_date) > date(order_estimated_delivery_date) then 'late'
			when date(order_delivered_customer_date) <= date(order_estimated_delivery_date)  then 'on-time'
		End as bucket
	from orders
	where order_delivered_customer_date is not null and order_estimated_delivery_date is not null
),
reviews as (
	select order_id, review_score
	from (
		select order_id, review_score, review_answer_timestamp,
		row_number() over(partition by order_id order by review_answer_timestamp desc) as rn
		from order_reviews
	)
	where rn = 1
)
select round(sum(p.total_payment)::numeric,2) as total_order_value
from (
	select b.order_id
	from bucket b
	inner join reviews r on b.order_id = r.order_id
	where b.bucket = 'late' and r.review_score <= 2
) o inner join (
	select order_id, sum(payment_value) as total_payment
	from order_payments
	group by order_id
) p on o.order_id = p.order_id;