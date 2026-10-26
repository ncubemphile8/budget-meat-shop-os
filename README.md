# BudgetOS — Budget Meat Shop Operations

A branded, multi-branch retail operations prototype for Budget Meat Shop, developed by VanillaWebz.

> **Demo environment:** all orders, staff, inventory, sales and finance numbers shown in the initial prototype are illustrative sample data. No connection to Budget Meat Shop's private systems is implied.

## Run locally

This is a static JavaScript application with no build step. Open `index.html` in a browser, or serve the directory with any static file server.

## Planned modules

- Executive overview and branch performance
- Fort Street, Leopold Takawira Street, and Lobengula Street branch workspaces
- Weight-based inventory, stock movements, batches/expiry, transfers and wastage
- Orders, order fulfilment and payment status
- Delivery and dispatch board, driver assignment and exception alerts
- Suppliers and purchase orders
- Staff roster and role/permission matrix
- Finance, reconciliation, expenses and gross-margin estimates
- Reports and CSV export
- Alerts/activity centre, promotions and settings

## Production requirements before live operations

- Add server-backed authentication and enforce role/branch permissions on the server.
- Add a managed PostgreSQL database and migrations.
- Integrate the client's existing point-of-sale and online storefront only after confirming their platform and API access.
- Integrate supported Zimbabwean payment and messaging providers if required.
- Validate branch details, delivery rules, tax/accounting treatment and reporting with management.
- Add automated tests, audit logs, backups, monitoring, privacy/security review and a staged rollout.

## Branding & visual media

Uses Budget Meat Shop's publicly served logo and product imagery, with a meat-preparation video from Pexels for demo visuals. Remote media loads from their respective hosts. A static fallback is provided for the video.
