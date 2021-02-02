variable "project_id" {
  description = "project id"
}

variable "region" {
  default     = "europe-west1"
  description = "region"
}

variable "region_zone" {
  default     = "europe-west1-b"
  description = "region_zone"
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}

variable "gke_machine_type" {
  default     = "g1-small"
  description = "gke nmachine_type"
}

variable "gke_preemtible" {
  default     = true
  description = "gke preemtible"
}
