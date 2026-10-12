variable "enable_threat_detection" {
  description = "GuardDuty + Security Hub. Use the 30-day trials, then turn off."
  type        = bool
  default     = true
}

variable "allow_public_s3_website" {
  description = "Account-level exception required ONLY by the Route 53 DR lab (phase 10)."
  type        = bool
  default     = false
}
