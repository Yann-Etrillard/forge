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
            port "http" {
                to = 9000
            }
        }
        task "sonarqube" {
            # Ajout de plugins en artifact
            artifact {
	    	    source = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/ext-tools/qualimetrie/sonarqube-plugins/sonar-cnes-report-4.1.3.jar"
	        }
            artifact {
	    	    source = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/ext-tools/qualimetrie/sonarqube-plugins/sonar-dependency-check-plugin-3.0.1.jar"
		        options {
			        archive = false
		        }
	        }

            driver = "docker"

            template {
                data = <<EOH
{{ with secret "forge/sonarqube" }}
SONAR_JDBC_USERNAME={{ .Data.data.username }}
SONAR_JDBC_PASSWORD={{ .Data.data.password }}
LDAP_BINDPASSWORD={{ .Data.data.ldap_password }} # LDAP password
{{ end }}
SONAR_JDBC_URL=jdbc:postgresql://{{ range service "forge-sonarqube-postgresql" }}{{.Address}}{{ end }}:{{ range service "forge-sonarqube-postgresql" }}{{.Port}}{{ end }}/sonar
SONAR_WEB_CONTEXT=/sonar

# LDAP
# ACTIVE DIRECTORY
SONAR_SECURITY_REALM=LDAP
SONAR_SECURITY_SAVEPASSWORD=true
LDAP_URL=ldap://10.3.8.44
LDAP_BINDDN=cn=Manager,dc=asipsante,dc=fr
# User Configuration
LDAP_USER_BASEDN=ou=People,dc=asipsante,dc=fr
LDAP_USER_REQUEST=(&(objectClass=inetOrgPerson)(uid={login}))
LDAP_USER_REALNAMEATTRIBUTE=cn
LDAP_USER_EMAILATTRIBUTE=mail
# Group Configuration
LDAP_GROUP_BASEDN=ou=group,dc=asipsante,dc=fr
LDAP_GROUP_REQUEST=(&(objectClass=posixGroup)(memberUid={uid}))

                EOH
                destination = "local/file.env"
                change_mode = "restart"
                env = true
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["http"]
                volumes = [
                    "name=sonarqube_extensions,io_priority=high,size=25,repl=2:/opt/sonarqube/extensions",
                    "name=sonarqube_logs,io_priority=high,size=25,repl=2:/opt/sonarqube/logs"
                ]

                # Mise en pace des plugins
                mount {
                    type = "bind"
                    target = "/opt/sonarqube/extensions/plugins/sonar-cnes-report-4.1.3.jar"
                    source = "local/sonar-cnes-report-4.1.3.jar"
                    readonly = false
                    bind_options {
                        propagation = "rshared"
                    }
                }
                mount {
                    type = "bind"
                    target = "/opt/sonarqube/extensions/plugins/sonar-dependency-check-plugin-3.0.1.jar"
                    source = "local/sonar-dependency-check-plugin-3.0.1.jar"
                    readonly = false
                    bind_options {
                        propagation = "rshared"
                    }
                }                
            }
            
            resources {
                cpu    = 600
                memory = 6144 #4096
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                tags = ["urlprefix-forge.dev.henix.asipsante.fr/"]
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
