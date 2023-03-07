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
            driver = "docker"
                        $\u007sonarcnesreport\u007D
            $\u007sonarkdependencycheck\u007D
            # Ajout de plugins
            artifact {
	    	    source = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/ext-tools/qualimetrie/sonarqube-plugins/sonar-cnes-report-4.1.3.jar"
                # source = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/ext-tools/qualimetrie/sonarqube-plugins/$\u007sonarcnesreport\u007D"
                # source = "https://repo.forge.ans.henix.fr:443/artifactory/ext-tools/qualimetrie/sonarqube-plugins/sonar-cnes-report-4.1.3.jar"
                options {
		            archive = false
  		        }
	        }
            artifact {
                source = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/ext-tools/qualimetrie/sonarqube-plugins/sonar-dependency-check-plugin-3.0.1.jar"
	    	    # source = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/ext-tools/qualimetrie/sonarqube-plugins/$\u007sonarkdependencycheck\u007D"
                # source = "https://repo.forge.ans.henix.fr:443/artifactory/ext-tools/qualimetrie/sonarqube-plugins/sonar-dependency-check-plugin-3.0.1.jar" # Prod
                options {
		            archive = false
  		        }
		    }

            artifact { # Certificat
	    	    source = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/asip-ac/truststore/cacerts"
                # source = "https://repo.forge.ans.henix.fr:443/artifactory/asip-ac/truststore/cacerts" # Prod
                options {
		            archive = false
  		        }
		    }

            template {
                data = <<EOH
{{ with secret "forge/sonarqube" }}
{{ .Data.data.token_sonar }}
{{ end }}
                EOH
                destination = "secrets/sonar-secret.txt"
                change_mode = "restart"
            }

            template {
                data = <<EOH
# SonarQube Configuration
SONAR_WEB_CONTEXT=/sonar
SONAR_UPDATECENTER_ACTIVATE=false
SONAR_SECRETKEYPATH=/opt/sonarqube/.sonar/sonar-secret.txt
# JDBC Configuration
SONAR_JDBC_USERNAME={{ with secret "forge/sonarqube" }}{{ .Data.data.psql_username }}{{ end }}
SONAR_JDBC_PASSWORD={{ with secret "forge/sonarqube" }}{{ .Data.data.psql_password }}{{ end }}
SONAR_JDBC_URL=jdbc:postgresql://{{ range service "forge-sonarqube-postgresql" }}{{.Address}}{{ end }}:{{ range service "forge-sonarqube-postgresql" }}{{.Port}}{{ end }}/sonar?currentSchema=sonar
# LDAP Configuration
LDAP_URL=ldap://{{ with secret "forge/sonarqube" }}{{ .Data.data.ldap_ip }}{{ end }}
LDAP_BINDPASSWORD={{ with secret "forge/sonarqube" }}{{ .Data.data.ldap_password }}{{ end }}
SONAR_SECURITY_REALM=LDAP
SONAR_SECURITY_SAVEPASSWORD=true
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
                destination = "secrets/file.env"
                change_mode = "restart"
                env = true
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["http"]

                mount {
                    type = "volume"
                    target = "/opt/sonarqube/data/"
                    source = "sonarqube_data"
                    readonly = false
                    volume_options {
                        no_copy = false
                        driver_config {
                            name = "pxd"
                            options {
                                io_priority = "high"
                                size = 2
                                repl = 1
                            }
                        }
                    }
                }             

                # Mise en pace des plugins
                mount {
                    type = "bind"
                    target = "/opt/sonarqube/extensions/plugins/sonar-cnes-report-4.1.3.jar"
                    # target = "/opt/sonarqube/extensions/plugins/$\u007sonarcnesreport\u007D"
                    source = "local/$\u007BSONAR_CNES_REPORT\u007D"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }
                mount {
                    type = "bind"
                    target = "/opt/sonarqube/extensions/plugins/sonar-dependency-check-plugin-3.0.1.jar"
                    # target = "/opt/sonarqube/extensions/plugins/$\u007sonarkdependencycheck\u007D"
                    source = "local/$\u007BSONAR_DEPENDENCY_CHECK\u007D"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }    
                # Certificat    
                mount {
                    type = "bind"
                    target = "/opt/java/openjdk/lib/security/cacerts"
                    source = "local/cacerts"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                } 
                # token    
                mount {
                    type = "bind"
                    target = "/opt/sonarqube/.sonar/sonar-secret.txt"
                    source = "secrets/sonar-secret.txt"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                } 
            }

            resources {
                cpu    = 600
                memory = 6144
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                tags = ["urlprefix-qual.forge.henix.asipsante.fr"]
                # tags = ["urlprefix-qual.forge.asipsante.fr/"] # Serveur name de prod
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
