# OpenHRC

OpenHRC (Open Household Router Contraption) is a set of [Ansible][ansible]
roles and playbooks to easily setup and maintain a home router running
[OpenBSD][openbsd].


## Overview

OpenHRC implements the basic networking services for a household, running the
following (quite common) scenario:

~~~~~~
          +--------------+
          | The Internet |
          +------+-------+
                 |
                 v
         +-------+---------+
         |   Cable modem   |
         +-------+---------+
                 |
                 v
            +----+-----+
     +------+ OpenHRC  +-------+
     |      +----------+       |
     v                         |
+----+-----+                +--+--+
| Home LAN |                | DMZ |
+----------+                +-----+
~~~~~~

Included services:

* DHCP
* NTP
* Local caching and validating DNS resolver
* Authoritative DNS server for a configurable zone
* Firewall
* Bad-host IP blocklisting (pf-badhost)
* DNS-based ad blocking (unbound-adblock)
* UPnP
* DDNS


## Hardware

OpenHRC should work on any device which can run [OpenBSD][openbsd] and has at
least 2 network interfaces. We have tested it successfully on the following
devices:

* [PC Engines APU][apu]
* [Soekris net4801][soekris]

This project targets the latest stable OpenBSD release (currently 7.9) and
does not attempt to remain compatible with older releases.


## Repository layout

```
openhrc/
├── site.yml                      # the entry-point playbook
├── inventory/
│   ├── hosts.yml                 # the "router" group -- this box, managed locally
│   └── group_vars/router/
│       ├── vars.yml.example      # copy to vars.yml, override what you need
│       └── vault.yml.example     # copy to vault.yml, encrypt with ansible-vault
└── roles/
    ├── base/                     # hostname, mirror, generic packages, sysctls, doas
    ├── network/                  # network interfaces, default gateway
    ├── badhost/                  # pf-badhost: bad-host IP blocklist for pf
    ├── firewall/                 # pf
    ├── adblock/                  # unbound-adblock: DNS-based ad blocking for unbound
    ├── dns/                      # unbound: recursive resolver + local "authoritative" records
    ├── dhcp/                     # dhcpd, ethers
    ├── ntp/                      # ntpd
    ├── upnp/                     # miniupnpd
    └── ddns/                     # inadyn
```

Every role has its own `defaults/main.yml` listing every variable it accepts,
with a short description. That's the authoritative reference for what you can
configure -- `vars.yml.example` just shows the most commonly-overridden ones.


## Installation

Watch [the video!][video]

OpenHRC assumes you have successfully installed [OpenBSD][openbsd] in your
contraption.

Once you have installed [OpenBSD][openbsd] you are ready to install OpenHRC.

* Download and execute the bootstrap script (as root)
~~~~~~
  ftp -o - https://raw.githubusercontent.com/ioc32/openhrc/master/bootstrap.sh | sh
~~~~~~
  We know, piping things from the internet to the shell directly is not a good
  idea... You're more than welcome to check the contents of the script, which
  basically just installs a few basic packages, clones this repository, and
  installs the required Ansible collections.
  Alternatively, you can clone this repo and manually run the bootstrapping
  script (you'll need to install git first):
~~~~~~
  git clone https://github.com/ioc32/openhrc && cd openhrc
  ./bootstrap.sh
~~~~~~
* Review each role's `defaults/main.yml` for available variables, and override
  the ones you need in `inventory/group_vars/router/vars.yml` (bootstrap.sh
  creates it for you from `vars.yml.example`).
* Put secrets (currently just the DDNS hash) in
  `inventory/group_vars/router/vault.yml` and encrypt it:
~~~~~~
  ansible-vault encrypt inventory/group_vars/router/vault.yml
~~~~~~
* Run `./configure.sh` (it will prompt for your vault password).
* Reboot and have fun!


## Continuous integration

Every push/PR runs `yamllint`, `ansible-lint` (production profile), and
`ansible-playbook --syntax-check` via GitHub Actions. This validates lint and
syntax only -- there is no maintained OpenBSD GitHub Actions runner or OpenBSD
container image, so CI cannot exercise the playbook against real OpenBSD
runtime behavior. See `docs/TESTING.md` for the manual OpenBSD verification
runbook used before releases.


## Authors

Brought to you by:

* Iñigo Ortiz de Urbina Cazenave <inigo@infornografia.net>
* Saúl Ibarra Corretgé <saghul@gmail.com>

with love.


## License

Simplified BSD License. Check LICENSE file.

[ansible]: http://www.ansible.com
[openbsd]: http://www.openbsd.org
[apu]: http://www.pcengines.ch/apu.htm
[soekris]: http://soekris.com/products/eol-products/net4801.html
[video]: https://www.youtube.com/watch?v=LZeKDM5jc90


## FAQ

**Q:** I have bad throughput in my system, what's up?

**A:** If you are using a snapshot you might need to disable some kernel debugging:
~~~~~~
sysctl kern.pool_debug=0
~~~~~~

**Q:** How do I forward a range of ports?

**A:** When defining a port forwarding, the external_ports and internal_ports options
can take a port range, using a colon:
~~~~~~
firewall_port_forwardings:
  -
    external_ports: 5000:6000
    target: 10.0.0.51
    internal_ports: 2000:3000
    protocols: udp,tcp
~~~~~~

**Q:** No IPv6 support, are you serious?

**A:** It's a known long-standing gap (`base_sysctls` already enables
`net.inet6.ip6.forwarding`, but there's no IPv6 pf/DHCPv6/AAAA support yet).
Not part of this rewrite -- tracked as future work alongside DoH/DoT and
traffic filtering.

**Q:** How can I override the variables used in the playbooks?

**A:** Every role ships sensible defaults in its own `roles/<role>/defaults/main.yml`.
Override only the specific variables you need in
`inventory/group_vars/router/vars.yml` (copy it from `vars.yml.example`) --
Ansible's normal variable precedence means your override wins over the role
default without needing to restate anything else.

**Q:** My favorite site/TLD have screwed their DNSSEC. Is there anything I can do?

**A:** You can either disable DNSSEC validation entirely (not recommended):
~~~~~~
dns_recursive_enable_dnssec_validation: false
~~~~~~
or enable the permissive validation mode, which will ensure unbound keeps validating domains and passing responses down to clients even when validation fails (ad bit and SERVFAIL RCODE will not be set, of course):
~~~~~~
dns_recursive_enable_dnssec_validation: true
dns_recursive_permissive_dnssec_validation: true
~~~~~~

You may also need to remove all bogus data from unbound's cache:
~~~~~~
# unbound-control flush_bogus
ok removed 0 rrsets, 0 messages and 0 key entries
~~~~~~
or remove all labels below the broken zone:
~~~~~~
# unbound-control flush_zone ke.
ok removed 10 rrsets, 0 messages and 1 key entries
~~~~~~

**Q:** How can I configure the authoritative DNS server?

**A:** The default zone is "home.lan", you can override it and create custom records by editing
`inventory/group_vars/router/vars.yml`:

~~~~~~
dns_authoritative_zone: kasa.lan
dns_authoritative_records:
  - foo.kasa.lan IN A 10.0.0.20
  - bar.kasa.lan IN A 10.0.0.30
~~~~~~

**Q:** Is the authoritative DNS server accessible externally?

**A:** There is no separate authoritative DNS server -- an earlier design used
[NSD](https://www.nlnetlabs.nl/projects/nsd/about/) bound to localhost with
unbound forwarding to it, but that was removed in 2020. Today unbound (the
`dns` role) serves the configured zone's records directly via `local-data`/PTR
static entries alongside its normal recursive-resolver duties, and it's bound
to the LAN interface only -- it was never reachable from the WAN either way.

**Q:** How can I perform a clean re-install/upgrade of OpenBSD?

**A:** From the existing installation, fetch the appropriate `bsd.rd` for the release you wish to install:

~~~~~~
# ftp -o /bsd-installer.rd https://cdn.openbsd.org/pub/OpenBSD/${RELEASE}/amd64/bsd.rd
~~~~~~

Compare the output of `sha256(1)` against that listed in `https://cdn.openbsd.org/pub/OpenBSD/${RELEASE}/amd64/SHA256`.

Console your contraption and reboot the system. Upon reboot, the kernel loader prompt will appear.
Configure the serial output for the re-installation process:

~~~~~~
>> OpenBSD/amd64 BOOT 3.43
boot> stty com0 115200

com0: 115200 baud
boot> bsd-installer.rd
~~~~~~

The OpenBSD Ram Disk will greet you, proceed as required:

~~~~~~
Welcome to the OpenBSD/amd64 X.X installation program.
(I)nstall, (U)pgrade, (A)utoinstall or (S)hell?
~~~~~~

A future release of OpenHRC will automate this upgrade process as a playbook
run from the router itself; for now it remains a manual procedure.
