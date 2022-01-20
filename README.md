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

# In-progress notes

Describe the state of the project here as I make changes.

I'm adding a terraform template to create some AWS resources for the
project. I'm using the enabling team sandbox found at
https://manage.rackspace.com/racker/rackspace-accounts/1317477/aws-accounts/622383701450
Must be on vpn to reach it.

Generate temporary credentials through the RAX FAWS page above, copy
the exports into terminal, then just `terraform apply`.

On success, it'll write the public ip of the server it creates. SSH to
the instance as user `ec2-user`. It adds the local keypair to the server.

The state file is committed. Make sure to keep it up to date, but most
likely it'll always be empty in the repo. I should only have resources
up for a short time and destroy them when I'm finished.
