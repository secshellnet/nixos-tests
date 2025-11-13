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
