This project is a cloudformation template that creates a vpc with the following features:

- 3 private subnets that can't access the internet
- 3 App subnets that only have outbound routing to the internet via NAT gateway
- 3 Public subnets that have inbound and outbound routing to the internet via internet gateway
- VPC Endpoints for SSM, SSM Messages and EC2 Messages to enable session manager for all instances
- Security groups that permit communications between VPC EC2 instances and the VPC endpoints
- exports for the VPC ID, Subnet IDs, VPC Endpoints and the security group tha an instance would need to access the VPC
  endpoint

## Usage

I publish the latest vpc.json to this publish s3 url. That's the easiest way to use it.

https://natemarks-cloudformation-public.s3.amazonaws.com/cfn-vpc/vpc.json

## Testing

I've automated most of the common project tasks for myself using make. The command below will run 'cloudformation
validate'

```shell
make lint
```

You can use taskcat (via pytest) to smoke test the stack, but I'm a little underwhelmed by it.

```shell
make pytest-taskcat
```

I don't think it's better to use for detailed custom testing than go the aws-sdk-go-v2, so I prefer to run custom tests
using go test

```shell
make test
```

Finally, I've made use of a test stack (test_vpc.json), that attaches additional testing resources to the vpc created by
vpc.json. The test_vpc.json does the following:

- serves as an example for stacks that use the vpc.json stack through cross-stack references
- creates an instance on each of the 3 App subnets that is accessible via SSM.
- creates an instance on each of the 3 Public subnets that is accessible via SSM
- creates VPC network reachability analyzer paths from each of the App instances to each of the VPC endpoints
- creates VPC network reachability analyzer paths from each of the Public instances to each of the VPC endpoints

NOTE: There are no tests for the private subnets, but I'll probably tackle that through a custom go test eventually. I
don't expect to have instances on those subnets, so I don't really need to test VPC endpoint access (for session
manager) from them either. I expect they're for things like RDS.  
![](network-reachability-test-limit.png)

**manual testing with the test stack**
NOTE: The test stack creates 18 reachability test paths all at once. the default limit is 5 concurrent. You might want
to increase the limit to like there. There are some other options as well, but this is the easiest.

To test manually, run the following script with your AWS credentials configured. This script will build the vpc stack,
the test stack and then pause. When you press a key, it'll delete the stacks it built.

```shell
bash scripts/create_and_teardown.sh
Creating Stack: deleteme-cfn-vpc-test
{
    "StackId": "arn:aws:cloudformation:us-east-1:0123456789:stack/deleteme-cfn-vpc-test/cb205ee0-6d6a-11ec-ae12-0e9c42e0f9b7"
}
Waiting for Stack to finish: deleteme-cfn-vpc-test
Creating Test Stack: test-deleteme-cfn-vpc-test
{
    "StackId": "arn:aws:cloudformation:us-east-1:0123456789:stack/test-deleteme-cfn-vpc-test/4ab6e070-6d6b-11ec-a4a1-0e30f4719ff3"
}
Waiting for Test Stack to finish: deleteme-cfn-vpc-test
Press any key to continue to stack deletion

Cleaning up (destroying) stack: test-deleteme-cfn-vpc-test
Finished destroying stack: test-deleteme-cfn-vpc-test
Finished destroying stack: deleteme-cfn-vpc-test
```

While the stacks are up, you can check the status of the availability tests by going to the vpn console and looking at
the Reachability Analyzer. It should have 18 test paths from all 6 instances to each of the 3 VPC endpoints for a total
of 18 like this:
![](network_reachability.png)

To shell into a test instance, use SSM. You can either use session manager from the aws console or from the cli like
this:

```shell
aws ssm start-session --target i-01243927h9b2433
```

To test the App subnets, use SSM to connect to the App[0|1|2] test instances and run curl to check its public IP. The
App0 public IP should be the App0 NAT gateway.

```shell
curl https://ifconfig.co
1.2.3.4 #  NAT gateway IP
```

To test the Public subnets, use SSM to connect to the Public[0|1|2] test instances and run curl to check its public IP.
The Public0 public IP should be Public0 instance IP address

```shell
curl https://ifconfig.co
5.6.7.8 # Instance public IP
```

The test stack also permits tcp/80 into the Public instances from 0.0.0.0/0 for testing, so if you turn up httpd, you
should be able to hit it from anywhere by the instance IP address:

```shell
# run this on the public instance with the ip address 5.6.7.8
sudo yum install -y httpd
sudo systemctl start httpd

```

```shell
# run this on some other internet host -  maybe your workstation
curl http://5.6.7.8
# it should succeed and give you a default html page
# if you stop he httpd service on the instance, it should fail
```
