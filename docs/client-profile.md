# Client Profile: Onward Logistics

Onward Logistics is the client for every lab in this programme. This page holds the facts that stay the same while their needs change each week.

## At a glance

Onward Logistics is a fast-growing last-mile delivery company that moves parcels for online merchants across West Africa.

| Topic | Detail |
|-------|--------|
| Business | Regional last-mile delivery. Connects merchants, riders and customers, with live parcel tracking. |
| Engineering team | Lean and growing. |
| Technology stacks | Systems built with Python and Java. |
| AWS starting point | One or multiple AWS accounts configured by hand in the console, a few servers and little consistency. An internal audit flagged too much access for too many people. |

## What the business is trying to achieve

Leadership wants to grow quickly without losing customer trust or control of costs.

**Priorities, in order:**

1. Grow without breaking: handle peak days without outages.
2. Protect customer and merchant data, because trust is the product.
3. Control cost, because delivery margins are thin.
4. Ship improvements faster, moving from monthly to weekly releases.
5. Be ready for audits at any time.

**Constraints:**

- A small platform team supports a much larger group of engineers.
- The budget is limited, so unexplained spend is a problem.
- Data protection rules apply in every market the company operates in.
- Many customers use mobile connections that can be slow or unreliable.

## Standards every solution follows

These company standards apply to everything you build, in every lab.

| Standard | Rule |
|----------|------|
| Naming | Use the pattern `onward-environment-purpose`, for example `onward-dev-orders`. Environments are `dev`, `test` and `prod`. |
| Tags | Tag every resource that supports tags with `Project` (`onward`), `Owner` (your name) and `Environment`. |
| Access | Grant only what a person or system needs. No shared accounts. Avoid long-lived credentials. |
| Automation | Make what you build repeatable from code, kept in Git, wherever the lab allows. |
| Cost | Every resource has an owner. Delete what you no longer need. Keep budget alerts active. |
| Region | Each lab names the Region or asks you to choose and justify one. |
| Decisions | Write down each decision with its reason, in business terms. |

## Requirements by week

The client's needs grow as the company grows. New requirements are added here at the start of each week, and earlier ones still apply.

| Week | What the client needs |
|:---:|------------------------|
| 1 | Engineers are onboarded safely and the same way every time. People outside the company get only temporary, limited access. Every change to who can access what can be traced. Spend is visible from day one. |
