#!/bin/bash

LOG_FILE="netcheck_$(date +%Y%m%d_%H%M%S).log"
TMP_FILE=$(mktemp)

echo "============================================"
echo "Tailscale Batch Netcheck v3.1 (Stable Core)"
echo "Start: $(date '+%F %T')"
echo "============================================"
echo ""

run_netcheck() {
    NAME="$1"
    TARGET="$2"

    printf "[RUN ] %-22s ...\n" "$NAME"

    if [ "$TARGET" = "local" ]; then
        OUTPUT=$(tailscale netcheck --format=json-line 2>/dev/null | tail -n 1)
    else
        OUTPUT=$(timeout 8 ssh \
            -o ConnectTimeout=5 \
            -o BatchMode=yes \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$TARGET" \
            "tailscale netcheck --format=json-line 2>/dev/null | tail -n 1" \
            2>/dev/null)
    fi

    echo "$NAME >>> $OUTPUT" >> "$LOG_FILE"

    # JSON 校验
    if ! echo "$OUTPUT" | jq -e . >/dev/null 2>&1; then
        printf "[DONE] %-22s → FAIL (SSH/ERROR)\n" "$NAME"
        printf "%-22s %-6s %-6s %-15s %-8s\n" \
            "$NAME" "-" "-" "-" "FAIL" >> "$TMP_FILE"
        return
    fi

    UDP=$(echo "$OUTPUT" | jq -r '.UDP // "-"')
    IPV6=$(echo "$OUTPUT" | jq -r '.IPv6 // "-"')
    DERP=$(echo "$OUTPUT" | jq -r '.NearestDERP // "-"')

    if [ "$UDP" = "true" ]; then
        if [ "$IPV6" = "true" ]; then
            STATE="EXCELLENT"
        else
            STATE="OK"
        fi
    else
        STATE="DERP"
    fi

    printf "[DONE] %-22s → %-9s (%s)\n" "$NAME" "$STATE" "$DERP"

    printf "%-22s %-6s %-6s %-15s %-8s\n" \
        "$NAME" "$UDP" "$IPV6" "$DERP" "$STATE" >> "$TMP_FILE"
}

# -------------------------
# 1️⃣ 运行本机
# -------------------------

LOCAL_NAME=$(hostname)
run_netcheck "$LOCAL_NAME" "local"

# -------------------------
# 2️⃣ 生成远程节点列表（先完整写入数组）
# -------------------------

mapfile -t NODE_ARRAY < <(
    tailscale status --json | jq -r '
    .Peer[]
    | select((.OS|ascii_downcase)=="linux")
    | select(.Online==true)
    | select(.TailscaleIPs != null)
    | .HostName + " " + .TailscaleIPs[0]
    '
)

# -------------------------
# 3️⃣ 遍历数组（绝对不会丢）
# -------------------------

for ENTRY in "${NODE_ARRAY[@]}"; do
    NAME=$(echo "$ENTRY" | awk '{print $1}')
    IP=$(echo "$ENTRY" | awk '{print $2}')

    [ -z "$NAME" ] && continue
    [ "$NAME" = "$LOCAL_NAME" ] && continue

    run_netcheck "$NAME" "root@$IP"
done

# -------------------------
# 4️⃣ 输出总结
# -------------------------

echo ""
echo "============================================"
echo "SUMMARY"
echo "============================================"

printf "%-22s %-6s %-6s %-15s %-8s\n" \
"Host" "UDP" "IPv6" "NearestDERP" "State"

printf "%-22s %-6s %-6s %-15s %-8s\n" \
"----------------------" "------" "------" "---------------" "--------"

cat "$TMP_FILE"

TOTAL=$(wc -l < "$TMP_FILE")
OK_COUNT=$(grep -c "OK" "$TMP_FILE")
EX_COUNT=$(grep -c "EXCELLENT" "$TMP_FILE")
DERP_COUNT=$(grep -c "DERP" "$TMP_FILE")
FAIL_COUNT=$(grep -c "FAIL" "$TMP_FILE")

echo "--------------------------------------------"
echo "Total Nodes : $TOTAL"
echo "Excellent   : $EX_COUNT"
echo "Direct OK   : $OK_COUNT"
echo "Via DERP    : $DERP_COUNT"
echo "Failed      : $FAIL_COUNT"
echo "Log saved to: $LOG_FILE"
echo "============================================"

rm -f "$TMP_FILE"
