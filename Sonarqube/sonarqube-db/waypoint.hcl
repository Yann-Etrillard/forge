project = "forge/sonaqube-db"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/Yann-Etrillard/forge.git"
        ref  = "main"
        path = "Sonarqube/sonarqube-bd"
        ignore_changes_outside_path = true
    }
}

app "forge/sonaqube-db" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
            disable_entrypoint = true
        }
    }
  
    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/forge-sonarqube-postgresql.nomad.tpl", {
            image   = var.image
            tag     = var.tag
            datacenter = var.datacenter
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "henix_docker_platform_dev"
}

variable "image" {
    type    = string
    default = "postgres"
}

variable "tag" {
    type    = string
    default = "15.2"
}
