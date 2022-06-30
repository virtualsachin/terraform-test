# Variables

# NSX Manager
variable "nsx_manager" {
  default = "198.51.100.21"
}

# Username & Password for NSX-T Manager
variable "username" {
  default = "admin"
}

variable "password" {
  default = "VMware1!VMware1!"
}

# Transport Zones
variable "vlan_tz" {
  default = "TZ-VLAN-Edge"
}

variable "overlay_tz" {
  default = "TZ-Overlay"
}

# Enter Edge Nodes & Edge Cluster Display Name. Required for external interfaces.
variable "edge_node_1" {
  default = "vSDDC-T0-EdgeVM-01"
}

variable "edge_node_2" {
  default = "vSDDC-T0-EdgeVM-02"
}

variable "edge_cluster_vrf" {
  default = "vSDDC-T0-Edge-Cluster-01"
}

# Segment Names
variable "nsx_segment_web" {
  default = "VM-Segment-Web"
}
variable "nsx_segment_app" {
  default = "VM-Segment-App"
}

variable "nsx_segment_db" {
  default = "VM-Segment-DB"
}

# Security Group names. 
variable "nsx_group_web" {
  default = "Web Servers"
}

variable "nsx_group_app" {
  default = "App Servers"
}

variable "nsx_group_db" {
  default = "DB Servers"
}

variable "nsx_group_blue" {
  default = "Blue Application"
}

variable "nsx_group_red" {
  default = "Red Application"
}
