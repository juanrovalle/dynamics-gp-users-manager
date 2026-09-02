# Operations and SQL administration

Normal users operate through the Windows console. See the complete installation/testing guide for the customer workflow.

## Database objects

- gpManagerSettings: activation, transaction policy, notification policy, GP/Dex bindings, commercial registration, revision token.
- gpManagerRuntime: latest completion UTC, outcome and error number. Job ticks do not change the settings revision.
- gpManagerAudit: manual/automatic outcomes and administration changes.
- gpManagerNotification: local outbox, native queue timestamp and status.
- gpManagerDepartment / gpManagerUser: preserved legacy data with constraints and revision tokens.

SP_GPUM_SAVE_DEPARTMENT, SP_GPUM_ASSIGN_USER, SP_GPUM_UNASSIGN_USER and SP_GPUM_SAVE_SETTINGS enforce validation and optimistic concurrency in SQL. Administrative mutations own their transactions, roll back on error and reject ambient caller transactions.

SP_GPUM_SET_AUTOMATION changes the setting read by every engine execution. Enabling native notifications requires a test message and administrator confirmation of its observation. Observation is an administrator assertion, not a GP read receipt.

## Roles and cross-database permissions

gpManagerReader reads reports/settings/history and previews. gpManagerAdmin executes administration procedures; the wizard also grants reader membership. gpManagerAutomation executes the quota procedure. The legacy gpManagerOperator role is reserved for explicit DBA-controlled manual cleanup.

Cross-database access is granted explicitly. Operating users receive required GP SELECT permissions; administrators also need the native-message insert/schema permissions for the test. The runtime login receives only the required GP/Dexterity table permissions and manager execution role. Existing broader permissions are not automatically removed.

The selected SQL Agent owner must be sysadmin. Its step restores tempdb user/grants after restart, then executes as the selected restricted engine login. The owner is an explicit installation choice, not automatically the installer. No passwords appear in job commands.

## Automatic execution

SP_LOGOUTGPUSER_BY_QUOTE with no parameters reads persistent policy and respects pause. ProtectActiveTransactions and NotifyInGP optional parameters override the stored policies for that call; the job created by the console does not pass overrides. DryRun=1 delegates to the read-only preview.

The engine removes at most one candidate, never selects disabled departments, checks ambiguous/shared session IDs and uses the gpManager.cleanup application lock. Pause/configuration changes use the same lock. GP record removal does not close the client or KILL SQL sessions.

A notification failure rolls the transaction back. An error is audited and rethrown so Agent can mark the job failed. Inspect last_outcome as well as last_completed_at: a recent error is still a recent execution.

The “Sin ejecución reciente” indicator is based only on a three-minute threshold. Check Agent history, job configuration, SQL connectivity, permissions and server restart state to diagnose it.

## Maintenance

Back up manager, GP databases and job definitions before upgrades. Keep the same manager/GP binding; the installer refuses a binding change or a newer schema. A failed new install can leave an empty manager database; review and retry rather than deleting customer databases automatically.

The wizard detects direct references to SP_LOGOUTGPUSER_BY_QUOTE. Review custom wrappers or external schedulers manually. Deselected jobs are disabled, not deleted. The wizard adds grants; SQL permission revocation remains a DBA task.

Disabling a department stops quota enforcement for it. Removing a user assignment never deletes a GP account. Retain audit/outbox data according to the customer's policy; no automatic retention purge is configured.

For full retirement: explicitly pause, verify the PAUSED outcome, have the DBA disable the product's job, back up retained data, then uninstall the console. Database deletion is not part of uninstall.

