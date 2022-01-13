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

