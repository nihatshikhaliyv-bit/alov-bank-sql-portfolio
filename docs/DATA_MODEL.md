# Data model

## Core customer and product model

```mermaid
erDiagram
    BRANCHES ||--o{ CUSTOMERS : home_branch
    BRANCHES ||--o{ ACCOUNTS : services
    CUSTOMERS ||--o{ ACCOUNTS : owns
    CUSTOMERS ||--o{ LOANS : borrows
    ACCOUNTS ||--o{ TRANSACTIONS : records
    BRANCHES ||--o{ LOANS : originates
```

Transactions also store customer_id and branch_id. These must match the related account; the V2 insert validation enforces that consistency for new entries. The historical data checks verify it independently.

## New operation and accounting records

```mermaid
flowchart TD
    O[Bank operation] --> T[Customer transaction entries]
    T --> L[Entry links]
    L --> O
    O --> J[GL journal]
    J --> G[Debit and credit lines]
```

A single operation can produce two customer entries for a transfer. Its GL journal has balanced debit/credit lines. The posting procedures commit both layers together; a ledger failure rolls back the customer change. Reversals create a new operation linked to the original.

## Loan servicing records

```mermaid
erDiagram
    LOANS ||--o| BANK_LOAN_SCHEDULES : has
    BANK_LOAN_SCHEDULES ||--o{ BANK_LOAN_INSTALLMENTS : contains
    BANK_LOAN_INSTALLMENTS ||--o{ BANK_LOAN_PAYMENTS : receives
    BANK_OPERATIONS ||--o| BANK_LOAN_PAYMENTS : records
```

`branch_financials` is a separate annual summary table. Its balances reconcile to the snapshot detail, but its income is not a complete historical ledger. See the financial analysis for this distinction.
