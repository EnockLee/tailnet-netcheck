# Tailscale Batch Netcheck

A stable batch network diagnostic tool for multi-node Tailnet environments.

This script runs `tailscale netcheck` across all online Linux nodes in your Tailnet via SSH and provides a clean summary of direct connectivity status, IPv6 capability, and DERP usage.

Designed for multi-region exit node monitoring.

---

## Features

- Automatically detects all **online Linux nodes**
- Runs `tailscale netcheck` remotely via SSH
- Strict JSON validation (no broken parsing)
- Timeout protection (no hanging SSH sessions)
- Clean summary table
- Health grading:
  - `EXCELLENT` – IPv4 + IPv6 direct
  - `OK` – IPv4 direct
  - `DERP` – Using relay
  - `FAIL` – SSH or error
- Log file output with timestamp

---

## Requirements

- Linux
- `tailscale`
- `jq`
- SSH access to remote nodes (root or appropriate user)

Install dependencies:

```bash
apt install jq
```

---

## Usage

```bash
chmod +x tailnet-netcheck.sh
./tailnet-netcheck.sh
```

## Example output:

```
============================================
SUMMARY
============================================
Host                   UDP    IPv6   NearestDERP     State
---------------------- ------ ------ --------------- --------
jp-iij                 true   -      -               OK
LAX                    true   -      -               OK
jp-hyper2              true   true   -               EXCELLENT
usmci-v6               true   true   -               EXCELLENT
bj-ecs                 true   -      -               OK
--------------------------------------------
Total Nodes : 5
Excellent   : 2
Direct OK   : 3
Via DERP    : 0
Failed      : 0
```

---

## How It Works

1.Detects all online Linux peers from:
```
tailscale status --json
```
2.Executes on each node:
```
tailscale netcheck --format=json-line
```
3.Parses:
```
UDP

IPv6

NearestDERP
```
4.Grades network quality.

---

## Health State Meaning

| State     | Meaning                       |
| --------- | ----------------------------- |
| EXCELLENT | IPv4 + IPv6 direct connection |
| OK        | IPv4 direct connection        |
| DERP      | Using Tailscale relay         |
| FAIL      | SSH or execution error        |

---

## Why This Tool?

In multi-exit-node setups, it is useful to:

Verify direct UDP connectivity

Detect unintended DERP routing

Monitor IPv6 availability

Validate cross-region NAT behavior

This script focuses on stability and correctness rather than fancy output.

---

## Design Goals

No lost nodes

No SSH hang

No stdout pollution

Safe JSON parsing

Clear terminal output

---

## Roadmap (Optional Ideas)

Telegram report integration

Scheduled health logging

Exit node auto-selection

Latency ranking

---

## License

MIT

---

## Author

Maintained by a multi-region Tailnet enthusiast.
