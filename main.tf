terraform {
  required_providers {
    virtualbox = {
      source = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

locals {
  php_content = <<-EOT
    <!DOCTYPE html>
    <html>
    <head>
        <title>User List</title>
        <style>
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid black; padding: 8px; text-align: left; }
        </style>
    </head>
    <body>
        <h1>User List</h1>
        <?php
        $conn = new mysqli("db-server", "webuser", "webpass", "mydatabase");
        
        if ($conn->connect_error) {
            die("Connection failed: " . $conn->connect_error);
        }
        
        $result = $conn->query("SELECT * FROM users");
        
        if ($result->num_rows > 0) {
            echo "<table>";
            echo "<tr><th>ID</th><th>Name</th><th>Email</th></tr>";
            while($row = $result->fetch_assoc()) {
                echo "<tr>";
                echo "<td>" . $row["id"] . "</td>";
                echo "<td>" . $row["name"] . "</td>";
                echo "<td>" . $row["email"] . "</td>";
                echo "</tr>";
            }
            echo "</table>";
        }
        $conn->close();
        ?>
    </body>
    </html>
  EOT

  sql_content = <<-EOT
    CREATE DATABASE mydatabase;
    USE mydatabase;

    CREATE TABLE users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100),
        email VARCHAR(100)
    );

    INSERT INTO users (name, email) VALUES
        ('John Doe', 'john@example.com'),
        ('Jane Smith', 'jane@example.com'),
        ('Bob Johnson', 'bob@example.com');
  EOT
}

resource "virtualbox_vm" "web_server" {
  name   = var.web_server_name
  cpus      = var.vm_cpus
  memory    = var.vm_memory
  image  = var.ubuntu_image
  
  network_adapter {
    type           = "bridged"
    host_interface = "wlp1s0"  # Change this to match your host's network interface name
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y apache2 php php-mysql",
    ]
    connection {
      type        = "ssh"
      user        = "vagrant"
      password    = "vagrant"
      private_key = file("~/.vagrant.d/insecure_private_key")
      host        = self.network_adapter.0.ipv4_address
    }
  }

  provisioner "file" {
    content     = local.php_content
    destination = "/tmp/index.php"
    connection {
      type        = "ssh"
      user        = "vagrant"
      password    = "vagrant"
      private_key = file("~/.vagrant.d/insecure_private_key")
      host        = self.network_adapter.0.ipv4_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo rm -f /var/www/html/index.html",
      "sudo cp /tmp/index.php /var/www/html/",
      "sudo chown www-data:www-data /var/www/html/index.php",
      "sudo chmod 644 /var/www/html/index.php",
      "echo '${virtualbox_vm.db_server.network_adapter.0.ipv4_address} db-server' | sudo tee -a /etc/hosts",
      "sudo systemctl restart apache2"
    ]
    connection {
      type        = "ssh"
      user        = "vagrant"
      password    = "vagrant"
      private_key = file("~/.vagrant.d/insecure_private_key")
      host        = self.network_adapter.0.ipv4_address
    }
  }
}

resource "virtualbox_vm" "db_server" {
  name   = var.db_server_name
  cpus   = var.vm_cpus
  memory = var.vm_memory
  image  = var.ubuntu_image

  network_adapter {
    type           = "bridged"
    host_interface = "wlp1s0"  # Change this to match your host's network interface name
  }

  provisioner "file" {
    content     = local.sql_content
    destination = "/tmp/init.sql"
    connection {
      type        = "ssh"
      user        = "vagrant"
      password    = "vagrant"
      private_key = file("~/.vagrant.d/insecure_private_key")
      host        = self.network_adapter.0.ipv4_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y mysql-server",
      "sudo mysql -e \"CREATE USER 'webuser'@'%' IDENTIFIED BY 'webpass'\"",
      "sudo mysql -e \"GRANT ALL PRIVILEGES ON *.* TO 'webuser'@'%'\"",
      "sudo mysql -e \"FLUSH PRIVILEGES\"",
      "sudo sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf",
      "sudo systemctl restart mysql",
      "sudo mysql < /tmp/init.sql"
    ]
    connection {
      type        = "ssh"
      user        = "vagrant"
      password    = "vagrant"
      private_key = file("~/.vagrant.d/insecure_private_key")
      host        = self.network_adapter.0.ipv4_address
    }
  }
}