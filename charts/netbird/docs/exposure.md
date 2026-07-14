# NetBird exposure

NetBird requires both HTTP/gRPC and UDP exposure for a complete production setup.

Expose TCP `443` through an Ingress, Gateway, load balancer, or reverse proxy. This endpoint carries the dashboard, management API, gRPC, signal, and relay traffic.

Expose UDP `3478` from the server Service for STUN. Kubernetes Ingress does not support UDP, so use a LoadBalancer Service, Gateway implementation with UDP support, or infrastructure-specific listener.

When using path-based routing, send dashboard paths to the `dashboard` service and API/gRPC paths to the `server` service. Many installations are simpler with a dedicated hostname for NetBird and reverse proxy rules that preserve HTTP/2 or gRPC behavior.
