module "controller-intel" {
  source = "git::https://github.com/kinvolk/lokomotive-kubernetes//packet/flatcar-linux/kubernetes?ref=27f1405662fec5232ad407262fa54b9ebebf2edc"

  providers = {
    aws      = "aws.default"
    local    = "local.default"
    null     = "null.default"
    template = "template.default"
    tls      = "tls.default"
    packet   = "packet.default"
  }

  dns_zone    = "${var.dns_zone}"
  dns_zone_id = "${var.dns_zone_id}"

  ssh_keys = "${var.ssh_keys}"

  asset_dir = "./assets-intel"

  cluster_name = "intel"
  project_id   = "${var.project_id}"
  facility     = "sjc1"

  controller_count = 1
  controller_type  = "m2.xlarge.x86"

  management_cidrs = ["0.0.0.0/0"]

  node_private_cidr = "10.0.0.0/8"
}

module "worker-intel" {
  source = "git::https://github.com/kinvolk/lokomotive-kubernetes//packet/flatcar-linux/kubernetes/workers?ref=27f1405662fec5232ad407262fa54b9ebebf2edc"

  providers = {
    local    = "local.default"
    template = "template.default"
    tls      = "tls.default"
    packet   = "packet.default"
  }

  ssh_keys = "${var.ssh_keys}"

  cluster_name = "intel"
  project_id   = "${var.project_id}"
  facility     = "sjc1"
  pool_name    = "pool"

  count = 1
  type  = "m2.xlarge.x86"

  kubeconfig = "${module.controller-intel.kubeconfig}"
}

module "worker-intel-x86client" {
  source = "git::https://github.com/kinvolk/lokomotive-kubernetes//packet/flatcar-linux/kubernetes/workers?ref=27f1405662fec5232ad407262fa54b9ebebf2edc"

  providers = {
    local    = "local.default"
    template = "template.default"
    tls      = "tls.default"
    packet   = "packet.default"
  }

  ssh_keys = "${var.ssh_keys}"

  cluster_name = "intel"
  project_id   = "${var.project_id}"
  facility     = "sjc1"
  pool_name    = "x86client"

  count = 1
  type  = "m2.xlarge.x86"

  kubeconfig = "${module.controller-intel.kubeconfig}"
}
