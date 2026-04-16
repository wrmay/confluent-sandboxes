# Overview and Concepts 

Cluster links allow data to be copied between topics in two different clusters.  
For a given topic data will only flow in one direction at a time.  The 
direction of data flow can be different for different topics or, for a 
single topic at two different times.

A _cluster_link_ is essentially just a connection between two clusters. It 
contains the information required to establish a connection including 
bootstrap servers and credentials for authentication.  

A _mirror_ is an instruction to replicate messages in one direction or 
the other.  When a mirror is set up, only one side, the source, is writable.
The target side is read only and can be considered a warm standby.  

# Labs

## Basic Cluster Linking on Docker 
