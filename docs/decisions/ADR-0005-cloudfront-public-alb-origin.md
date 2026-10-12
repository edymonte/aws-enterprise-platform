# ADR-0005 — CloudFront with a public ALB origin locked by prefix list

**Status:** accepted (lab trade-off)

## Decision
Internet-facing ALB (created by the LB Controller), security group admitting only the `com.amazonaws.global.cloudfront.origin-facing` prefix list (+ operator IP). CloudFront → ALB over HTTP. CloudFront sends `X-Origin-Verify`. DR lab uses Route 53 failover to a public S3 website in another region with an explicit, temporary account-level exception.

## Consequences
- ✅ Simple, cheap, and every hop is observable.
- ⚠️ The prefix list covers all CloudFront distributions — verify the header at the ALB (phase 10 challenge).
- ⚠️ The prefix list consumes ~55 of the 60 default rules per security group.
- ⚠️ The DR site needs a public bucket — flagged by Config by design.

## Alternatives
**CloudFront VPC origins** (internal ALB, no public exposure — production recommendation); HTTPS to the origin with an ACM cert on the ALB; CloudFront origin groups for HTTP failover instead of DNS failover.
