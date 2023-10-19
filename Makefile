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

.PHONY: tenant-e-infra-install
tenant-e-infra-install:
	helm install --set config.envoyGateway.gateway.controllerName=gateway.envoyproxy.io/tenant-e-gatewayclass-controller \
	eg-tenant-e oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 \
	-n tenant-e --create-namespace
	kubectl apply -f manifests/tenant-e.yaml

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

.PHONY: curl-tenant-b-malicious
curl-tenant-b-malicious:
	curl --verbose --header "Host: www.tenant-b.example.com" http://localhost:8889/totally-legit

.PHONY: curl-tenant-d
curl-tenant-d:
	curl --verbose --header "Host: www.tenant-d.example.com" http://localhost:8888/get

.PHONY: malicious-httproute
malicious-httproute:
	kubectl apply -f manifests/tenant-c-malicious-httproute.yaml

.PHONY: build-malicious-envoy
build-malicious-envoy:
	docker build -t tcpdump-envoy:v0.1 .
	kind load docker-image tcpdump-envoy:v0.1 -n egw

.PHONY: port-forward-tenant-e
port-forward-tenant-e:
	$(eval ENVOY_SERVICE_E := $(shell kubectl get svc -n tenant-e --selector=gateway.envoyproxy.io/owning-gateway-namespace=tenant-e,gateway.envoyproxy.io/owning-gateway-name=eg -o jsonpath='{.items[0].metadata.name}'))
	kubectl -n tenant-e port-forward service/${ENVOY_SERVICE_E} 8890:8080 &

.PHONY: curl-tenant-e
curl-tenant-e:
	curl --verbose --header "Host: www.tenant-e.example.com" http://localhost:8890/get

.PHONY: exec-into-proxy-e
exec-into-proxy-e:
	scripts/exec-into-proxy-e.sh

.PHONY: create-malicious-proxy
create-malicious-proxy:
	kubectl apply -f manifests/malicious-proxy.yaml

.PHONY: patch-gatewayclass
patch-gatewayclass:
	./scripts/perform-action-as-gateway.sh \ 
	kubectl apply -f manifests/malicious-gatewayclass.yaml

.PHONY: restart-shared-pods
restart-shared-pods:
	./scripts/restart-shared-pods.sh

.PHONY: grep-shared-envoy-image
grep-shared-envoy-image:
	./scripts/grep-envoy-image.sh

.PHONY: teardown
teardown:
	kind delete cluster --name egw