Cloud Run deploy


# 0) Set variables

```
SET PROJECT_ID=YOUR_PROJECT_ID
SET REGION=us-east1
SET BUCKET=dmarc-ingest

# Names
SET RUNTIME_SA_NAME=ai-agent-sa
SET PUSH_SA_NAME=pubsub-push-sa

# Derived
SET RUNTIME_SA=%RUNTIME_SA_NAME%@%PROJECT_ID%.iam.gserviceaccount.com
SET PUSH_SA=%PUSH_SA_NAME%@%PROJECT_ID%.iam.gserviceaccount.com
SET PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"


gcloud projects describe "lappuai-prod" --format=value(projectNumber)

```


```
SET PROJECT_ID=YOUR_PROJECT_ID
SET REGION=us-east1
SET SERVICE="ai-agent"
export IMAGE="gcr.io/${PROJECT_ID}/${SERVICE}:$(date +%Y%m%d-%H%M%S)"

# from earlier step
export RUNTIME_SA="ai-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com"
export PUSH_SA="pubsub-push-sa@${PROJECT_ID}.iam.gserviceaccount.com"

```