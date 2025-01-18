WITH tab AS (
    SELECT 
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        COALESCE(SUM(vk.daily_spent), 0) + COALESCE(SUM(ya.daily_spent), 0) AS total_cost
    FROM
        sessions s
    LEFT JOIN 
        vk_ads vk ON s.source = vk.utm_source AND s.medium = vk.utm_medium AND s.campaign = vk.utm_campaign
    LEFT JOIN
        ya_ads ya ON s.source = ya.utm_source AND s.medium = ya.utm_medium AND s.campaign = ya.utm_campaign
    GROUP BY visit_date, source, medium, campaign 
),
visits AS (
    SELECT 
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        COUNT(visitor_id) AS visitors_count
    FROM 
        sessions
    GROUP BY 
        visit_date, utm_source, utm_medium, utm_campaign
),
leads_data AS (
    SELECT 
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        COUNT(l.lead_id) AS leads_count,
        COUNT(CASE WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142 THEN 1 END) AS purchases_count,
        SUM(CASE WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142 THEN l.amount ELSE 0 END) AS revenue
    FROM 
        sessions s
    LEFT JOIN 
        leads l ON s.visitor_id = l.visitor_id
    GROUP BY 
        s.visit_date, s.source, s.medium, s.campaign
)
SELECT 
    v.visit_date,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    v.visitors_count,
    COALESCE(tab.total_cost, 0) AS total_cost,
    COALESCE(ld.leads_count, 0) AS leads_count,
    COALESCE(ld.purchases_count, 0) AS purchases_count,
    COALESCE(ld.revenue, 0) AS revenue
FROM
    visits v
LEFT JOIN
    tab ON v.visit_date = tab.visit_date AND v.utm_source = tab.utm_source AND v.utm_medium = tab.utm_medium AND v.utm_campaign = tab.utm_campaign
LEFT JOIN 
    leads_data ld ON v.visit_date = ld.visit_date AND v.utm_source = ld.utm_source AND v.utm_medium = ld.utm_medium AND v.utm_campaign = ld.utm_campaign
ORDER BY
    revenue DESC NULLS LAST,
    v.visit_date ASC,
    v.visitors_count DESC,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign
LIMIT 15;
