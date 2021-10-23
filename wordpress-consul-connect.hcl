job "wordpress" {
  datacenters = ["dc1"]
  type = "service"

  group "mariadb" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "5m"
      progress_deadline = "10m"
      auto_revert = true
    }

    network {
      mode = "bridge"
    }

    volume "mariadb" {
      type = "host"
      read_only = false
      source = "wordpress-mariadb"
    }

    service {
      name = "mariadb"
      port = "3306"
      tags = ["database"]

      connect {
          sidecar_service {}
      }
    }

    task "mariadb" {
      driver = "docker"
      config {
        image = "mariadb:10.6.4-focal"
        volumes = [
          "/var/lib/mariadb:/var/lib/mysql",
        ]
      }

      env {
        MYSQL_ROOT_PASSWORD = "mariadb_root_password"
        MYSQL_DATABASE = "wordpress"
        MYSQL_USER = "wordpress"
        MYSQL_PASSWORD = "wordpress"
      }

      resources {
        cpu    = 256
        memory = 256
      }
    }
  }

  group "phpmyadmin" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "5m"
      progress_deadline = "10m"
      auto_revert = true
    }

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }

    service {
      name = "phpmyadmin"
      port = "http"
      tags = ["database"]

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "mariadb"
              local_bind_port = 3306
            }
          }
        }
      }
    }

    task "phpmyadmin" {
      driver = "docker"
      config {
        image = "phpmyadmin:5.1.1-apache"
      }

      env {
        MYSQL_ROOT_PASSWORD = "mariadb_root_password"
        PMA_HOST = "${NOMAD_UPSTREAM_IP_mariadb}"
        PMA_PORT = "${NOMAD_UPSTREAM_PORT_mariadb}"
        MYSQL_USERNAME = "wordpress"
      }

      resources {
        cpu    = 256
        memory = 256
      }
    }
  }

  group "wordpress" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "5m"
      progress_deadline = "10m"
      auto_revert = true
    }

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }

    service {
      name = "wordpress"
      port = "http"
      tags = ["app"]

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "mariadb"
              local_bind_port = 3306
            }
          }
        }
      }
    }

    task "wordpress" {
      driver = "docker"
      config {
        image = "wordpress:5.8.1-apache"
      }

      env {
        WORDPRESS_DB_HOST = "${NOMAD_UPSTREAM_ADDR_mariadb}"
        WORDPRESS_DB_USER = "wordpress"
        WORDPRESS_DB_PASSWORD = "wordpress"
        WORDPRESS_DB_NAME = "wordpress"
      }

      resources {
        cpu    = 256
        memory = 256
      }
    }
  }
}