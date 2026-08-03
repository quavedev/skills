---
name: quave-enums
description: Enum conventions using the @quave/enum createEnum factory — never use loose strings for enum values; always reference entries via .name or .value, drive SimpleSchema allowedValues/defaultValue from the enum, and prefer boolean flags on entries over string-comparison chains. Use when creating an enum, adding values to one, storing enum values in a collection, comparing enum values, or building UI options from an enum.
---

# Enum conventions

The single reference for creating, storing, and using enums. Read it before creating a
new enum, adding a value, storing an enum value in a collection, or comparing an enum
value in code.

## TL;DR — The One Rule You Must Not Break

**Never use loose strings for enum values. Always reference the enum entry via `.name`
(or `.value` when the enum has a `value` property).**

```javascript
if (status === OrderStatus.SHIPPED.name) { /* ... */ }   // ✅
if (status === 'SHIPPED') { /* ... */ }                   // ❌ Loose string

saveOrder({ status: OrderStatus.PENDING.name });          // ✅
saveOrder({ status: 'PENDING' });                         // ❌ Loose string

const level = LogLevels.ERROR.value;                      // ✅ (enum has `value`)
const level = 'error';                                    // ❌ Loose string
```

Loose strings bypass IDE refactoring, hide broken references when a key is renamed, and
defeat grep-based coverage audits. If you catch yourself typing a bare `'SOME_STATUS'`
string, stop and reference the enum instead.

## The `createEnum` factory

Enums are built with `createEnum` from the `@quave/enum` package (zero dependencies).
Install with `meteor npm install @quave/enum` (or plain `npm install` outside Meteor).

```javascript
import { createEnum } from '@quave/enum';

export const OrderStatus = createEnum({
  PENDING: { label: 'Pending' },
  PROCESSING: { label: 'Processing' },
  SHIPPED: { label: 'Shipped' },
  DELIVERED: { label: 'Delivered' },
});
```

`createEnum` returns the same shape with two auto-generated fields per entry:

- **`name`** — the key itself (e.g. `'PENDING'`)
- **`index`** — the declaration order (0, 1, 2, ...)

```javascript
OrderStatus.PENDING;        // { name: 'PENDING', index: 0, label: 'Pending' }
OrderStatus.SHIPPED.name;   // 'SHIPPED'
OrderStatus.SHIPPED.label;  // 'Shipped'
```

`defaultFields` are merged into every entry (per-entry values override):

```javascript
export const Permissions = createEnum(
  {
    VIEWER: { label: 'Viewer' },
    EDITOR: { label: 'Editor', canEdit: true },
    ADMIN: { label: 'Admin', canEdit: true, canDelete: true },
  },
  { defaultFields: { canEdit: false, canDelete: false } }
);

Permissions.VIEWER.canEdit; // false (from defaultFields)
Permissions.EDITOR.canEdit; // true  (overridden)
```

## File locations

Enums must be importable by **both client and server**, so they live under `app/`.

| Location | Purpose |
|----------|---------|
| `app/<domain>/<EnumName>.js` | Enum owned by a single domain — co-locate with that domain's collection/logic. |
| `app/enums/<EnumName>.js` | Cross-domain enum used by several domains (create the folder when the first one appears). |

Prefer co-location (`app/orders/OrderStatus.js`); only promote to `app/enums/` once it
is genuinely shared across domains. One enum per file, named after the enum.

## Naming conventions

| Element | Convention | Example |
|---------|------------|---------|
| Enum name | PascalCase (singular or plural, be consistent) | `OrderStatus`, `LogLevels`, `UserRoles` |
| File name | Matches the enum name | `OrderStatus.js` |
| Keys | SCREAMING_SNAKE_CASE | `PENDING`, `IN_TRANSIT`, `OUT_OF_STOCK` |
| `label` | Human-readable | `'Pending'`, `'Out of Stock'` |
| `value` | lowercase / snake_case (only when needed) | `'error'`, `'out_of_stock'` |

## When to use the `value` property

Decision rule: **do we control the stored data format, or does an external system?**

- **Without `value` (default)** — we control the data. The DB stores the KEY (identical
  to `.name`); renames stay safe.
- **With `value`** — an external system dictates the format (third-party API, legacy
  database, protocol, OAuth scopes). Use `value` to match exactly what the external
  system requires:

  ```javascript
  export const LogLevels = createEnum({
    ERROR: { value: 'error', label: 'Error', severity: 1 },
    WARN:  { value: 'warn',  label: 'Warning', severity: 2 },
    INFO:  { value: 'info',  label: 'Info', severity: 3 },
  });
  ```

If no external constraint applies, **do not add `value`** — keys are simpler and
rename-safe.

## Storing enums in Mongo (SimpleSchema)

Drive `allowedValues` and `defaultValue` from the enum — never hand-type the strings.

### Standard enums (no `value`) — store the KEY

```javascript
import { createCollection } from 'meteor/quave:collections';
import SimpleSchema from 'simpl-schema';
import { OrderStatus } from './OrderStatus';

const OrderSchema = new SimpleSchema({
  status: {
    type: String,
    defaultValue: OrderStatus.PENDING.name,   // "PENDING"
    allowedValues: Object.keys(OrderStatus),  // ["PENDING", "PROCESSING", ...]
  },
});

export const OrdersCollection = createCollection({
  name: 'orders',
  schema: OrderSchema,
});
```

### Enums with `value` — store the VALUE

```javascript
import { LogLevels } from '../enums/LogLevels';

const LogEntrySchema = new SimpleSchema({
  level: {
    type: String,
    defaultValue: LogLevels.INFO.value,                                // "info"
    allowedValues: Object.values(LogLevels).map(({ value }) => value), // ["error", "warn", "info"]
  },
});
```

## Accessing enum properties

```javascript
// Direct access (key known)
const status = OrderStatus.SHIPPED.name;   // "SHIPPED"
const label  = OrderStatus.SHIPPED.label;  // "Shipped"

// Dynamic access (from a database value — standard enums store the key)
const statusEnum = OrderStatus[order.status];
const label = OrderStatus[order.status]?.label || order.status; // safe with fallback

// Finding by value (enums with `value`) — export a helper from the enum file
export const getLogLevelByValue = (value) =>
  Object.values(LogLevels).find((level) => level.value === value);
```

## Comparing enum values

Always compare against `.name` (or `.value`), never a literal. Prefer **boolean flags**
on the enum over chains of string comparisons:

```javascript
export const OrderStatus = createEnum({
  PENDING:    { label: 'Pending',    canCancel: true,  canEdit: true },
  PROCESSING: { label: 'Processing', canCancel: true,  isInProgress: true },
  SHIPPED:    { label: 'Shipped',    isInProgress: true },
  DELIVERED:  { label: 'Delivered',  isComplete: true },
});

const status = OrderStatus[order.status];
if (status.canCancel)    showCancelButton();   // ✅ expressive, centralized
if (status.isInProgress) showTracker();

// ❌ if (order.status === 'PENDING' || order.status === 'PROCESSING') { ... }
```

## Iterating over enums

```javascript
const allStatuses = Object.values(OrderStatus);
const allKeys = Object.keys(OrderStatus);
const cancelable = Object.values(OrderStatus).filter((s) => s.canCancel);

// Build UI options (e.g. a <select>)
const options = Object.values(OrderStatus).map(({ name, label }) => ({
  value: name,
  label,
}));
```

## Common patterns

```javascript
// Referencing other enums — store the .name, not a literal
import { Categories } from './Categories';

export const Products = createEnum({
  LAPTOP:  { label: 'Laptop',  category: Categories.ELECTRONICS.name },
  T_SHIRT: { label: 'T-Shirt', category: Categories.CLOTHING.name },
});

// Helper exports co-located with the enum
export const getLogLevelByValue = (value) =>
  Object.values(LogLevels).find((level) => level.value === value);

export const LOG_LEVEL_VALUES = Object.values(LogLevels).map(({ value }) => value);
```

## Quick reference

| Task | Pattern |
|------|---------|
| Create enum | `export const Name = createEnum({ KEY: { label: '...' } })` |
| Import factory | `import { createEnum } from '@quave/enum'` |
| Get key/name | `EnumName.KEY.name` |
| Get value | `EnumName.KEY.value` |
| Dynamic access | `EnumName[statusString]` |
| DB `allowedValues` (key) | `Object.keys(EnumName)` |
| DB `allowedValues` (value) | `Object.values(EnumName).map(({ value }) => value)` |
| DB `defaultValue` (key) | `EnumName.KEY.name` |
| DB `defaultValue` (value) | `EnumName.KEY.value` |
| Filter entries | `Object.values(EnumName).filter((e) => e.prop)` |
| Find by value | `Object.values(EnumName).find((e) => e.value === val)` |
| Compare | `x === EnumName.KEY.name` (never a literal) |
