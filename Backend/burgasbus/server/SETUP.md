# Bus-data server — setup deferred

## Decision saved on 5 October 2026

The user asked to do hosting later. The current recommended low-cost option is [Netcup VPS pico G11.5s](https://www.netcup.com/en/server/vps/vps-pico-g11.5s-iv-12m-nue), approximately €2.23/month with Bulgarian VAT, billed for 12 months (about €27 upfront), with IPv4 + IPv6 connectivity. RackNerd's $21.99/year special was the cheaper annual alternative. These were researched offers, not purchases; recheck prices, availability, renewal terms and the user's choice before ordering. The earlier free-only search is superseded by the request for inexpensive options, but no expenditure has been authorized.

No account, server or IP has been created. Resume provisioning only when the user asks. Keep the existing importer package; adapt installation to the chosen host, then verify its actual outgoing IPv4 and persistence before giving it to Burgasbus. Official feed access is also still pending.

## Earlier free-hosting preparation (4 October 2026)

Status, 4 October 2026: the server configuration is prepared locally. **No VM, reserved IP, paid resource, or running importer has been created. There is no IP to put in the Burgasbus form yet.**

The user requires free hosting and has no hosting account. The next step is personal signup and verification at [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/). Oracle says most users need a phone number and card for verification. Keep the account on the free tier. A temporary trial credit is not the same as an Always Free resource.

Oracle's [Always Free documentation](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) lists VM.Standard.E2.1.Micro and eligible A1 instances. Free capacity is not guaranteed, and Oracle can reclaim idle Always Free instances. Reserve the public IP separately so its identity is retained if the server must be replaced. Check the console's allowance and estimated costs before creating anything; stop if any component requires payment. Do not upgrade the account or allocate paid capacity as a fallback.

## Prepared configuration

- `cloud-init.yaml`: upload as the initialization/user-data file for a new dedicated Ubuntu 24.04 instance. It contains source code and installation steps, **no credentials**.
- `burgasbus-importer.service`: unprivileged background importer, with IPv4-only network sockets to use the address registered with Burgasbus.
- `feeds.env.example`: names of settings to enter privately on the server after provider approval.
- `verify-ip.sh`: compare two public IPv4 observations with the reserved address shown in the provider console.

The initialization file installs Python and the importer but leaves the importer disabled. No feed URLs or Supabase service credentials are required merely to create the server and reserve its address.

## Provisioning plan after account verification

1. In the selected **home region**, create one Always Free-eligible Ubuntu VM. Prefer the 1 GB `VM.Standard.E2.1.Micro` if available; an A1 allocation must also fit the current free CPU, memory and storage limits shown in that account. Do not substitute a paid shape.
2. Use an IPv4 public subnet with an Internet Gateway. Allow outbound HTTPS and necessary DNS/time services. Limit inbound SSH to the administrator's current public IP; no HTTP/HTTPS web port is needed for this importer. Do not add a paid NAT gateway or load balancer.
3. Choose key-based SSH and save the generated private key securely on the user's Mac, outside source control. Attach `cloud-init.yaml` as initialization data.
4. Create a **Reserved Public IPv4 Address** and attach it to the VM's primary private IP. Confirm the console shows it as reserved and within the free allowance. If an ephemeral IP was auto-assigned, replace it with the reserved IP before recording the address. Reference: [Oracle public-IP documentation](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingpublicIPs.htm).
5. Connect using SSH, wait for `sudo cloud-init status --wait`, and check its exit status/logs. Run `/opt/burgasbus/verify-ip.sh` **on the VM**, not on the Mac. The two observed outgoing IPv4 addresses must match the console's reserved IPv4. Record the region, instance name, reserved-IP resource and verified address in a local deployment note.
6. Reboot, reconnect, and recheck the address. Only then give that exact address to Burgasbus. Keep the reserved address allocated; never replace it silently after approval.

## After Burgasbus grants access

Confirm the authorized GTFS and VehiclePositions URLs, authentication, redistribution terms, attribution, and allowed polling frequency. The importer currently polls every 20 seconds; change that interval before activation if the provider requires a different limit.

Create `/etc/burgasbus/feeds.env` privately on the server, owned by root with mode 0600. Fill the settings from `feeds.env.example`; never put service keys in the iPhone app or cloud-init file. Apply the existing Supabase category/transit SQL setup if still pending. Validate a one-shot import, check the results, then enable the service with `sudo systemctl enable --now burgasbus-importer.service`.

The server should remain idle until approved credentials are available. Check provider retention rules while waiting; no keep-alive workload or artificial resource usage should be used to avoid free-tier reclamation.

## What was checked locally

The generated initialization document was parsed, bundled Python sources checked for syntax, private configuration validation tested, and shell scripts checked for syntax. The live Linux boot, cloud-init schema validation on Ubuntu, dependency installation, network restrictions, cloud costs, actual outgoing IP, reserved-IP persistence, and live import still require the real account and VM. No local check proves that a server or an IP exists.
