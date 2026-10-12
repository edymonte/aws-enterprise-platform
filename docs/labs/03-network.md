# Phase 03 — VPC across two AZs (4 h)

📘 **SAA-C03:** D1 (network security), D2 (multi-AZ resilience), D4 (NAT/endpoint cost)

## 🎯 Goal

A VPC with public, private and database subnets in two Availability Zones, outbound internet through NAT, a free S3 gateway endpoint, flow logs, and the SNS alert topic.

## 🧠 Concepts

```text
VPC 10.70.0.0/16
├── public    10.70.100.0/24, 10.70.101.0/24  → IGW          (ALB, NAT gateway)
├── private   10.70.0.0/20,  10.70.16.0/20    → NAT gateway  (EKS nodes AND pods)
└── database  10.70.110.0/24, 10.70.111.0/24  → no internet  (RDS)
```

- **Why /20 private subnets?** The VPC CNI gives **every pod** a VPC IP. Size subnets for pods, not nodes. (Azure CNI Overlay avoids this; prefix delegation is the EKS mitigation.)
- **Subnets are AZ-scoped** in AWS (regional in Azure). Multi-AZ = at least one subnet per AZ per tier.
- **NAT**: `single_nat_gateway = true` saves money but makes egress depend on one AZ — a resilience vs cost trade-off the exam loves.
- **Gateway endpoint (S3)**: free, route-table based; keeps ECR image layers (stored in S3) off the NAT. **Interface endpoints**: ENIs + private DNS, paid per AZ-hour.

## 🛠️ Steps

1. `terraform -chdir=infra/terraform/10-network console` → `cidrsubnet("10.70.0.0/16", 4, 1)` = `10.70.16.0/20`.
2. Read `10-network/main.tf`: which module inputs create the database route table **without** a route to the internet?
3. `./scripts/awp.ps1 apply 10-network` and confirm the SNS subscription e-mail.

## ✅ Checkpoint

```powershell
$vpc = terraform -chdir=infra/terraform/10-network output -raw vpc_id
aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc --query "Subnets[].{az:AvailabilityZone,cidr:CidrBlock,name:Tags[?Key=='Name']|[0].Value}" --output table
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$vpc --query "VpcEndpoints[].{svc:ServiceName,type:VpcEndpointType}" --output table
```

## 💥 Break it — the NAT single point of failure

Look at the private route tables: all point to **one** NAT in one AZ. *Question:* if that AZ fails, what happens to nodes in the other AZ? *(No egress: image pulls from public registries, AWS APIs without endpoints, Datadog — all fail.)* Change `single_nat_gateway=false`, plan, and read the cost difference.

## 🏋️ Challenge

Enable the interface endpoints (`-Var 'enable_interface_endpoints=true'`) and prove ECR pulls no longer use the NAT: compare VPC flow logs to the NAT ENI before and after a node restart.

<details><summary>Hint</summary>

CloudWatch Logs Insights on the flow log group: `filter interfaceId = "<nat-eni>" | stats sum(bytes) by bin(5m)`. With `ecr.api`, `ecr.dkr` and the S3 gateway endpoint, image pulls stay inside the VPC.

</details>

## 🎤 Interview

1. Public vs private vs isolated subnets — what makes a subnet "public"?
2. NAT gateway vs NAT instance vs egress-only IGW?
3. Gateway vs interface endpoints — cost and use cases?
4. Security groups vs NACLs (stateful vs stateless)?
5. How would this become multi-VPC? *(Transit Gateway hub; centralized egress/inspection VPC.)*
