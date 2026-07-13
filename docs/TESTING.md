# Testing OpenHRC

No OpenBSD CI runner exists, so verification is layered.

## Automated (CI)

Runs on every push/PR:

- `yamllint .`
- `ansible-lint` (production profile)
- `ansible-playbook -i inventory/hosts.yml site.yml --syntax-check`

These catch YAML/style errors and structural mistakes in task files, but
`--syntax-check` does not render Jinja templates.

## Manual, on a Linux dev box

Template rendering errors (e.g. a bad `ipaddr()` filter call) won't surface
in `--syntax-check`. Run a dry-run against the local-connection inventory:

```
ansible-playbook site.yml --check --diff
```

This fails on OpenBSD-specific modules (`community.general.openbsd_pkg`,
`ansible.builtin.service` with OpenBSD-style args), but still renders every
`template:` task's Jinja and reports diffs -- enough to catch template logic
errors without OpenBSD hardware.

While reviewing `--check --diff` output, confirm the
`unbound-control-setup` command task in the `dns` role is skipped, since its
`creates:` guard should be honored in check mode.

## Manual, on real OpenBSD hardware/VM (pre-release checklist)

Before tagging a release:

1. Run `bootstrap.sh` then `configure.sh` on a fresh OpenBSD install with two
   network interfaces.
2. Confirm the firewall loaded: `pfctl -sr`.
3. Confirm services are enabled: `rcctl ls on`.
4. Confirm DNS resolution against unbound: `dig @<lan-ip> <hostname>.<zone>`.
5. Confirm a DHCP client actually gets a lease with the expected options.
6. Run the playbook a second time and confirm it reports no `changed` tasks
   (the `firewall` role's `pf-custom.conf` touch task is a known exception --
   `ansible.builtin.file: state=touch` always reports changed on repeat runs
   when `firewall_enable_custom_rules` is set; low-priority, not a
   correctness issue).

With `badhost_enabled: true` and `adblock_enabled: true` (after updating the
placeholder `badhost_checksum`/`adblock_checksum` values to a real pinned
release):

7. Confirm `pfctl -sr` shows the `pfbadhost` table/block rules, and
   `crontab -u _pfbadhost -l` shows the nightly job.
8. Run `doas -u _pfbadhost pf-badhost -s` manually once and confirm no
   permission errors, then `pfctl -t pfbadhost -T show` reports a populated
   table.
9. Confirm `crontab -u _unboundadblock -l` shows the job, run
   `doas -u _unboundadblock unbound-adblock -s` manually once, and confirm
   `/var/log/unbound-adblock` gets populated and `dig @<lan-ip>
   <known-blocked-ad-domain>` returns `NXDOMAIN`.

Building and maintaining an automated OpenBSD CI VM is intentionally out of
scope -- disproportionate maintenance burden for a project this size.
