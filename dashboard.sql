-- Количество пользователей, заходивших на сайт:
select
    count(distinct visitor_id) as total_visitor,
    date(visit_date) as visit_day
from sessions
group by visit_day
order by visit_day;
--Каналы приводящие пользователей на сайт (по дням/неделям/месяца):
select
    source,
    count(distinct visitor_id) as total_visitors,
    date(visit_date) as visit_day
from sessions
group by source, visit_day
order by visit_day, source;
--Количество лидов:
select
    count(distinct lead_id) as total_leads,
    date(created_at) as lead_day
from leads
group by lead_day
order by lead_day;
--Расходы по разным каналам в динамике:
select
    utm_source,
    sum(daily_spent) as total_spent,
    date(campaign_date) as campaign_day
from vk_ads
group by utm_source, campaign_day
union all
select
    utm_source,
    sum(daily_spent) as total_spent,
    date(campaign_date) as campaign_day
from ya_ads
group by
    utm_source, campaign_day
order by campaign_day, utm_source;
-- Окупаемость каналов:
select
    s.source,
    coalesce(sum(ya.daily_spent), 0)
    + coalesce(sum(vk.daily_spent), 0) as total_cost,
    coalesce(sum(l.amount), 0) as revenue,
    (coalesce(
        sum(l.amount), 0) - (
        coalesce(sum(ya.daily_spent), 0)
        + coalesce(sum(vk.daily_spent), 0)
    ))
    / nullif((
        coalesce(sum(ya.daily_spent), 0)
        + coalesce(sum(vk.daily_spent), 0)
    ), 0) * 100 as roi
from
    sessions as s
left join
    leads as l on s.visitor_id = l.visitor_id
left join
    ya_ads as ya
    on
        s.source = ya.utm_source
        and s.visit_date = ya.campaign_date
left join
    vk_ads as vk
    on
        s.source = vk.utm_source
        and s.visit_date = vk.campaign_date
where
    s.source in (
        'yandex', 'vk', 'telegram', 'google',
        'organic', 'admitad', 'bing.com'
    )
group by
    s.source;
-- Конверсия из клика в лид:
select
    s.source,
    count(distinct s.visitor_id) as visitors_count,
    count(distinct l.lead_id) as leads_count,
    (
        count(distinct l.lead_id) * 1.0
        / nullif(count(distinct s.visitor_id), 0)
    ) as conversion_click_to_lead
from
    sessions as s
left join
    leads as l on s.visitor_id = l.visitor_id
group by
    s.source;
-- Из лида в оплату:
select
    count(distinct lead_id) as leads_count,
    count(distinct case
        when status_id = '142'
            then lead_id
    end) as paid_count,
    (count(distinct case
        when
            status_id = '142' then
            lead_id
    end) * 100.0 / nullif(count(
        distinct
        lead_id
    ), 0)) as conversion_rate
from leads;
-- Основные метрики:
with last_paid_click as (
    select
        l.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.lead_id,
        s.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
        over (
            partition by l.visitor_id
            order by s.visit_date desc
        )
        as rn
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

f_clicks as (
    select
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    from last_paid_click
    where rn = 1
),

metrics as (
    select
        f.utm_source,
        sum(
            coalesce(ya.daily_spent, 0)
            +
            coalesce(vk.daily_spent, 0)
        ) as total_cost,
        count(distinct f.visitor_id) as
        visitors_count,
        count(distinct f.lead_id) as leads_count,
        count(distinct case
            when f.status_id = '142'
                then f.lead_id
    end) as purchases_count,
        sum(f.amount) as revenue
    from f_clicks as f
    left join (
        select
            utm_source,
            campaign_date,
            sum(daily_spent) as daily_spent
        from ya_ads
        group by utm_source, campaign_date
    ) as ya on f.utm_source = ya.utm_source
    left join (
        select
            utm_source,
            campaign_date,
            sum(daily_spent) as daily_spent
        from vk_ads
        group by utm_source, campaign_date
    ) as vk on f.utm_source = vk.utm_source
    group by f.utm_source
)

select
    utm_source,
    total_cost,
    visitors_count,
    leads_count,
    purchases_count,
    revenue,
    (total_cost / nullif(visitors_count, 0)) as cpu,
    (total_cost / nullif(leads_count, 0)) as cpl,
    (total_cost / nullif(purchases_count, 0)) as cppu,
    ((revenue - total_cost) / nullif(total_cost, 0)) * 100 as roi
from metrics
where utm_source in ('yandex', 'vk');
