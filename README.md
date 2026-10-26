# BudgetOS — Budget Meat Shop Operations

**A branded multi-branch meat-retail operations concept by VanillaWebz.**

Repository: https://github.com/ncubemphile8/budget-meat-shop-os

> **Demo data disclaimer:** sales, staff names, inventory, prices, expenses, orders, deliveries, suppliers and campaign results inside the prototype are illustrative samples. They are not Budget Meat Shop's actual private records, and the app does not connect to the retailer's point-of-sale, website, payment gateway, drivers or internal database.

## Visual identity & experience

- Uses the Budget Meat Shop logo hosted on the retailer's public website.
- Brand palette built around its blue and red identity, charcoal and white.
- Premium retail/operations layout, responsive sidebar, phone-first layouts, loading transitions and branded logo loader.
- Meat-preparation loop video with product-image poster fallback plus a real product photo from the public catalogue.
- Uses Jost typography and Lucide icons.
- Respects reduced-motion preferences.

Media sources:
- Logo: https://budgetmeatshop.co.zw/wp-content/uploads/2025/11/Screenshot_2025-11-13_164119-removebg-preview.png
- Meat product image: https://budgetmeatshop.co.zw/wp-content/uploads/2025/11/Beef-T-Bone.jpg
- Meat-preparation clip: https://www.pexels.com/video/butcher-shop-scene-with-meat-preparation-37432143/

## Modules included in the interactive prototype

1. **Executive overview** — group KPIs, hourly trend visualisation, exception queue, branch comparison, order queue and recent activity.
2. **Branch operations** — separate workspaces labelled Fort Street, Leopold Takawira Street and Lobengula Street. Each branch screen includes its location details, sample sales, stock valuation, alerts, orders, inventory batches and staff.
3. **Inventory & stock** — product/category search, branch-level quantity, kg/pack/piece units, reorder thresholds, unit costs and selling prices, batch / expiry watch, receive stock, discrete physical-count adjustment, inter-branch transfer, wastage and a movement ledger.
4. **Point of sale** — branch-specific catalogue, add/remove basket controls, payment-method recording, stock validation, demo checkout and stock deduction.
5. **Orders & sales** — online / WhatsApp / in-store samples, branch assignment, order status workflow, payment statuses, details, CSV export and packed-weight confirmation that recalculates the order total using the stored unit price.
6. **Delivery & dispatch** — branch-aware delivery board, driver assignment, delivery windows, route-area grouping, delivery status progression, exception monitoring and configurable delivery fee / free-delivery threshold.
7. **Suppliers & purchasing** — sample supplier directory, purchase orders and a goods-received action that updates the sample stock balance.
8. **Staff & access** — sample roster, role templates, branch assignment and a permission matrix for Owner, Group Manager, Branch Manager, Stock Controller, Cashier, Dispatch, Accountant and Viewer.
9. **Finance** — sample takings, payment channel allocation, expenses, payment reconciliation register and explicit gross-profit vs net-profit disclaimer.
10. **Reports & insights** — branch sales comparison, status mix, inventory exposure and CSV exports.
11. **Alerts & activity** — stock, expiry, payment, delivery, variance and operations issues with acknowledge/resolve actions and an activity timeline.
12. **Promotions & loyalty** — sample campaigns, coupon codes, campaign statuses, redemptions and campaign totals.
13. **Settings** — editable sample delivery rules and operational defaults, public branch directory and integration readiness.

### Working prototype behaviours

- Main navigation, branch picker, branch detail workspaces, search/filter controls, status selectors, forms, modals, toast feedback, loading transitions and CSV downloads.
- Demo changes persist in that browser using localStorage.
- Stock transfers deduct from the source branch and add to the destination branch, creating a sample ledger movement.
- POS sales validate stock, reduce on-hand stock, create a completed order and update the sample sales total.
- Order completion / packing workflow can deduct the order's recorded quantity from the related branch stock (only once per order); packed quantity changes recalculate the total.
- Purchase order receipt increases the matching inventory sample.
- Budget Intelligence offers deterministic answers based on sample data only. **It is a demo helper, not a connected LLM or live database query.**

## Run locally

This is a static JavaScript prototype with no bundler required. Clone the repository, then run npm run check to validate the application JavaScript. Open index.html in a browser or run a static server (for example, python -m http.server 8000). There is no production API or live integration in the current demo.

## Deployment

The repo is configured for a static Vercel deployment. Import ncubemphile8/budget-meat-shop-os into Vercel and select the root directory. No build command or environment variables are required for the prototype. The repository's main branch contains a GitHub Actions syntax-check workflow.

## Production architecture and go-live checklist

The supabase/schema.sql file is an initial PostgreSQL/Supabase-compatible data model with branch-scoped tables and row-level access policies for review. It has **not** been applied to a database or connected to the current frontend.

Before real operations, these items are still required and must be tested against the client's actual processes:

- Choose and provision the production database / authentication provider. Apply and security-review the schema; configure a secure account invitation process and seed the verified branch records.
- Replace localStorage storage with server APIs, enforce role and branch permissions server-side, and add database transactions / RPCs for stock, transfer, sale, returns and goods-received operations.
- Confirm the live branch names, addresses, opening hours, stock units, pricing, batch / expiry practice, delivery policy, customer data requirements, and who may approve refunds or stock adjustments.
- Confirm the existing website platform and available APIs; integrate online order and inventory synchronisation only after the client authorises access.
- Confirm their existing in-store POS, supplier / accounting workflow and data migration needs.
- Connect and test the selected Zimbabwe-supported payment providers before recording a gateway payment as verified. The prototype does not collect or process real money.
- Connect WhatsApp / notification providers and courier APIs only with authorised credentials. GPS / tracking is not connected; route grouping is currently a demo suggestion.
- Create scheduled / threshold-based server alerts, audit every sensitive operation, and define backups, access revocation, retention, data-protection, monitoring and incident response.
- Run migration tests, unit / integration tests, stock reconciliation tests, branch-permission tests, mobile/browser checks, and a supervised pilot before production use.

**Do not enter real employee, customer, stock, order, financial or credential data into this public demonstration build.** This repo is suitable for presenting the concept; the live multi-user system requires the backend and integration work listed above.
