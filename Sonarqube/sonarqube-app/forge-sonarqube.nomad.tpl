job "forge-sonarqube" {
    datacenters = ["${datacenter}"]
    type = "service"
    vault {
        policies = ["forge"]
        change_mode = "restart"
    }
    group "sonarqube" {
        count ="1"

        task "prep-sonar-extention" {
            driver = "docker"
            config {
                image = "busybox:latest"
                mount {
                    type = "volume"
                    target = "/opt/sonarqube/extensions"
                    source = "sonarqube_extensions"
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
                command = "sh"
                args = ["-c", "chown -R 1000:1000 /opt/sonarqube/extensions"]
            }

            resources {
                cpu = 100
                memory = 64
            }
            lifecycle {
                hook = "prestart"
                sidecar = "false"
            }
        }




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
SONAR_JDBC_USERNAME={{ .Data.data.psql_username }}
SONAR_JDBC_PASSWORD={{ .Data.data.psql_password }}

LDAP_URL=ldap://{{ .Data.data.ldap_ip }}
LDAP_BINDPASSWORD={{ .Data.data.ldap_password }} # LDAP password
{{ end }}
SONAR_JDBC_URL=jdbc:postgresql://{{ range service "forge-sonarqube-postgresql" }}{{.Address}}{{ end }}:{{ range service "forge-sonarqube-postgresql" }}{{.Port}}{{ end }}/sonar?currentSchema=sonar
SONAR_WEB_CONTEXT=/sonar

# LDAP
# ACTIVE DIRECTORY
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
                    target = "/opt/sonarqube/data"
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
                mount {
                    type = "volume"
                    target = "/opt/sonarqube/extensions"
                    source = "sonarqube_extensions"
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
                mount {
                    type = "volume"
                    target = "/opt/sonarqube/logs"
                    source = "sonarqube_logs"
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
                tags = ["urlprefix-qual.forge.asipsante.fr/"]
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
