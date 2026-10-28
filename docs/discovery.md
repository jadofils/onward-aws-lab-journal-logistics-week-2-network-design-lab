# Discovery Report: Designing a Secure Network for the Onward Logistics Order System

| | |
|---|---|
| Lab | Designing a Secure Network for the Onward Logistics Order System (Week 2) |
| Name | [Your full name] |
| Date | 2026-10-28 |
| Client | Onward Logistics (see the [Client Profile](../../docs/client-profile.md)) |

## 1. What you found

### The client's need

Onward Logistics needs its order website to stay open to merchants and customers even when part of the data center fails, while keeping the systems behind it hidden from the internet, still patched, and maintainable by engineers without risky shortcuts, at a cost the Finance Lead can see and justify.

### Solutions that exist

| Solution | How it works | Trade-off for this client |
|----------|--------------|---------------------------|
| Single server with a public address (today) | One hand-built server runs the website and the order services, reachable directly from the internet, and engineers log in over SSH with shared keys. | **Strength:** cheapest and simplest. **Weakness:** one failure takes the business offline on a peak day, and every internal system is exposed to the internet. |
| Servers in public subnets across two zones, with a bastion host for admin | Web and order servers each have a public address in two Availability Zones; engineers reach them through one "jump" server over SSH. | **Strength:** survives the loss of one zone and needs no NAT gateway. **Weakness:** internal servers stay reachable from the internet, and the bastion needs an open SSH port and shared keys, which the Head of Security has ruled out. |
| Load balancer in front, all servers in private subnets across two zones, admin through AWS Systems Manager (chosen) | Only the load balancer faces the internet. Web and order servers sit in private subnets in two zones, reach the internet only outbound for updates, and engineers connect through Session Manager with no open ports. | **Strength:** meets every leader's requirement. **Weakness:** NAT gateways and the load balancer bill by the hour even when traffic is low, so the design must be explained to Finance. |

### What happens with no solution

If the order system stays on one hand-built server, any failure of that server or of the data center it runs in takes ordering and tracking offline. On a sales day, when delivery volume triples, that means lost orders, merchants moving to competitors, and broken trust with customers, which the Client Profile calls "the product".

This is a documented risk, not a theory. On **22 December 2021**, AWS lost power to one data center in a single Availability Zone (USE1-AZ4) in its US East Region. EC2 instances there lost availability and connectivity, AWS reported that some hardware might be unrecoverable, and recovery of some instances and volumes ran into the afternoon. AWS reported that other Availability Zones in the Region were not affected. Systems spread across two or more zones kept running; systems in that one zone did not.

Exposure is the second risk. A server reachable from the internet with an open SSH port is a constant target, and shared keys cannot be traced to one person. A breach of merchant or customer data would also create legal exposure under the data protection rules in every market Onward serves.

### Sources

- AWS, [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/): NAT gateway, public IPv4 and gateway endpoint charges
- AWS, [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/): Application Load Balancer hourly and LCU charges
- AWS, [AWS PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/): interface endpoint charges
- AWS, [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html): access with no inbound ports, bastion hosts or SSH keys; session logging
- Converge Digest, [AWS hit by loss of power within data center](https://convergedigest.com/aws-hit-by-loss-of-power-within-data/): the 22 December 2021 USE1-AZ4 incident

## 2. The business value of your solution

### Your chosen approach

A load balancer in front of web servers in two Availability Zones, with every server in private subnets and administration through Session Manager.

- **It keeps ordering open on the worst day.** The load balancer sends merchants and customers only to healthy web servers. If a server or a whole zone fails, traffic moves to the other zone and an Auto Scaling group replaces the lost server.
- **It hides everything internal.** No server has a public address. Security groups allow web traffic only from the load balancer to the web servers, and order traffic only from the web servers to the order services. No security group allows port 22.
- **Engineers can still work.** Session Manager gives each engineer a browser or command-line session, approved by their own IAM permissions and recorded in CloudTrail, with no SSH keys to share or lose.
- **Servers can still be patched.** Private servers reach the internet outbound only, through a NAT gateway in their own zone, so they can download updates while nobody on the internet can start a connection to them.
- **It is all code.** The whole network is one CloudFormation template deployed by GitSync, so it can be rebuilt from the repository and every change is reviewed.

The other options were rejected because they either leave internal servers on the internet or need an open SSH port and shared keys, both of which break the Head of Security's two conditions.

### Services you will use

| Service | The job it does | Why this service, used this way |
|---------|-----------------|---------------------------------|
| Amazon VPC (2 public + 4 private subnets across 2 Availability Zones) | A private network split into an internet-facing layer and two private layers, in two separate zones | Two zones give resilience against a data center failure; private subnets keep internal systems off the internet |
| Application Load Balancer | The only internet-facing entry point; spreads traffic over healthy web servers in both zones | Removes failed servers automatically, and lets web servers stay private |
| Amazon EC2 with Auto Scaling (Amazon Linux, Free Tier eligible) | Web servers (at least one per zone) and internal order servers; the web page is installed at launch | Auto Scaling replaces failed web servers; installing the page at launch makes every server identical and rebuildable |
| NAT gateway (one per zone) | Outbound-only internet access for private servers | Servers download updates, but nothing on the internet can connect in; one per zone so losing a zone doesn't cut the other zone's updates |
| Security groups | Allow only load balancer → web, and web → order services | Least privilege between layers; no admin ports anywhere |
| AWS Systems Manager Session Manager + IAM instance profile (AWS managed policy `AmazonSSMManagedInstanceCore`) | Engineer access to every server with no open ports and no keys | Access is per-person, can be revoked in one place, and is logged; a managed policy keeps the "no inline policies" rule |
| Amazon S3 gateway endpoint | Private route from the VPC to S3 | Free, and keeps S3 traffic off the NAT gateway, which reduces data charges |
| AWS CloudFormation + GitSync | Builds and updates everything from the repository | Repeatable, reviewed and rebuildable, as the brief and the Client Profile require |
| AWS Budgets | Alerts when monthly network spend passes a set amount | The Client Profile requires active budget alerts; it gives Finance early warning |

**Naming and tags.** Resources follow `onward-dev-<purpose>` (for example `onward-dev-orders-vpc`, `onward-dev-web-alb`) and carry `Project=onward`, `Owner=[Your full name]` and `Environment=dev`.

**Region.** EU (Ireland), `eu-west-1`: it needs no opt-in, offers every service in this design and the Free Tier, and costs less than the Africa (Cape Town) Region. Latency from Lagos and Accra must be measured before a production launch.

**What it costs (approximate, per month, 730 hours, using the US East list prices on the AWS pricing pages; Ireland must be confirmed in the AWS Pricing Calculator):**

| Item | Calculation | Monthly |
|------|-------------|--------:|
| Application Load Balancer | $0.0225/h × 730 + about 1 LCU × $0.008/h × 730 | about $22 |
| 2 NAT gateways | 2 × $0.045/h × 730, plus $0.045 per GB processed | about $66 + data |
| 4 public IPv4 addresses (load balancer in 2 zones, 2 NAT gateways) | 4 × $0.005/h × 730 | about $15 |
| 4 EC2 instances (2 web, 2 order) | Free Tier eligible size; partly covered by Free Tier credits | to confirm |
| S3 gateway endpoint | No hourly or data charge | $0 |
| **Total, before EC2 and data** | | **about $103** |

**Alternatives rejected on cost or risk:**

- **One NAT gateway instead of two:** saves about $33 a month, but if its zone fails, servers in the other zone also lose updates. Kept as a parameter so a `dev` environment can use one.
- **Interface endpoints for Systems Manager instead of NAT for admin traffic:** 3 endpoints × 2 zones × $0.01/h ≈ $44 a month, on top of NAT, which is still needed for updates.
- **A self-managed NAT instance:** cheaper per hour, but the small platform team would have to patch it and make it highly available itself.

### Who benefits, and how you will know

| Stakeholder | Benefit | How you would know |
|-------------|---------|--------------------|
| Chief Technology Officer | The order site stays up when a server or a whole zone fails | Stop a web server, or every server in one zone: the site keeps answering, and the load balancer shows healthy targets in the other zone |
| Head of Security | Nothing internal is reachable from the internet; no open admin ports; no shared keys | Private servers have no public IP; a connection attempt from the internet fails; no security group allows port 22; each admin session appears in CloudTrail under a named person |
| Head of Operations | Engineers can fix servers and servers stay patched | An engineer opens a Session Manager session to each internal server, and `sudo dnf install` of a package succeeds there |
| Finance Lead | Knows what the network costs and why | The cost table above matches the AWS Pricing Calculator, and the AWS Budgets alert fires before spend passes the agreed amount |
| Merchants and customers | Can place and track orders at any time, including sales days | The site answers during the zone-failure test with no visible error |

### Limits and risks of your design

- **Fixed hourly costs.** NAT gateways and the load balancer bill every hour even with no traffic, so `dev` and `test` stacks should be deleted when not in use.
- **HTTP only in the lab.** HTTPS needs a domain name and a certificate (AWS Certificate Manager), which the lab does not provide. Production must add them.
- **One Region.** The design survives the loss of one zone, not the loss of the whole Region.
- **No application-layer protection yet.** A web application firewall (AWS WAF) and DDoS protection are not included and should be considered before production.
- **Data protection.** The rules differ by market; whether customer data may be stored in an EU Region must be confirmed for each country Onward serves.
- **Cost figures are estimates.** They use US East list prices; final figures for Ireland must come from the AWS Pricing Calculator.
