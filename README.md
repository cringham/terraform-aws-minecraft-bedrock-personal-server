# terraform-module-minecraft-bedrock-server-1.14.60.5

Terraform module for launching and initializing a dedicated Minecraft Bedrock server. Check out the `~/examples` folder for examples on how you can use this module.

## TODO

- Create network diagram

- Create examples directory

- Support pushing of permissions.json

---

## After Deployment

Note that this module does not provide the means for any automatic or scheduled server shutdowns. This will have to be done manually by SSHing to the server and stopping it or by integrating another solution.

This module does allow you to enable scheduled snapshots/backups through the AWS EC2 Data Lifecycle Management service, but there is no automatic instance restore or disaster recovery configured. In the event of a disaster, restoration of the server will have to be done manually or by integrating another solution.

### Connecting to Your Server

You can find the public IP of your instance in two ways:

1. Configure your calling Terraform directory/module to output it after Terraform operations or using `terraform output` by adding this:

```terraform
output "instance_public_ip" {
  value = module.<YOUR CALLING MODULE NAME>.instance_public_ip
}
```

2. Head into the AWS Console for the Account you deployed into, find the Minecraft instance under EC2, and find its public IP under "Description."

If you have whitelisting enabled on your server, be sure your whitelist is configured to allow you and other desired players to connect.

If you chose to configure non-default ports for server communication in `server.properties`, you will need to manually add those ports in your instance Security Group or via the `ingress` input variable for this module. It is best-practice security hygiene to remove any unused ports from your instance Security Group.

### Auto-Start

If you left `auto_start` enabled for this module, the Minecraft server is started using [`screen`](https://linuxize.com/post/how-to-use-linux-screen/) to run the server in the background and still give you control to run other commands on your server in the main terminal. SSH onto your instance and `cd` into the server package directory to manage the server manually and stop/start the server.

### Useful Commands

- Run `screen -list` to list your active screens.

- Run `screen -r` to attach to the running Minecraft screen if it is the only screen running.

- Run `Ctrl+a+d` to detach from the current screen.

- Run `screen` to start a new screen.

- When attached to the minecraft screen, run `stop` to gracefully stop the Minecraft server.

- When attached to the minecraft screen, run `LD_LIBRARY_PATH=. ./bedrock_server` to start the Minecraft server.

- When attached to the minecraft screen, run `whitelist reload` to apply changes from `whitelist.json` to the running server.

- When attached to the minecraft screen, run `permission reload` to apply changes from `permissions.json` to the running server.

---

## Final Notes

- The Minecraft server must be restarted to reflect changes to the `server.properties`.

- Changes to `whitelist.json` and `permissions.json` files can be applied to the running server by running `whitelist reload` and `permissions reload` respectively.

- You will notice that this module supports different means of managing your server's configuration and operations. Note that Terraform is not typically meant for this kind of work, but given that most people are luanching Minecraft servers for peronal use, this module supports it for ease of setup and administration. Please report any quirks found.

- Running `terraform taint` on the instance will not trigger the reprovisioning of each `null_resource` related to server initialization, at least for Terraform Core v0.12.25 and prior -- [a bug](https://github.com/hashicorp/terraform/issues/2895). To trigger these for rerun, you must explicitly destroy the instance and recreate it in two seperate steps. Destroy with `terraform destroy -target <INSTANCE STATE NAME HERE>` (for example: `terraform destroy -target module.minecraft.aws_instance.this`) which will trigger destruction of the dependent `null resources`. Then run `terraform apply` to redeploy and initialize the server anew.

---
