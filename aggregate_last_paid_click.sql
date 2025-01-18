with tab as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
            over (
                partition by s.visitor_id
                order by s.visit_date desc
            )
        as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

last_paid_click as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(lead_id) as leads_count,
        count(
            case
                when
                    closing_reason = 'Успешно реализовано' or status_id = 142
                    then 1
            end
        ) as purchases_count,
        sum(amount) as revenue
    from tab
    where rn = 1
    group by
        date(visit_date),
        utm_source,
        utm_medium,
        utm_campaign
),

canal as (
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by campaign_date, utm_source, utm_medium, utm_campaign
    union
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    order by campaign_date
)

select
    lcl.visit_date,
    lcl.visitors_count,
    lcl.utm_source,
    lcl.utm_medium,
    lcl.utm_campaign,
    c.total_cost,
    lcl.leads_count,
    lcl.purchases_count,
    lcl.revenue
from last_paid_click as lcl
left join
    canal as c
    on
        lcl.utm_source = c.utm_source
        and lcl.utm_medium = c.utm_medium
        and lcl.utm_campaign = c.utm_campaign
        and lcl.visit_date = c.campaign_date
order by
    lcl.revenue desc nulls last,
    lcl.visit_date asc,
    lcl.visitors_count desc,
    lcl.utm_source asc,
    lcl.utm_medium asc,
    lcl.utm_campaign asc
limit 15;
