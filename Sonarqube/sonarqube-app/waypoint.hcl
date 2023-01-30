project = "forge/sonarqube"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/Yann-Etrillard/forge.git"
        ref  = "var.datacenter"
        // ref  = "main"
        path = "Sonarqube/sonarqube-app"
        ignore_changes_outside_path = true
    }
}


app "forge/sonarqube-app" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
            disable_entrypoint = true
        }
    }
  
    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/forge-sonarqube.nomad.tpl", {
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
    default = "sonarqube/sonarqube"
}

variable "tag" {
    type    = string
    default = "8.9-developer"
}
