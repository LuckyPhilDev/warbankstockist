## v1.4.0

### Fixed
- Reliably withdraws multiple items at once instead of stalling after the first.
- Recovers cleanly when a bank slot is briefly locked by an in-flight move.
- Avoids placing two withdrawn items into the same empty bag slot.

### Improved
- Faster withdrawals for full stacks — moved directly without cursor handoff.