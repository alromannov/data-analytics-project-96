with ads as (
    select
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by 1, 2, 3, 4
    union all
    select
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
),

lpc as (
    select
        s.visitor_id,
        visit_date::date,
        source,
        medium,
        campaign,
        l.lead_id,
        created_at::date,
        status_id,
        coalesce(amount, 0) as amount,
        row_number()
            over (partition by s.visitor_id order by visit_date desc)
        as rnk
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where medium != 'organic'
)

select
    visit_date::date,
    source,
    medium,
    campaign,
    count(visitor_id) as visitors_count,
    total_cost,
    sum(case when lead_id is not null then 1 else 0 end) as leads_count,
    sum(case when s.status_id = 142 then 1 else 0 end) as purchases_count,
    sum(s.amount) as revenue
from lpc as s
left join ads as ad
    on
        s.source = ad.utm_source
        and s.medium = ad.utm_medium and s.campaign = ad.utm_campaign
        and s.visit_date = ad.campaign_date
where rnk = 1
group by 1, 2, 3, 4, 6
order by 9 desc nulls last, 1 asc, 5 desc, 2 asc, 3 asc, 4 asc
limit 15
