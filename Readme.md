How this aligns with Google’s behavior (key points)

Push delivery is wrapped JSON by default: endpoint receives POST with { message: { data, attributes, ... } }, and data is base64. Can also opt into payload unwrapping if you prefer raw body; this template assumes the default wrapped format. 

GCS→Pub/Sub notifications put bucket/object info in message.attributes (e.g., eventType, bucketId, objectId, objectGeneration) and can also include a JSON representation of the object in message.data (when payloadFormat=JSON_API_V1). 

We read the exact object generation for idempotency and correctness; generation changes whenever content changes (metageneration changes on metadata updates). 

The Storage client can pin reads to a generation (and even enforce if_generation_match); that’s what this template uses. 

For auth, a push subscription can attach an OIDC ID token (Bearer) and Cloud Run can validate it automatically when you restrict the service and grant run.invoker to the push identity; manual verification is optional. 

Handler should return 2xx (commonly 204) on success to ack the message; non-2xx triggers Pub/Sub retries with backoff. 


## Local Testing
Env Setup
```
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
```

Send a sample Pub/Sub push payload (wrapped):

```
curl -s -X POST http://localhost:8080/ -H "Content-Type: application/json" -d  @data.json

```

## Env Variables

```
COMPONENT_NAME=ai-scorer

EXPECTED_EVENT_TYPE=OBJECT_FINALIZE

OBJECT_PREFIX=reports/ (if you want to scope)

OUTPUT_PREFIX=outputs/ai-scorer/

REQUIRE_JWT=true and PUBSUB_ALLOWED_AUDIENCE=<your push endpoint URL> if you want in-app token verification (optional; Cloud Run can enforce it without this).
```


# Steps for creating an AI Agent

This set up assumes
- We are creating an event based trigger for the AI agent
- Event based trigger uses PUB SUB as the techincal implementation
- The code is python based

This set up creates
- All necessary infrastructure required for the agent on GCP
- Uses Pub sub
- Assumes code is written in Python

Run the following bat file
```
create-agent.bat
```

# Steps for removing the AI Agent created above

Run the following bat file
```
teardown.bat
```

# Misc files
smoke.json - Empty json file for testing the functionality
