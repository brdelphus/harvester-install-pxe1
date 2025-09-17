variable "ovh_endpoint" {
  description = "OVH API endpoint"
  type        = string
  default     = "ovh-ca"
}

variable "ovh_application_key" {
  description = "OVH API application key"
  type        = string
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "OVH API application secret"
  type        = string
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "OVH API consumer key"
  type        = string
  sensitive   = true
}

variable "server_name" {
  description = "OVH server service name"
  type        = string
  default     = "ns5033122.ip-148-113-208.net"
}

variable "hostname" {
  description = "Server hostname"
  type        = string
  default     = "hv1"
}

variable "ssh_key" {
  description = "SSH public key for server access"
  type        = string
}