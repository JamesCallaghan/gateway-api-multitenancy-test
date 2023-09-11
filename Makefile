.PHONY: cluster-up
cluster-up:
	kind create cluster --image kindest/node:v1.27.3 --name egw

.PHONY: shared-controller-install
shared-controller-install:
	helm install --set config.envoyGateway.gateway.controllerName=gateway.envoyproxy.io/shared-gatewayclass-controller \
	eg-shared oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 \
	-n shared --create-namespace

.PHONY: tenant-a-controller-install
tenant-a-controller-install:
	helm install --set config.envoyGateway.gateway.controllerName=gateway.envoyproxy.io/tenant-a-gatewayclass-controller \
	eg-tenant-a oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 \
	-n tenant-a --create-namespace

.PHONY: gwc-tenant-a
gwc-tenant-a:
	kubectl apply -f ./manifests/gwc-tenant-a.yaml

.PHONY: gwc-shared
gwc-shared:
	kubectl apply -f ./manifests/gwc-shared.yaml

.PHONY: shared-gw-create
shared-gw-create:
	kubectl apply -f ./manifests/shared-gw.yaml

.PHONY: run-backend-services
run-backend-services:
	kubectl apply -f ./manifests/tenant-a.yaml
	kubectl apply -f ./manifests/tenant-b.yaml
	kubectl apply -f ./manifests/tenant-c.yaml
	kubectl apply -f ./manifests/tenant-d.yaml
	
.PHONY: cross-ns-route-create
cross-ns-route-create:	
	kubectl apply -f ./manifests/cross-ns-route.yaml
	
.PHONY: ref-grant-create
ref-grant-create:	
	kubectl apply -f ./manifests/ref-grant.yaml

.PHONY: port-forward-tenant-a
port-forward-tenant-a:
	$(eval ENVOY_SERVICE_A := $(shell kubectl get svc -n tenant-a --selector=gateway.envoyproxy.io/owning-gateway-namespace=tenant-a,gateway.envoyproxy.io/owning-gateway-name=eg -o jsonpath='{.items[0].metadata.name}'))
	kubectl -n tenant-a port-forward service/${ENVOY_SERVICE_A} 8888:8080 &

.PHONY: curl-tenant-a
curl-tenant-a:
	curl --verbose --header "Host: www.tenant-a.example.com" http://localhost:8888/get

.PHONY: port-forward-shared-tenants
port-forward-shared-tenants:
	$(eval ENVOY_SERVICE_SHARED := $(shell kubectl get svc -n shared --selector=gateway.envoyproxy.io/owning-gateway-namespace=shared,gateway.envoyproxy.io/owning-gateway-name=eg -o jsonpath='{.items[0].metadata.name}'))
	kubectl -n shared port-forward service/${ENVOY_SERVICE_SHARED} 8889:8080 &

.PHONY: curl-tenant-b
curl-tenant-b:
	curl --verbose --header "Host: www.tenant-b.example.com" http://localhost:8889/get

.PHONY: curl-tenant-c
curl-tenant-c:
	curl --verbose --header "Host: www.tenant-c.example.com" http://localhost:8889/get

.PHONY: curl-tenant-d
curl-tenant-d:
	curl --verbose --header "Host: www.tenant-d.example.com" http://localhost:8888/get

.PHONY: teardown
teardown:
	kind delete cluster --name egw