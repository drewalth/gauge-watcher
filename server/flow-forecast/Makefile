
# http://localhost:8000/openapi.json

SERVER_HOST=http://localhost:8000

generate_clients: swift_client validate_swift_client

swift_client:
	openapi-generator generate \
	-i $(SERVER_HOST)/openapi.json \
	-g swift5 \
	-o ./sdks/FlowForecast/ \
	--additional-properties projectName=FlowForecast \
	--additional-properties useSPMFileStructure=true \
	--additional-properties responseAs=AsyncAwait \
	--additional-properties swiftToolsVersion=5.9 \
	--additional-properties validatable=false

validate_swift_client:
	cd ./sdks/FlowForecast && swift build