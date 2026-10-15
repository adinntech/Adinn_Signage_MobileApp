# Signage Recce Mobile – Project Rules

Full global rules: `D:\Projects\Signage\.claude\skills\adinn-signage-crm\SKILL.md` (skill `adinn-signage-crm`). Read it before building or changing any screen. This file summarizes the Flutter-relevant parts.

Stack: Flutter + Dart, Riverpod, Dio, go_router. Field app for recce executives and vendors (offline-first). Talks only to the backend `/api/v1`.

## Workflow
- Existing project: inspect first, reuse working code, no unnecessary refactoring.
- Build only the requested screen/stage; wait for approval before the next.
- Before a screen, inspect relevant images in `docs/ui-references/` and match them, adapted to touch/field use.

## Design system
Primary Navy #102449, Royal Blue #2563EB, BD #2563EB, Recce #0D9488, Vendor #9333EA, Planning #F59E0B, Approval #F97316, Finance #059669, Rejection/Loss #DC2626, Background #F4F7FC, Cards #FFFFFF. Keep one consistent theme in `core/theme`; no per-screen palette changes. Avoid tiny labels, poor contrast, decorative inactive buttons, overcrowded screens.

## Structure and reuse
```
lib/core/{api,auth,config,constants,error,routing,theme,utils,widgets}
lib/features/{authentication,dashboard,assignments,dealer_confirmation,route_tracking,field_recce,measurements,board_options,photos,acknowledgement,expenses,approvals,synchronization}
lib/shared/{models,widgets,services}
```
Reuse or create once: AppScaffold, AppTopBar, AppBottomNavigation, AppTextField, AppDropdown, AppDatePicker, AppStatusChip, AppInfoCard, AppPrimaryButton, AppLoadingView, AppErrorView, AppEmptyView, AppFilePicker, AppPhotoPicker, AppSignaturePad, AppConfirmationDialog, AppProgressStepper, AppFormSection, AppDocumentPreview. Avoid near-duplicate widgets.

Use the existing Riverpod setup; do not introduce a second state management approach.

## Centralized services
One Dio API client (base URL, token interceptor, standard response model, central error mapper, upload support, timeouts), secure token storage, file upload service, notification service, offline sync service, theme config. No HTTP calls from widgets.

Standard response: `{ success, message, data, meta }` / `{ success: false, message, error: { code, details } }`.

## Business rules
Do not maintain separate business rules. Costs, square feet, statuses and approvals come from the backend; local calculations are previews only. Reuse backend field definitions, workflow statuses and validation specs.

## Field UX
Touch-friendly targets, minimal typing, auto-fill project/client/shop data, searchable dropdowns, conditional fields, step forms, inline validation, offline drafts, background sync, confirm destructive actions, loading/success/error/empty states. Measurements captured here must flow to recce verification, exports, PPT, estimation, approval and handover without re-entry. Raw and annotated photos are separate.

## Animation
Native APIs only (AnimatedContainer, AnimatedSwitcher, Hero, AnimatedList, ExpansionTile). Avoid distracting animation during measurements and expense submission.

## Scrolling
Use ScrollController, ListView, CustomScrollView, NestedScrollView or slivers appropriately; no nested uncontrolled scroll views. Test long forms, small screens, keyboard open, modals.

## Performance
Paginated/lazy lists, local caching, image compression, offline drafts, background sync, dispose controllers and subscriptions.

## Security and env
No secrets in the app. Use `--dart-define` (or the established method) for non-secret values only, and document the example. Tokens only in secure storage.

## Testing
`flutter analyze`, widget tests, relevant integration tests, Android execution where available. No decorative Save/Submit/Upload/Approve/Export.

## Completion report
Completed screens, reused widgets, new shared widgets, modified files, API routes used, env/dart-define names only, tests and results, manual verification steps, known issues, next recommended stage. No secrets. Then wait for approval.

## When to load the full skill
Before building or changing any screen, API, model, workflow or shared component, invoke the `adinn-signage-crm` skill first (Skill tool) and follow it. Skip it for trivial questions, small fixes and non-code chat.
