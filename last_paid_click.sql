with tab as (
    select distinct on (visitor_id)
        visitor_id,
        visit_date,
        source,
        medium,
        campaign,
        lead_id,
        amount,
        created_at,
        closing_reason,
        status_id
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium != 'organic' and s.visit_date <= l.created_at
)

select * from tab
order by
amount desc nulls last, visit_date asc, source asc, medium asc, campaign asc
