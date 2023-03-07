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

            SONAR_CNES_REPORT = var.SONAR_CNES_REPORT
            SONAR_DEPENDENCY_CHECK = var.SONAR_DEPENDENCY_CHECK

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
    default = "9.9-developer"
}

# SONAR_CNES_REPORT=sonar-cnes-report-4.1.3.jar
# SONAR_DEPENDENCY_CHECK=sonar-dependency-check-plugin-3.0.1.jar
variable "SONAR_CNES_REPORT" {
    type    = string
    default = "sonar-cnes-report-4.1.3.jar"
}
variable "SONAR_DEPENDENCY_CHECK" {
    type    = string
    default = "sonar-dependency-check-plugin-3.0.1.jar"
}