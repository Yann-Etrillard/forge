project = "forge/sonarqube"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/Yann-Etrillard/forge.git"
        ref  = "main"
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
            sonarcnesreport = var.sonarcnesreport
            sonardependencycheck = var.sonardependencycheck

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
    default = "sonarqube"
}

variable "tag" {
    type    = string
    default = "8.9-developer"
}

variable "sonarcnesreport" {
    type    = string
    default = "sonar-cnes-report-4.1.3.jar"
}
variable "sonardependencycheck" {
    type    = string
    default = "sonar-dependency-check-plugin-3.0.1.jar"
}
