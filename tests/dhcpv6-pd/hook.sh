# https://kea.readthedocs.io/en/latest/arm/hooks.html#run-script-run-script-support-for-external-hook-scripts
# This script adds/removes IPv6 routes on prefix-delegation from KEA/DHCP server

lease6_renew () {
    if [ "$LEASE6_TYPE" = "IA_PD" ]; then
       # Add route for delegated prefix (next hop is the client)
       ip -6 route replace "${LEASE6_ADDRESS}/${LEASE6_PREFIX_LEN}" via "${QUERY6_REMOTE_ADDR}" dev "${QUERY6_IFACE_NAME}" proto static
    fi
    exit 0

}

lease6_expire () {
    if [ "$LEASE6_TYPE" = "IA_PD" ]; then
       # Remove route for delegated prefix
       ip -6 route del "${LEASE6_ADDRESS}/${LEASE6_PREFIX_LEN}" proto static
    fi
    exit 0
}

leases6_committed () {
    # TODO: If i.e. addresses are also available via DHCP, there can be more than a single AT[index], so Loop 0..($LEASES6_SIZE-1)
    # if [ "$LEASES6_AT0_TYPE" = "IA_NA" ]; then it's an address
    if [ "$LEASES6_AT0_TYPE" = "IA_PD" ]; then
       # Add route for delegated prefix (next hop is the client). Remote-addr (via) will typically be LinkLocal, unless KEA listens on Unicast
       ip -6 route replace "${LEASES6_AT0_ADDRESS}/${LEASES6_AT0_PREFIX_LEN}" via "${QUERY6_REMOTE_ADDR}" dev "${QUERY6_IFACE_NAME}" proto static
    fi
    exit 0
}

lease6_release () {
    if [ "$LEASE6_TYPE" = "IA_PD" ]; then
       # Remove route for delegated prefix
       ip -6 route del "${LEASE6_ADDRESS}/${LEASE6_PREFIX_LEN}" proto static
    fi
    exit 0
}

case "$1" in
    "lease6_renew")
        lease6_renew
        ;;
    "lease6_expire")
        lease6_expire
        ;;
    "leases6_committed")
        leases6_committed
        ;;
    "lease6_release")
        lease6_release
        ;;
esac
