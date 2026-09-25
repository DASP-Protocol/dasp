# Use cases

These examples describe possible applications. They do not define standard profiles or shipped integrations.

## Agent work that outlives an interface

A web application asks a report actor to produce a report. The application closes before the work completes. A later connection reads the saved outcome and the updates after its cursor.

A report profile would define the request fields, the report reference, and what completed means. Approval, attachments, and model selection would belong to that profile. A `report.create` command is illustrative, not part of the DASP core.

## An operator and automation share a session

A service submits work while an operator follows its progress. Both clients read the same ordered session history. They keep separate cursors and use the host's current access policy.

The profile decides which concurrent operations are valid. A shared history alone does not resolve competing application edits.

## A workflow reports durable results

A workflow actor starts a job, saves application facts, and records an outcome. Temporary activity messages help a user interface. Only saved facts establish recovery state.

If an external effect cannot be established after a crash, the host records uncertainty. The application defines the next reconciliation action.

## When the core is not enough

DASP does not supply an execution engine, scheduler, queue policy, database, or model API. It also does not define presence or shared text editing. Choose or define the application profile and transport binding before attempting a live integration.

See [Add DASP to your project](../build/README.md).
