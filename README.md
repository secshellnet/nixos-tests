# nixos-tests

This repository contains a collection of integration tests built using the NixOS
test framework to verify the functionality and interoperability of various services,
network components, and configurations within NixOS environments.

The majority of tests target networking functionality. NixOS supports multiple
networking implementations, including
[systemd-networkd](https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html),
[NetworkManager](https://networkmanager.dev/),
and [IfState](https://ifstate.net).


These tests aim to ensure that these implementations function correctly both
independently and in combination, validating interoperability between them and
with other software components.

## Contribution
Feel free to open issues to report bugs or suggest improvements. Pull requests of any scope are welcome.
Please ensure that all submitted changes are correct, reproducible, and successfully pass the existing test
suite. Verify that your modified or new tests execute successfully, are reliable (non-flaky), and follow
the patterns used in the existing test suite.

To maintain clarity and consistency in network-related tests, always use documentation-reserved domain names,
ASNs, and IP address ranges. These reserved values ensure tests are clearly identifiable as examples and avoid
any ambiguity when interpreting test results.

| Category                    | Values                                        | Reference                                          |
|-----------------------------|-----------------------------------------------|----------------------------------------------------|
| Documentation ASN           | 64496..64511, 65536..65551                    | [RFC 5398](https://www.rfc-editor.org/rfc/rfc5398) |
| Documentation domain names  | example.com, example.net, example.org         | [RFC 2606](https://www.rfc-editor.org/rfc/rfc2606) |
| IPv4 documentation prefix   | 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24 | [RFC 5737](https://www.rfc-editor.org/rfc/rfc5737) |
| IPv6 documentation prefix   | 2001:db8::/32                                 | [RFC 3849](https://www.rfc-editor.org/rfc/rfc3849) |
| IPv6 documentation prefix   | 3fff::/20                                     | [RFC 9637](https://www.rfc-editor.org/rfc/rfc9637) |

Ensure that all Nix code is formatted and linted using [NixOS RFC 0166](https://github.com/NixOS/rfcs/blob/master/rfcs/0166-nix-formatting.md)
by running `nixfmt-rfc-style` and `deadnix` before submitting a pull request.
