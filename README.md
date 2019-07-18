# EC2 + Route53 Demo
*How to boot a new instance that knows its own domain name*.

### Running the demo
To see this in action for yourself, just clone this repo and run the provided
Makefile on a system with valid AWS credentials:

```bash
git clone https://github.com/robertdfrench/ec2-route53-demo.git
cd ec2-route53-demo
make PARENT_ZONE=example.org
```

This assumes you are working in the same AWS account where `example.org` is
registered. It will create an EC2 instance at `demo.example.org`, boot it, and
query that system for its hostname (which should of course return
"demo.example.org").

#### Cleanup
Don't forget to tear this instance and its associated DNS records down after you
are done: `make clean PARENT_ZONE=example.org`.

### The Problem
We need the IP address of the instance to be able to configure an "A" record for
our subdomain. But if we want the instance to be able to do anything with this
record (for example, obtain a TLS certificate from [Let's Encrypt][1]), then it
should not be considered ready until the subdomain record has been created. This
gets us into a loop, which terraform will reject:

```console
+--------------+
| EC2 Instance |---+
+--------------+   |
        ^          |
        |          |
        |          |
+--------------+   |
|    IP of     |   |
| EC2 Instance |   |
+--------------+   |
        ^          |
        |          |
        |          V
+------------------------+
|        Subdomain       |
| demo.robertdfrench.com |
+------------------------+
             |
             |
             V
+------------------------+
|         Domain         |
| i.e. robertdfrench.com |
+------------------------+
```

### A Solution
As [David Wheeler][2] said, *"All problems in computer science can be solved by
another level of indirection"*. Terraform has the concept of a [Null Resource][3]
which can be abused to allow us to run provisioners in response to changes in
real resources:

```hcl
resource "null_resource" "instance" {

  triggers = {
    instance = aws_instance.instance.id
  }

  connection {
    host = aws_instance.instance.public_ip
  }

  provisioner "remote-exec" {
    # Tell the host what its domain name is 
    inline = [format("hostname -s %s", aws_route53_record.record.fqdn)]
  }

}
```

Because the null resource is triggered *after* the creation of the EC2 instance
but *before* the terraform run has completed, we get something like this:

```console
       +- - - - - - - - - - +
       |(trigger on create) |
       |                    V
+--------------+       +---------------+
| EC2 Instance |       | Null Resource |
+--------------+       +---------------+
        ^    ^  (provision) |       |
        |    + - - - - - - -+       |
        |                           |
+--------------+                    |
|    IP of     |                    |
| EC2 Instance |                    |
+--------------+                    |
        ^                           |
        |                           |
        |                           |
+------------------------+          |
|        Subdomain       |<---------+
| demo.robertdfrench.com |
+------------------------+
             |
             |
             V
+------------------------+
|         Domain         |
| i.e. robertdfrench.com |
+------------------------+
```

This graph does not contain any cycles of resources *which must exist
simultaneously*. Because the Null Resource does not need to "exist" until after
the EC2 instance and "A" record both exist, it does not contribute to any
circular dependencies.

[1]: https://letsencrypt.org/
[2]: https://en.wikipedia.org/wiki/David_Wheeler_(computer_scientist)#Quotes
[3]: https://www.terraform.io/docs/provisioners/null_resource.html
