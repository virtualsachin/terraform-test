# Terraform Provider
terraform {
  required_providers {
    nsxt = {
	    source = "vmware/nsxt"
	  }
  }
}

# NSX-T Manager Credentials
provider "nsxt" {
  host                  = var.nsx_manager
  username              = var.username
  password              = var.password
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

# Data Sources we need for reference later
data "nsxt_policy_transport_zone" "overlay_tz" {
  display_name = var.overlay_tz
}

data "nsxt_policy_transport_zone" "vlan_tz" {
  display_name = var.vlan_tz
}

data "nsxt_policy_edge_cluster" "edge_cluster_vrf" {
  display_name = var.edge_cluster_vrf
}

# Edge Nodes
data "nsxt_policy_edge_node" "edge_node_1" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster_vrf.path
  display_name      = var.edge_node_1
}

data "nsxt_policy_edge_node" "edge_node_2" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster_vrf.path
  display_name      = var.edge_node_2
}

# DFW Services
data "nsxt_policy_service" "ssh" {
  display_name = "SSH"
}

data "nsxt_policy_service" "http" {
  display_name = "HTTP"
}

data "nsxt_policy_service" "https" {
  display_name = "HTTPS"
}

# Create VLAN Segments
resource "nsxt_policy_vlan_segment" "vlan100" {
  display_name        = "VLAN100"
  description         = "VLAN Segment created by Terraform"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["100"]
}

resource "nsxt_policy_vlan_segment" "vlan200" {
  display_name        = "VLAN200"
  description         = "VLAN Segment created by Terraform"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["200"]
}

# Create Red Tenant Access VLAN Segments for Tenant VRF
resource "nsxt_policy_vlan_segment" "vlan101" {
  display_name        = "VLAN101"
  description         = "VRF Red Tenant Access VLAN to ToR-A"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["101"]
}

resource "nsxt_policy_vlan_segment" "vlan201" {
  display_name        = "VLAN201"
  description         = "VRF Red Tenant Access VLAN to ToR-B"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["201"]
}

# Create Blue Tenant Access VLAN Segments for Tenant VRF
resource "nsxt_policy_vlan_segment" "vlan102" {
  display_name        = "VLAN102"
  description         = "VRF Blue Tenant Access VLAN to ToR-A"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["102"]
}

resource "nsxt_policy_vlan_segment" "vlan202" {
  display_name        = "VLAN202"
  description         = "VRF Blue Tenant Access VLAN to ToR-B"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["202"]
}

# Create Tenant Access VLAN Trunk Segments for Tenant VRF
resource "nsxt_policy_vlan_segment" "vrf_trunk_a" {
  display_name        = "VRF-Trunk-A"
  description         = "Tenant VRF Trunk"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["101-110"]
}

resource "nsxt_policy_vlan_segment" "vrf_trunk_b" {
  display_name        = "VRF-Trunk-B"
  description         = "Tenant VRF Trunk"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["201-210"]
}

# Create Default Tier-0 Gateway for Tenants Tier-0 VRFs to be runnning on.
resource "nsxt_policy_tier0_gateway" "vrf_tier0_gw" {
  display_name         = "VRF-Tier-0"
  description          = "VRF Tier 0"
  failover_mode        = "NON_PREEMPTIVE"
  default_rule_logging = false
  enable_firewall      = false
  force_whitelisting   = false
  ha_mode              = "ACTIVE_STANDBY"
  edge_cluster_path    = data.nsxt_policy_edge_cluster.edge_cluster_vrf.path

  bgp_config {
	ecmp            = false
	local_as_num    = "65201"
	inter_sr_ibgp   = false
	multipath_relax = false
  }
}

# Create VRF for Red Tenant
resource "nsxt_policy_tier0_gateway" "red_vrf" {
  display_name         = "VRF-Red-Tenant"
  description          = "VRF Red Tenant"
  failover_mode        = "NON_PREEMPTIVE"
  default_rule_logging = false
  enable_firewall      = false
  force_whitelisting   = false
  ha_mode              = "ACTIVE_STANDBY"
  edge_cluster_path    = data.nsxt_policy_edge_cluster.edge_cluster_vrf.path

  vrf_config {
	gateway_path = nsxt_policy_tier0_gateway.vrf_tier0_gw.path
  }

  bgp_config {
	ecmp            = false
	inter_sr_ibgp   = false
	multipath_relax = false
  }

  tag {
	scope = "tenant"
	tag   = "red"
  }
}

# Create VRF for Blue Tenant
resource "nsxt_policy_tier0_gateway" "blue_vrf" {
  depends_on           = [nsxt_policy_tier0_gateway.vrf_tier0_gw]
  display_name         = "VRF-Blue-Tenant"
  description          = "VRF Blue Tenant"
  failover_mode        = "NON_PREEMPTIVE"
  default_rule_logging = false
  enable_firewall      = false
  force_whitelisting   = false
  ha_mode              = "ACTIVE_STANDBY"
  edge_cluster_path    = data.nsxt_policy_edge_cluster.edge_cluster_vrf.path

  vrf_config {
	gateway_path = nsxt_policy_tier0_gateway.vrf_tier0_gw.path
  }

  bgp_config {
	ecmp            = false
	inter_sr_ibgp   = false
	multipath_relax = false
  }

  tag {
	scope = "tenant"
	tag   = "blue"
  }
}

# Create VRF Tier-0 Gateway Uplink Interfaces
resource "nsxt_policy_tier0_gateway_interface" "vrf_uplink1" {
  display_name   = "Uplink-01"
  description    = "Default Uplink to VRF to Provider Transit"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_1.path
  gateway_path   = nsxt_policy_tier0_gateway.vrf_tier0_gw.path
  segment_path   = nsxt_policy_vlan_segment.vlan100.path
  subnets        = ["10.10.0.2/24"]
  mtu            = 1500
}

resource "nsxt_policy_tier0_gateway_interface" "vrf_uplink2" {
  display_name   = "Uplink-02"
  description    = "Default Uplink to VRF to Provider Transit"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_2.path
  gateway_path   = nsxt_policy_tier0_gateway.vrf_tier0_gw.path
  segment_path   = nsxt_policy_vlan_segment.vlan200.path
  subnets        = ["10.20.0.2/24"]
  mtu            = 1500
}

# Create Red Tenant VRF Uplink Interfaces
resource "nsxt_policy_tier0_gateway_interface" "red_vrf_uplink1" {
  depends_on     = [nsxt_policy_tier0_gateway_interface.vrf_uplink1]
  display_name   = "Uplink-01"
  description    = "Uplink to VRF to Provider Transit"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_1.path
  gateway_path   = nsxt_policy_tier0_gateway.red_vrf.path
  segment_path   = nsxt_policy_vlan_segment.vrf_trunk_a.path
  access_vlan_id = 101
  subnets        = ["10.10.1.2/24"]
  mtu            = 1500
}

resource "nsxt_policy_tier0_gateway_interface" "red_vrf_uplink2" {
  depends_on     = [nsxt_policy_tier0_gateway_interface.vrf_uplink2]
  display_name   = "Uplink-02"
  description    = "Uplink to VRF to Provider Transit"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_2.path
  gateway_path   = nsxt_policy_tier0_gateway.red_vrf.path
  segment_path   = nsxt_policy_vlan_segment.vrf_trunk_b.path
  access_vlan_id = 201
  subnets        = ["10.20.1.2/24"]
  mtu            = 1500
}

# Create Blue Tenant VRF Uplink Interfaces
resource "nsxt_policy_tier0_gateway_interface" "blue_vrf_uplink1" {
  depends_on     = [nsxt_policy_tier0_gateway_interface.vrf_uplink1]
  display_name   = "Uplink-01"
  description    = "VRF Uplink to ToR"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_1.path
  gateway_path   = nsxt_policy_tier0_gateway.blue_vrf.path
  segment_path   = nsxt_policy_vlan_segment.vrf_trunk_a.path
  access_vlan_id = 102
  subnets        = ["10.10.2.2/24"]
  mtu            = 1500
}

resource "nsxt_policy_tier0_gateway_interface" "blue_vrf_uplink2" {
  depends_on     = [nsxt_policy_tier0_gateway_interface.vrf_uplink2]
  display_name   = "Uplink-02"
  description    = "VRF Uplink to ToR"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_2.path
  gateway_path   = nsxt_policy_tier0_gateway.blue_vrf.path
  segment_path   = nsxt_policy_vlan_segment.vrf_trunk_b.path
  access_vlan_id = 202
  subnets        = ["10.20.2.2/24"]
  mtu            = 1500
}

# Provider Tier-0 to ToR BGP Neighbor Configuration
resource "nsxt_policy_bgp_neighbor" "router_a" {
  display_name     = "ToR-A"
  description      = "Terraform provisioned BGP Neighbor Configuration"
  bgp_path         = nsxt_policy_tier0_gateway.vrf_tier0_gw.bgp_config.0.path
  neighbor_address = "10.10.0.1"
  remote_as_num    = "65200"
}

resource "nsxt_policy_bgp_neighbor" "router_b" {
  display_name     = "ToR-B"
  description      = "Terraform provisioned BGP Neighbor Configuration"
  bgp_path         = nsxt_policy_tier0_gateway.vrf_tier0_gw.bgp_config.0.path
  neighbor_address = "10.20.0.1"
  remote_as_num    = "65200"
}

# VRF Red to ToR BGP Neighbor Configuration
resource "nsxt_policy_bgp_neighbor" "vrf_red_router_a" {
  depends_on       = [nsxt_policy_bgp_neighbor.router_a]
  display_name     = "ToR-A"
  description      = "VRF Red to ToR-A"
  bgp_path         = nsxt_policy_tier0_gateway.red_vrf.bgp_config.0.path
  neighbor_address = "10.10.1.1"
  remote_as_num    = "65200"
}

resource "nsxt_policy_bgp_neighbor" "vrf_red_router_b" {
  depends_on       = [nsxt_policy_bgp_neighbor.router_b]
  display_name     = "ToR-B"
  description      = "VRF Red to ToR-B"
  bgp_path         = nsxt_policy_tier0_gateway.red_vrf.bgp_config.0.path
  neighbor_address = "10.20.1.1"
  remote_as_num    = "65200"
}

# VRF Blue to ToR BGP Neighbor Configuration
resource "nsxt_policy_bgp_neighbor" "vrf_blue_router_a" {
  depends_on       = [nsxt_policy_bgp_neighbor.router_a]
  display_name     = "ToR-A"
  description      = "VRF Blue to ToR-A"
  bgp_path         = nsxt_policy_tier0_gateway.blue_vrf.bgp_config.0.path
  neighbor_address = "10.10.2.1"
  remote_as_num    = "65200"
}

resource "nsxt_policy_bgp_neighbor" "vrf_blue_router_b" {
  depends_on       = [nsxt_policy_bgp_neighbor.router_b]
  display_name     = "ToR-B"
  description      = "VRF Blue to ToR-B"
  bgp_path         = nsxt_policy_tier0_gateway.blue_vrf.bgp_config.0.path
  neighbor_address = "10.20.2.1"
  remote_as_num    = "65200"
}

# Create Red Tier-1 Gateway
resource "nsxt_policy_tier1_gateway" "tier1_gw_red" {
  description               = "Red Tenant Tier-1"
  display_name              = "Red-Tier-1"
  edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster_vrf.path
  failover_mode             = "NON_PREEMPTIVE"
  default_rule_logging      = "false"
  enable_firewall           = "true"
  enable_standby_relocation = "false"
  force_whitelisting        = "true"
  tier0_path                = nsxt_policy_tier0_gateway.red_vrf.path
  route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED"]

  tag {
	scope = "tenant"
	tag   = "red"
  }

  route_advertisement_rule {
	name                      = "Tier 1 Networks"
	action                    = "PERMIT"
	subnets                   = ["172.16.10.0/24", "172.16.11.0/24"]
	prefix_operator           = "GE"
	route_advertisement_types = ["TIER1_CONNECTED"]
  }
}

# Create Blue Tier-1 Gateway
resource "nsxt_policy_tier1_gateway" "tier1_gw_blue" {
  description               = "Blue Tenant Tier-1"
  display_name              = "Blue-Tier-1"
  edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster_vrf.path
  failover_mode             = "NON_PREEMPTIVE"
  default_rule_logging      = "false"
  enable_firewall           = "false"
  enable_standby_relocation = "false"
  force_whitelisting        = "true"
  tier0_path                = nsxt_policy_tier0_gateway.blue_vrf.path
  route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED"]

  tag {
	scope = "tenant"
	tag   = "blue"
  }

  route_advertisement_rule {
	name                      = "Tier 1 Networks"
	action                    = "PERMIT"
	subnets                   = ["172.16.20.0/24"]
	prefix_operator           = "GE"
	route_advertisement_types = ["TIER1_CONNECTED"]
  }
}

# Create Tenant Segments
resource "nsxt_policy_segment" "red_segment_1" {
  display_name        = "Red-Segment-1"
  description         = "Red Tenant Segment 1"
  connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw_red.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path

  subnet {
	cidr = "172.16.10.1/24"
  }
}

resource "nsxt_policy_segment" "red_segment_2" {
  display_name        = "Red-Segment-2"
  description         = "Red Tenant Segment 2"
  connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw_red.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path

  subnet {
	cidr = "172.16.11.1/24"
  }
}

resource "nsxt_policy_segment" "blue_segment_1" {
  display_name        = "Blue-Segment-1"
  description         = "Blue Tenant Segment 1"
  connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw_blue.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path

  subnet {
	cidr = "172.16.20.1/24"
  }
}

# Create Security Groups
resource "nsxt_policy_group" "web_servers" {
  display_name = var.nsx_group_web
  description  = "Terraform provisioned Group"

  criteria {
	condition {
	  key         = "Tag"
	  member_type = "VirtualMachine"
	  operator    = "CONTAINS"
	  value       = "Web"
	}
  }
}

resource "nsxt_policy_group" "app_servers" {
  display_name = var.nsx_group_app
  description  = "Terraform provisioned Group"

  criteria {
	condition {
	  key         = "Tag"
	  member_type = "VirtualMachine"
	  operator    = "CONTAINS"
	  value       = "App"
	}
  }
}

resource "nsxt_policy_group" "db_servers" {
  display_name = var.nsx_group_db
  description  = "Terraform provisioned Group"

  criteria {
	condition {
	  key         = "Tag"
	  member_type = "VirtualMachine"
	  operator    = "CONTAINS"
	  value       = "DB"
	}
  }
}

resource "nsxt_policy_group" "red_servers" {
  display_name = var.nsx_group_red
  description  = "Terraform provisioned Group"

  criteria {
	condition {
	  key         = "Tag"
	  member_type = "VirtualMachine"
	  operator    = "CONTAINS"
	  value       = "Red"
	}
  }
}

resource "nsxt_policy_group" "blue_servers" {
  display_name = var.nsx_group_blue
  description  = "Terraform provisioned Group"

  criteria {
	condition {
	  key         = "Tag"
	  member_type = "VirtualMachine"
	  operator    = "CONTAINS"
	  value       = "Blue"
	}
  }
}

# Create Custom Services
resource "nsxt_policy_service" "service_tcp8443" {
  description  = "HTTPS service provisioned by Terraform"
  display_name = "TCP 8443"

  l4_port_set_entry {
	display_name      = "TCP8443"
	description       = "TCP port 8443 entry"
	protocol          = "TCP"
	destination_ports = ["8443"]
  }

  tag {
	scope = "color"
	tag   = "blue"
  }
}

# Create Security Policies
resource "nsxt_policy_security_policy" "allow_blue" {
  display_name = "Allow Blue Application"
  description  = "Terraform provisioned Security Policy"
  category     = "Application"
  locked       = false
  stateful     = true
  tcp_strict   = false
  scope        = [nsxt_policy_group.web_servers.path]

  rule {
	display_name       = "Allow SSH to Blue Servers"
	destination_groups = [nsxt_policy_group.blue_servers.path]
	action             = "ALLOW"
	services           = [data.nsxt_policy_service.ssh.path]
	logged             = true
	scope              = [nsxt_policy_group.blue_servers.path]
  }

  rule {
	display_name       = "Allow HTTPS to Web Servers"
	destination_groups = [nsxt_policy_group.web_servers.path]
	action             = "ALLOW"
	services           = [data.nsxt_policy_service.https.path]
	logged             = true
	scope              = [nsxt_policy_group.web_servers.path]
  }

  rule {
	display_name       = "Allow TCP 8443 to App Servers"
	source_groups      = [nsxt_policy_group.web_servers.path]
	destination_groups = [nsxt_policy_group.app_servers.path]
	action             = "ALLOW"
	services           = [nsxt_policy_service.service_tcp8443.path]
	logged             = true
	scope              = [nsxt_policy_group.web_servers.path, nsxt_policy_group.app_servers.path]
  }

  rule {
	display_name       = "Allow HTTP to DB Servers"
	source_groups      = [nsxt_policy_group.app_servers.path]
	destination_groups = [nsxt_policy_group.db_servers.path]
	action             = "ALLOW"
	services           = [data.nsxt_policy_service.http.path]
	logged             = true
	scope              = [nsxt_policy_group.app_servers.path, nsxt_policy_group.db_servers.path]
  }

  rule {
	display_name = "Any Deny"
	action       = "REJECT"
	logged       = false
	scope        = [nsxt_policy_group.blue_servers.path]
  }
}
