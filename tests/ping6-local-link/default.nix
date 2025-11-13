{ lib, pkgs, ... }:
{
  name = "ping6-local-link";

  nodes = {
    machine1 = { };
    machine2 = { };
  };

  testScript = ''
    start_all()

    for m in [machine1, machine2]:
      m.wait_for_unit("network.target")

    addresses = [m.succeed("""
      ip -j -6 a sh eth1 | \
        ${lib.getExe pkgs.jq} -r '.[] | .addr_info | .[] | select((.family == "inet6") and .scope == "link") | .local' | \
        tr -d '\n'
    """) for m in [machine1, machine2]]

    # Wait for IPv6 Duplicate Address Detection (DAD) to complete.
    # The address remains "tentative" (check via `ip address`) and unusable until then, so this may take a few seconds.
    machine1.wait_until_succeeds(f"ping -c 1 {addresses[1]}%eth1")
    machine2.wait_until_succeeds(f"ping -c 1 {addresses[0]}%eth1")
  '';
}
