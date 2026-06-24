# Role Metrics Index

Role metrics live under this directory by role and share helpers in `_shared/`.

- assassin/
  - assassin_role_identity_test.gd (`role_assassin_identity`)
- brawler/
  - brawler_role_identity_test.gd (`role_brawler_identity`)
- mage/
  - mage_role_identity_test.gd (`role_mage_identity`)
- marksman/
  - marksman_role_identity_test.gd (`role_marksman_identity`)
- support/
  - support_role_identity_test.gd (`role_support_identity`)
- tank/
  - tank_role_identity_test.gd (`role_tank_identity`)
- roles/
  - roles_thresholds.json (central thresholds for metrics)
- _shared/
  - role_common.gd, context_builder.gd: helpers and context loading

To list all metrics programmatically: see `MetricRegistry.list_metrics()`.
