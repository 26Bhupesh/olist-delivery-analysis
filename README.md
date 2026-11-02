# Olist: Delivery Performance vs. Customer Satisfaction

**Business question:** As a data analyst on Olist's Operations \& Customer Experience team: is delivery performance driving inconsistent satisfaction scores, and where should Olist fix it first?

!\[Dashboard](dashboard/dashboard.png)

## Key findings

* **Most orders arrive on time, but late ones hurt.** 93.2% of 96,476 delivered orders arrived on or before the estimated date (6,535 were late).
* **Late delivery goes with much lower ratings.** 62% of on-time orders get 5★, while 70% of orders 8+ days late get 1★. At 1–3 days late, ratings split (25% give 1★, 33% give 5★), so something beyond lateness alone shapes the score.
* **Lateness is uneven.** Alagoas (AL) is the worst state at 21.4% late vs. 6.8% overall. The worst category is audio (11.6%), and the worst seller was late on \~21% of 104 deliveries. Dec 2017, Mar 2018, and Mar Apr 2018 shows spikes in late deliveries.
* **R$720.9K of order value sits in late orders rated 1–2★.** 334 high-value orders (8.4% of them) hold 36% of it, and this value is not concentrated in the worst-delay categories.

## Recommendations

1. **Protect high-value orders.** Prioritise on-time delivery for the small set of high-value orders that carry over a third of the revenue at risk.
2. **Target the worst states and sellers.** Review carrier performance in the worst states and set delivery-time expectations (or SLAs) for the worst-performing sellers.
3. **Test before scaling.** Investigate what separates happy from unhappy customers at 1–3 days late (e.g. delay communication) before investing broadly. Category-level fixes alone won't address the revenue concentration.

## Approach

* **SQL (PostgreSQL):** five business questions answered across 7 tables using joins, CTEs, window functions and CASE logic.
* **Python (pandas):** results re-derived and checked against SQL; full review-score distributions; IQR outlier analysis; summary tables exported as CSVs.
* **Excel:** a one-sheet dashboard built from the exported CSVs.

## Method notes and limitations

* Delivered orders only; 2,965 orders (3.0%) without a delivery date are excluded.
* *Late* = delivered after the estimated delivery date, compared as dates. That date is Olist's deadline for the seller, not a carrier promise.
* Reviews are deduplicated to one per order (latest answer). Categories and sellers are shown only above 100 orders/deliveries.
* Descriptive analysis: delay is associated with low ratings, not proven to cause them. Data covers 2016–2018. Values are in Brazilian reais (R$).

## Repository

```
sql/          # the five SQL queries
notebooks/    # data loading + Python analysis
exports/      # summary CSVs feeding the dashboard
dashboard/    # olist\_dashboard.xlsx + dashboard.png
docs/         # one-page recommendation memo
```

## Reproduce

1. Download the [Olist dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) from Kaggle (not included in this repo).
2. Load the CSVs into a PostgreSQL database named `olist` (see `notebooks/`), run the queries in `sql/`, then the Python notebook.
3. Open `dashboard/olist\_dashboard.xlsx`.

\---

Bhupesh Suryawanshi · [LinkedIn](www.linkedin.com/in/bhupesh-suryawanshi) · [Email](mailto:bhupeshsuryavanshi2@gmail.com)

