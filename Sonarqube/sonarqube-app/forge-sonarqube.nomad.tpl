job "forge-sonarqube" {
    datacenters = ["${datacenter}"]
    type = "service"
    vault {
        policies = ["forge"]
        change_mode = "restart"
    }
    group "sonarqube" {
        count ="1"
        
        restart {
            attempts = 3
            delay = "60s"
            interval = "1h"
            mode = "fail"
        }
        
        constraint {
            attribute = "$\u007Bnode.class\u007D"
            value     = "data"
        }

        network {
            port "http" { to = 8080 }
        }

        task "squashtm" {
            driver = "docker"
            template {
                data = <<EOH
# User credentials.
{{ with secret "forge/sonarqube" }}
sonar_jdbc_username={{ .Data.data.username }}
sonar_jdbc_password={{ .Data.data.password }}
{{ end }}
# Database
sonar_jdbc_url=jdbc:postgresql://vm368a674857.qual.henix.asip.hst.fluxus.net/sonar?currentSchema=sonar
# Web context.
sonar_web_context=/sonar


#---------------------------------------------------------
# CONFIGURATION LDAP
#---------------------------------------------------------
# LDAP configuration
# General Configuration
sonar_security_realm=LDAP
sonar_security_savePassword=true
#ldap.url=ldap://FORGE-Admin01.asip.hst.fluxus.net
ldap_url=ldap://10.3.8.44
# User Configuration
ldap_user.baseDn=ou=People,dc=asipsante,dc=fr
ldap_bindDn=cn=Manager,dc=asipsante,dc=fr
ldap_bindPassword=asiprootmgr
ldap_user_request=(&(objectClass=inetOrgPerson)(uid={login}))
ldap_user_realNameAttribute=cn
ldap_user_emailAttribute=mail
# Group Configuration
ldap_group_baseDn=ou=group,dc=asipsante,dc=fr
ldap_group_request=(&(objectClass=posixGroup)(memberUid={uid}))

                EOH
                destination = "secrets/file.env"
                change_mode = "restart"
                env = true
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["http"]
            }

            resources {
                cpu    = 600
                memory = 4096
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                tags = ["urlprefix-sonarqube.forge.henix.asipsante.fr/"]
                port = "http"
                check {
                    name     = "alive"
                    type     = "http"
                    path     = "/sonar"
                    interval = "60s"
                    timeout  = "5s"
                    port     = "http"
                }
            }
        } 
    }
}
