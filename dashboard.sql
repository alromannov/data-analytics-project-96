--Сколько у нас пользователей заходят на сайт?
select COUNT(distinct visitor_id)
from sessions

--Каналы по дням, с количеством посетителей больше 10 человек:
select
    (case
        when source like lower('yan%') then 'yandex'
        when source like 'Yandex' then 'yandex'
        when source like 'telegram%' then 'telegram'
        when source like 'tg' then 'telegram'
        when source like 'twitter%' then 'twitter'
        when source like 'facebook%' then 'facebook'
        when source like 'vk%' then 'vk' else source
    end) as source,
    extract(day from visit_date) as day_number,
    count(distinct visitor_id)
from sessions
group by 1, 2
having count(distinct visitor_id) > 10
order by 2, 1

--Какие каналы их приводят на сайт? По месяцам
select
    (case
        when source like lower('yan%') then 'yandex'
        when source like 'Yandex' then 'yandex'
        when source like 'telegram%' then 'telegram'
        when source like 'tg' then 'telegram'
        when source like 'twitter%' then 'twitter'
        when source like 'facebook%' then 'facebook'
        when source like 'vk%' then 'vk' else source
    end) as source,
    extract(month from visit_date) as month_number,
    count(distinct visitor_id)
from sessions
group by 1, 2
order by 2, 1 

--Какие каналы их приводят на сайт? По неделям
select
    (case
        when source like lower('yan%') then 'yandex'
        when source like 'Yandex' then 'yandex'
        when source like 'telegram%' then 'telegram'
        when source like 'tg' then 'telegram'
        when source like 'twitter%' then 'twitter'
        when source like 'facebook%' then 'facebook'
        when source like 'vk%' then 'vk' else source
    end) as source,
    extract(week from visit_date) as week_number,
    count(distinct visitor_id)
from sessions
group by 1, 2
having count(distinct visitor_id) > 100
order by 2, 1

--Какая конверсия из клика в лид? А из лида в оплату?
select ROUND(((
        select count(distinct(lead_id))
        from sessions s 
        left join leads l using(visitor_id)
        where lead_id is not null
        ) * 100.00) / count(distinct(visitor_id)), 2) as visit_to_lead,
        (select 
               (
               select count(lead_id)
                from leads l
                where status_id = 142
                ) * 100/count(lead_id) as storm
         from leads l 
         ) as leads_to_buy
from sessions s 
left join leads l using(visitor_id)

--update Какая конверсия из клика в лид? А из лида в оплату?
select ROUND(((
        select count(distinct(lead_id))
        from sessions s 
        left join leads l using(visitor_id)
        where lead_id is not null
        ) * 100.00) / count(distinct(visitor_id)), 2) as visit_to_lead,
        (select count(lead_id)
         from leads l
         where status_id = 142
         ) * 100/count(l.lead_id) as leads_to_buy
from sessions s 
left join leads l using(visitor_id)

--Сколько мы тратим по разным каналам в динамике?
with tab as (
select campaign_date::date, utm_source, utm_medium, utm_campaign, sum(daily_spent) as total_cost
from vk_ads vk
group by 1,2,3,4
union all
select campaign_date::date, utm_source, utm_medium, utm_campaign, sum(daily_spent) as total_cost
from ya_ads vk
group by 1,2,3,4
)
select * from tab
order by campaign_date asc, total_cost desc

--окупаются ли каналы:
with ads as (
select campaign_date::date, utm_source, utm_medium, utm_campaign, sum(daily_spent) as total_cost
from vk_ads vk
group by 1,2,3,4
union all
select campaign_date::date, utm_source, utm_medium, utm_campaign, sum(daily_spent) as total_cost
from ya_ads vk
group by 1,2,3,4
),
       lpc as(
select s.visitor_id, visit_date::date, source, medium, campaign, l.lead_id, created_at::date, coalesce(amount, 0) as amount,
status_id,
row_number() over (partition by s.visitor_id order by visit_date desc) as rnk
from sessions s
left join leads l on s.visitor_id = l.visitor_id
and s.visit_date <= l.created_at
where medium <> 'organic'
), lpcagr as (
select visit_date::date, utm_source, utm_medium, utm_campaign, count(visitor_id) as visitors_count,
total_cost, sum(case when lead_id is not null then 1 else 0 end) as leads_count, sum(case when s.status_id = 142 then 1 else 0 end) as purchases_count,
sum(s.amount) as revenue
from lpc s
join ads ad on s.source = ad.utm_source and 
s.medium = ad.utm_medium and s.campaign = ad.utm_campaign
and s.visit_date = ad.campaign_date
where rnk = 1
group by 1,2,3,4,6
)
select utm_source, ROUND(sum(total_cost)  / sum(visitors_count), 2) as cpu,
round(sum(coalesce(total_cost, 0)) / sum(leads_count), 2) as cpl,
round(sum(coalesce(total_cost, 0))  / sum(purchases_count), 2) as cppu,
round(((sum(revenue) - sum(total_cost)) * 100 / sum(total_cost) ), 2) as roi 
from lpcagr
group by 1

--Можно посчитать за сколько дней с момента перехода по рекламе закрывается 90% лидов.
with tab as (
    select distinct
        created_at,
        (s.visitor_id),
        FIRST_VALUE(s.visit_date)
            over (partition by s.visitor_id order by visit_date)
        as fvd
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where medium != 'organic' and status_id = 142
)

select PERCENTILE_CONT(0.9) within group (order by (created_at::date - fvd::date)) as ninetieth_percentile_lead_lifetime
from tab
