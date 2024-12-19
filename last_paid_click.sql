with tab as (
select l.visitor_id, visit_date, source as utm_source,
row_number() over(partition by l.visitor_id order by s.visit_date desc) as rn, 
medium as utm_medium, campaign as utm_campaign, lead_id, created_at, amount, closing_reason,
status_id
from sessions s 
left join leads l on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
where medium in ('cpc', 'cpm','cpa', 'youtube', 'cpp', 'tg','social'))
select visitor_id, visit_date, utm_source, utm_medium, utm_campaign, lead_id, created_at,
amount, closing_reason, status_id
from tab
where rn = '1'
order by amount desc nulls last, visit_date, utm_source, utm_medium, utm_campaign
limit 10;