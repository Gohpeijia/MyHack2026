"""
llm_router.py — Multi-provider LLM fallback chain (Enterprise Google Cloud Edition).

Priority order:
  1. Gemini 2.5 Flash (Google Cloud Vertex AI)
  2. Grok 4.20        (Google Cloud Model Garden)
  3. Qwen 3.6         (Google Cloud Model Garden)
  4. Groq             (Standard API fallback)
"""

import os
import time
import requests
from dotenv import load_dotenv

# NEW: Google Cloud Authentication
import google.auth
import google.auth.transport.requests

load_dotenv() 

# ---------------------------------------------------------------------------
# Google Cloud Configuration
# ---------------------------------------------------------------------------
GCP_PROJECT = os.getenv("GCP_PROJECT_ID", "myhack-55a43")
GCP_LOCATION = os.getenv("GCP_LOCATION", "us-central1")

# Vertex AI's new OpenAI-compatible endpoint!
GCP_BASE_URL = f"https://{GCP_LOCATION}-aiplatform.googleapis.com/v1beta1/projects/{GCP_PROJECT}/locations/{GCP_LOCATION}/endpoints/openapi/chat/completions"

def get_gcp_headers(dummy_key=""):
    """
    Uses your firebase-adminsdk.json to generate a live, secure OAuth token.
    This replaces the need for static API keys for Google Cloud models.
    """
    try:
        credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
        auth_req = google.auth.transport.requests.Request()
        credentials.refresh(auth_req)
        return {
            "Authorization": f"Bearer {credentials.token}",
            "Content-Type": "application/json",
        }
    except Exception as e:
        print(f"❌ Failed to generate Google Cloud Token. Check GOOGLE_APPLICATION_CREDENTIALS: {e}")
        return {}

def get_standard_headers(api_key: str):
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

# ---------------------------------------------------------------------------
# Provider Configurations
# ---------------------------------------------------------------------------
PROVIDERS = [
    {
        "name": "Gemini 2.5 Flash (Google Cloud)",
        "env_key": "GCP_PROJECT_ID", # Used just to check if GCP is configured
        "url": GCP_BASE_URL,
        "model": "google/gemini-2.5-flash",
        "max_tokens": 4000,
        "headers_fn": get_gcp_headers,
    },
    {
        "name": "Qwen 3.6 (Google Cloud)",
        "env_key": "GCP_PROJECT_ID",
        "url": GCP_BASE_URL,
        # Note: Check your Model Garden deployment for the exact string if this throws a 404
        "model": "qwen/qwen3.6-35b", 
        "max_tokens": 4000,
        "headers_fn": get_gcp_headers,
    },
    {
        "name": "Grok 4.20 (Google Cloud)",
        "env_key": "GCP_PROJECT_ID",
        "url": GCP_BASE_URL,
        "model": "xai/grok-4.20", 
        "max_tokens": 4000,
        "headers_fn": get_gcp_headers,
    },
    {
        "name": "Groq (Standard API)",
        "env_key": "GROQ_API_KEY",
        "url": "https://api.groq.com/openai/v1/chat/completions",
        "model": "llama-3.3-70b-versatile", 
        "max_tokens": 4000,
        "headers_fn": get_standard_headers,
    }
]

# ---------------------------------------------------------------------------
# Generic OpenAI-compatible caller
# ---------------------------------------------------------------------------
def _call_openai_compatible(provider: dict, api_key: str, system_prompt: str, user_prompt: str, temperature: float) -> str:
    headers = provider["headers_fn"](api_key)
    if not headers:
        raise Exception("Failed to generate headers (Missing Token/Key)")

    response = requests.post(
        provider["url"],
        headers=headers,
        json={
            "model": provider["model"],
            "temperature": temperature,
            "max_tokens": provider["max_tokens"],
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user",   "content": user_prompt},
            ],
        },
        timeout=60,
    )

    if not response.ok:
        raise Exception(f"HTTP {response.status_code}: {response.text[:250]}")

    data = response.json()
    choices = data.get("choices", [])
    if not choices:
        raise Exception("Returned empty choices array")

    return (choices[0].get("message") or {}).get("content", "").strip()

# ---------------------------------------------------------------------------
# Main router
# ---------------------------------------------------------------------------
def call_llm(system_prompt: str, user_prompt: str, temperature: float = 0.2) -> str:
    """Try each provider in order. Returns the first successful response."""
    errors = []

    for provider in PROVIDERS:
        # For GCP models, we just need the environment variable to exist to trigger it
        keys = [k.strip() for k in os.getenv(provider["env_key"], "").split(",") if k.strip()]

        if not keys:
            print(f"[LLM Router] Skipping {provider['name']} — env variable {provider['env_key']} not found.")
            continue

        for idx, api_key in enumerate(keys):
            try:
                print(f"[LLM Router] Trying {provider['name']}...")
                
                content = _call_openai_compatible(
                    provider=provider,
                    api_key=api_key,
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    temperature=temperature
                )

                print(f"[LLM Router] ✅ {provider['name']} succeeded!")
                return content

            except Exception as exc:
                err_msg = f"{provider['name']}: {exc}"
                errors.append(err_msg)
                print(f"[LLM Router] ❌ {err_msg}")
                time.sleep(1)

    raise Exception("All LLM providers failed.\n" + "\n".join(errors))