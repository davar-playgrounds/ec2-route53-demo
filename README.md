# EC2 + Route53 Demo
*How to boot a new instance that knows its own domain name*.

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
        ^    ^  (provision) |
        |    + - - - - - - -+
        |          
+--------------+   
|    IP of     |   
| EC2 Instance |   
+--------------+   
        ^          
        |          
        |          
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

[1]: https://letsencrypt.org/
[2]: https://en.wikipedia.org/wiki/David_Wheeler_(computer_scientist)#Quotes
[3]: https://www.terraform.io/docs/provisioners/null_resource.html
