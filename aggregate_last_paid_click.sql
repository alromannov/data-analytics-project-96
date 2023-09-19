with ads as (
    select
        campaign_date::date,
        daily_spent,
        utm_source,
        utm_medium,
        utm_campaign
    from vk_ads
    union all
    select
        campaign_date::date,
        daily_spent,
        utm_source,
        utm_medium,
        utm_campaign
    from ya_ads
),

adssum as (
    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ads
    group by campaign_date, utm_source, utm_medium, utm_campaign
)

select
    visit_date::date,
    utm_source,
    utm_medium,
    utm_campaign,
    count(visitor_id) as visitors_count,
    total_cost,
    count(lead_id) as leads_count,
    sum(case when status_id = 142 then 1 else 0 end) as purchases_count,
    sum(amount) as revenue
from sessions as s
left join leads on s.visitor_id = leads.visitor_id
inner join adssum as ad
on
    s.source = ad.utm_source
    and s.medium = ad.utm_medium and s.campaign = ad.utm_campaign
    and s.visit_date::date = ad.campaign_date
group by 1, 2, 3, 4, 6
order by 9 desc nulls last, 1 asc, 5 desc, 2 asc, 3 asc, 4 asc