WITH last_click AS (
    SELECT
        s.visitor_id,
        DATE(s.visit_date) AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM sessions s
    LEFT JOIN leads l ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
    WHERE s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),
visits AS (
    SELECT
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COUNT(visitor_id) AS visitors_count
    FROM last_click
    WHERE rn = 1
    GROUP BY visit_date, utm_source, utm_medium, utm_campaign
),
costs AS (
    SELECT
        DATE(campaign_date) AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM (
        SELECT
            campaign_date,
            utm_source,
            utm_medium,
            utm_campaign,
            daily_spent
        FROM vk_ads
        UNION ALL
        SELECT
            campaign_date,
            utm_source,
            utm_medium,
            utm_campaign,
            daily_spent
        FROM ya_ads
    ) AS ad_costs
    GROUP BY visit_date, utm_source, utm_medium, utm_campaign
),
leads_summary AS (
    SELECT
        DATE(l.created_at) AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        COUNT(l.lead_id) AS leads_count,
        COUNT(CASE WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142 THEN 1 END) AS purchases_count,
        SUM(CASE WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142 THEN l.amount ELSE 0 END) AS revenue
    FROM sessions s
    LEFT JOIN leads l ON s.visitor_id = l.visitor_id
    GROUP BY l.created_at, visit_date, s.source, s.medium, s.campaign
)
SELECT
    TO_CHAR(v.visit_date, 'YYYY-MM-DD') AS visit_date,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    v.visitors_count,
    COALESCE(c.total_cost, 0) AS total_cost,
    COALESCE(l.leads_count, 0) AS leads_count,
    COALESCE(l.purchases_count, 0) AS purchases_count,
    COALESCE(l.revenue, 0) AS revenue
FROM visits v
LEFT JOIN costs c ON v.visit_date = c.visit_date AND v.utm_source = c.utm_source AND v.utm_medium = c.utm_medium AND v.utm_campaign = c.utm_campaign
LEFT JOIN leads_summary l ON v.visit_date = l.visit_date AND v.utm_source = l.utm_source AND v.utm_medium = l.utm_medium AND v.utm_campaign = l.utm_campaign
ORDER BY
    revenue DESC NULLS LAST,
    v.visit_date ASC,
    v.visitors_count DESC,
    v.utm_source ASC,
    v.utm_medium ASC,
    v.utm_campaign ASC
LIMIT 15;
