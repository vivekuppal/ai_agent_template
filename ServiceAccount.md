# Service account creation

Least-privilege setup for two service accounts:

- Runtime Service Account (Used by Cloud Run container to read/write GCS)
- Push Invoker Service Account (Used by Pub/Sub to sign the OIDC token when pushing to Cloud Run)

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

# 1) Create the service accounts

```
gcloud iam service-accounts create %RUNTIME_SA_NAME%  --project %PROJECT_ID% --display-name "AI Agent Runtime SA"

gcloud iam service-accounts create %PUSH_SA_NAME% --project %PROJECT_ID% --display-name "Pub/Sub Push Invoker SA"
```


# 2) Grant bucket-scoped minimal roles to the Runtime SA

- Read the new objects
- Write your component’s outputs (creating new objects only)

```
# Read/list objects
gcloud storage buckets add-iam-policy-binding gs://%BUCKET% --member="serviceAccount:%RUNTIME_SA%" --role="roles/storage.objectViewer" --project %PROJECT_ID%

# Create new objects (no overwrite/delete)
gcloud storage buckets add-iam-policy-binding "gs://%BUCKET%" --member="serviceAccount:%RUNTIME_SA%" --role="roles/storage.objectCreator" --project %PROJECT_ID%

```

# 3) Allow Pub/Sub to mint OIDC tokens for the Push SA
Pub/Sub’s service agent must have Service Account Token Creator on the Push SA:

```
Enable the pub sub service
gcloud services enable pubsub.googleapis.com --project %PROJECT_ID%

Check that the service agent now exists
gcloud iam service-accounts list --project %PROJECT_ID% --filter='email:gcp-sa-pubsub'

# (Optional) 3) Proactively create the service identity if it still hasn’t shown up
gcloud beta services identity create --service=pubsub.googleapis.com --project=%PROJECT_ID%


gcloud iam service-accounts add-iam-policy-binding %PUSH_SA% --member="serviceAccount:service-%PROJECT_NUMBER%@gcp-sa-pubsub.iam.gserviceaccount.com" --role="roles/iam.serviceAccountTokenCreator" --project %PROJECT_ID%

```

# 4) (For later) Grant the Push SA permission to invoke your Cloud Run service

Run this after we deploy the service in Step 3:

```
# AFTER deployment; replace SERVICE with your Cloud Run service name
SET SERVICE="ai-agent"
gcloud run services add-iam-policy-binding "$SERVICE" --region %REGION% --project %PROJECT_ID% --member="serviceAccount:%PUSH_SA%" --role="roles/run.invoker"

```
