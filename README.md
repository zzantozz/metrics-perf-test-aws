# Metrics performance

This project's purpose is to explore performance of various data
forwarding tools for use in monitoring and metrics.  Tools should be
able to reliably and efficiently forward large volumes of data to
multiple sinks. Facebook Scribe and Apache Flume are examples of tools
used in the past.

Required attributes:

- back pressure: When a data sink is unavailable, data should be
  buffered to disk until the sink is available again.

- buffer cap: The disk buffer should have a size limit so that a disk
  doesn't get completely filled during extended downtime.

- throughput: It should be able to send a minimum of 10 million
  metrics per minute. Horizontal scaling is acceptable.

- fanout: It should be able to duplicate all metrics to at least three
  different remote sinks.

- sink clustering/load balancing: It should be able to distribute
  metrics across a cluster of similar sinks. If one sink in a cluster
  goes down, it should continue sending to the rest.

# How to run it

There's a terraform template to create some AWS resources for the
project. It uses the enabling team sandbox found at
https://manage.rackspace.com/racker/rackspace-accounts/1317477/aws-accounts/622383701450
You must be on vpn to reach it that page.

Generate temporary credentials through the RAX FAWS page above, copy
the exports into terminal, then run `./create.sh`.

On success, it'll write out all instance public ip's in addition to a
cssh command to connect to all of them at once. SSH to them as user
`ec2-user`. The local machine's ssh public key is added to the 
instances for authentication.

The state file is committed. Make sure to keep it up to date, but most
likely it'll always be empty in the repo. I should only have resources
up for a short time and destroy them when I'm finished.

Tear down the environment with `./destroy.sh`.

# How it works

The environment consists of multiple ec2 instances that forward events
to each other. The first instance generates the events and sends to the
second. The second receives them and sends them to the third, and so on.
The last instance in the chain just writes the events to file for
inspection.

The simplest common input and output between all the tools is writing or
reading events from file, so every input writes to a file on its
instance, and the next output reads from file. This also creates a handy
way of inspecting the event flow.

Each instance uses a different tool/service to send/receive events. For
simplicity, the same tool is used to send and receive between any two
services. For example, if Flume sends events from instance2, then
instance3 receives events with Flume.

All instances register their IP in etcd at startup so that they can find
each other. The other alternative is for terraform to put the IPs into
the appropriate configs, but that causes the instances to be
interdependent in terraform. For example, if instance1 needs the IP of
instance2, then terraform can't start creating instance1 until instance2
is created and its IP is known. This makes the provisioning take much
longer, since instances can't be created in parallel.

# The instances

On the EC2 instances, all the important things are in /opt. Any downloaded
files or tools are there, and the events are written to files there by
the inputs.

Some convenient commands are set up in the path for every instance:

- `instanceid` gives the id of the instance so that you can easily match
  it up to the configs here.

- `lsevents` shows the directory where events are being written to file.
  This lets you get a quick overview of how many events are flowing and
  whether they're making it all way to the final instance.
