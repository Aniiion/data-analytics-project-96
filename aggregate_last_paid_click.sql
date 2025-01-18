with tab as (
    select 
        visit_date,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        coalesce(SUM(vk.daily_spent), 0) + COALESCE(SUM(ya.daily_spent), 0) as total_cost
   from
        sessions s
   left join
        vk_ads vk on s.source = vk.utm_source and s.medium = vk.utm_medium and s.campaign = vk.utm_campaign
    left join
        ya_ads ya on s.source = ya.utm_source and s.medium = ya.utm_medium and s.campaign = ya.utm_campaign
    group by visit_date, source, medium, campaign 
),
visits as (
    select 
        visit_date,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        count(visitor_id) as visitors_count
    from 
        sessions
    group by 
        visit_date, utm_source, utm_medium, utm_campaign
),
leads_data as (
    select 
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        count(l.lead_id) as leads_count,
        count(case when l.closing_reason = 'Успешно реализовано' or l.status_id = 142 then 1 end) as purchases_count,
        SUM(case when l.closing_reason = 'Успешно реализовано' or l.status_id = 142 then l.amount else 0 end) as revenue
     from 
        sessions s
    left join 
        leads l on s.visitor_id = l.visitor_id
    group by 
        s.visit_date, s.source, s.medium, s.campaign
)
select 
    to_char(v.visit_date,'YYYY-MM-DD') as visit_date,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    v.visitors_count,
    COALESCE(tab.total_cost, 0) as total_cost,
    COALESCE(ld.leads_count, 0) as leads_count,
    COALESCE(ld.purchases_count, 0) as purchases_count,
    COALESCE(ld.revenue, 0) as revenue
from
    visits v
left join
    tab on v.visit_date = tab.visit_date and v.utm_source = tab.utm_source and v.utm_medium = tab.utm_medium and v.utm_campaign = tab.utm_campaign
left join 
    leads_data ld on v.visit_date = ld.visit_date and v.utm_source = ld.utm_source and v.utm_medium = ld.utm_medium and v.utm_campaign = ld.utm_campaign
order by
    revenue desc NULLS last,
    v.visit_date asc,
    v.visitors_count desc,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign
limit 15;
