
# OpenHRC changelog

## Unreleased

### Added
- `badhost` role: installs and cron-schedules [pf-badhost][pf-badhost],
  which maintains a `pf` table of known-bad hosts from public blocklists.
  Disabled by default (`badhost_enabled: false`); the script is fetched
  directly from upstream and pinned by checksum (not an OpenBSD package).
- `adblock` role: installs and cron-schedules
  [unbound-adblock][unbound-adblock], which blocks ad/tracker domains via an
  `unbound` Response Policy Zone. Disabled by default
  (`adblock_enabled: false`); same fetch-and-pin delivery as `badhost`.
- Both roles contribute narrowly-scoped `doas` rules to the (now templated)
  `/etc/doas.conf`, gated on their respective `_enabled` flag.

[pf-badhost]: https://www.geoghegan.ca/pfbadhost.html
[unbound-adblock]: https://www.geoghegan.ca/unbound-adblock.html

## 2.0.0 - Ansible modernization rewrite

### Changed
- Restructured the flat playbook into per-feature roles (base, network,
  firewall, dns, dhcp, ntp, upnp, ddns).
- Flattened all `vars.yml` dict variables into role-namespaced flat
  variables (e.g. `dns.recursive.forwarders` -> `dns_recursive_forwarders`).
- Replaced the `local-vars.yml` + `-e @local-vars.yml` override pattern with
  `inventory/group_vars/router/vars.yml` (plaintext overrides) and
  `inventory/group_vars/router/vault.yml` (ansible-vault-encrypted secrets).
- Modernized all tasks to FQCN modules and YAML-dict argument syntax, and
  replaced `with_items`/`with_dict` with `loop`.
- Added handlers so templated config changes actually take effect instead of
  silently requiring a manual reboot, favoring a live reload over a full
  restart wherever the daemon actually supports one (unbound, miniupnpd,
  inadyn reload; dhcpd and ntpd restart, since neither supports a live
  reload on OpenBSD; pf is validated with `pfctl -nf` before ever being
  written to disk, then reloaded with `pfctl -f`).
- Added GitHub Actions CI (yamllint, ansible-lint on the `production`
  profile, `ansible-playbook --syntax-check`) -- lint/syntax validation
  only, since no OpenBSD CI runner exists.
- Added `requirements.yml` pinning `community.general` (for `openbsd_pkg`).
- Renamed `ntp.enabled` to `ntp_serve_lan_clients` to reflect what it
  actually controls: whether ntpd also listens on the LAN and serves the
  internal network, not whether the router syncs its own clock (ntpd is
  always enabled for that).

### Removed
- Dead `templates/home.lan.zone` leftover from the pre-2020 NSD-based
  design.
- The deprecated `hash_behaviour = merge` setting from `ansible.cfg`.

### Fixed
- `network_wan_gateway_enabled`/`network_wan_gateway_address` and
  `firewall_enable_wan_ssh`/`firewall_wan_ssh_external_port` replace two
  variables that used to overload a single key with mixed types (bool vs.
  IP string; int port vs. the string `"no"`).

## 1.0.0 (31/01/2016)

- First release, FOSDEM edition
