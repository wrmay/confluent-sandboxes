# OUTLINE 

- the basic idea is to establish a whole new network path to your cluster using custom listners
- only an idea at this point, would still need to be validated 
- Create your own load balancers with IPs that  you control. One for each eventual broker (so 12) and one for the bootstrap. Those LBs point at the existing broker/bootstrap service (in the k8s sense) 
  6 of the 12 services don't exist initially but hopefully you can still deploy the LBs. 
- Request firewall holes for those IPs
- Point names at those IPs: broker-0.partner.acme.com, broker-N.partner.acme.com, bootstrap.partner.acme.com (acme==ubs, partner==broadridge)
- Add custom listeners (see example below) to your broker config (see https://docs.confluent.io/operator/current/co-networking-overview.html#ak-listeners) 
  You can do this without stopping the whole cluster.  The custom listener acts like an additional advertised listener.  If the client connects over bootstrap.partner.acme.com then 
  the bootstrap will hand out broker-0/1/N.partner.acme.com.  Those names point to your static IPs.  
- I think you can test at this point without scaling up.  Verify a client can connect over bootstrap.partner.acme.com.  6 of the 12 LBs will be broken but you wont be using them anyway.
- scale up using the normal mechanism. New brokers will be deployed with new custom listeners pointing to the new name (broker-6.partner.acme.com).  New services will be created.
  The additional 6 LBs will start working.  


spec:
  listeners:
    custom:
      - name: partner
        port: 9206
        tls:
          enabled: true
        externalAccess:
          type: loadBalancer
          loadBalancer:
            domain: partner.acme.com
            bootstrapPrefix: bootstrap
            brokerPrefix: broker
            advertisedPort: 9206


 1490  minikube addons enable metallb
 1493  minikube addons configure metallb

