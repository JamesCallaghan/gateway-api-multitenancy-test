FROM envoyproxy/envoy:v1.27-latest
RUN apt update && apt install tcpdump -y
COPY scripts/tcpdump.sh /tcpdump.sh
RUN chmod +x /tcpdump.sh