"""
llm_router.py — Multi-provider LLM fallback chain.

Priority order:
  1. Groq          (fastest, free tier)
  2. Cerebras      (fast inference, free tier)
  3. OpenRouter    (multi-model gateway, free tier)
  4. Gemini        (Google, free tier)

Add your keys to .env:
  GROQ_API_KEY=...
  CEREBRAS_API_KEY=...
  OPENROUTER_API_KEY=...
  GEMINI_API_KEY=...

Usage in vision_service.py:
  from llm_router import call_llm

  text = call_llm(system_prompt, user_prompt, temperature=0.2)
"""

import os
import time
import requests
from typing import Optional
from dotenv import load_dotenv
load_dotenv() 

# ---------------------------------------------------------------------------
# Provider configurations
# ---------------------------------------------------------------------------

PROVIDERS = [
    {
        "name": "Groq",
        "env_key": "GROQ_API_KEY",
        "url": "https://api.groq.com/openai/v1/chat/completions",
        "model": "llama-3.3-70b-versatile", 
        "max_tokens": 4000,
        "headers_fn": lambda key: {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    },
    {
        "name": "Cerebras",
        "env_key": "CEREBRAS_API_KEY",
        "url": "https://api.cerebras.ai/v1/chat/completions",
        "model": "llama-3.3-70b",       
        "max_tokens": 4000,
        "headers_fn": lambda key: {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        },
    {
        "name": "OpenRouter",
        "env_key": "OPENROUTER_API_KEY",
        "url": "https://openrouter.ai/api/v1/chat/completions",
        "model": "meta-llama/llama-3.3-70b-instruct:free", 
        "max_tokens": 4000,
        "headers_fn": lambda key: {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    },
    {
        "name": "Gemini",
       "env_key": "GEMINI_API_KEY",
        "url": "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",  
        "model": "gemini-2.0-flash",
        "max_tokens": 4000,
        "headers_fn": lambda key: {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    },
]


# ---------------------------------------------------------------------------
# Generic OpenAI-compatible caller
# ---------------------------------------------------------------------------

def _call_openai_compatible(
    provider: dict,
    api_key: str,
    system_prompt: str,
    user_prompt: str,
    temperature: float,
) -> Optional[str]:
    """Call any OpenAI-compatible endpoint."""
    response = requests.post(
        provider["url"],
        headers=provider["headers_fn"](api_key),
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

    # Detect HTML error pages
    if "text/html" in response.headers.get("content-type", ""):
        raise Exception(f"{provider['name']} returned HTML error (HTTP {response.status_code})")

    if not response.ok:
        raise Exception(f"{provider['name']} HTTP {response.status_code}: {response.text[:200]}")

    data = response.json()

    # Check finish_reason — skip if cut off with no content
    choices = data.get("choices", [])
    if not choices:
        raise Exception(f"{provider['name']} returned no choices")

    first = choices[0]
    finish_reason = str(first.get("finish_reason", "")).lower()
    content = (first.get("message") or {}).get("content")

    if not content and finish_reason == "length":
        raise Exception(f"{provider['name']} hit max_tokens with no content (finish_reason=length)")

    if not content:
        raise Exception(f"{provider['name']} returned empty content (finish_reason={finish_reason})")

    return content.strip()


# ---------------------------------------------------------------------------
# Main router
# ---------------------------------------------------------------------------
def call_llm(system_prompt: str, user_prompt: str, temperature: float = 0.2) -> str:
    """Try each provider in order. Returns the first successful response."""
    errors = []

    for provider in PROVIDERS:
        # Get keys and split by comma to support multiple fallback keys per provider
        keys = [k.strip() for k in os.getenv(provider["env_key"], "").split(",") if k.strip()]

        if not keys:
            print(f"[LLM Router] Skipping {provider['name']} — no API key in .env")
            continue

        for idx, api_key in enumerate(keys):
            try:
                print(f"[LLM Router] Trying {provider['name']} (Key {idx + 1}/{len(keys)})...")

                headers = {
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                    **provider.get("extra_headers", {})
                }

                payload = {
                    "model": provider["model"],
                    "temperature": temperature,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ]
                }

                response = requests.post(provider["url"], headers=headers, json=payload, timeout=60)
                
                # Catch HTML pages or bad status codes immediately
                if "text/html" in response.headers.get("content-type", ""):
                    raise ValueError(f"Returned HTML error (HTTP {response.status_code})")
                response.raise_for_status()

                # Parse JSON and extract content
                data = response.json()
                content = data.get("choices", [{}])[0].get("message", {}).get("content")
                finish_reason = data.get("choices", [{}])[0].get("finish_reason")

                if not content:
                    raise ValueError(f"Empty content returned (finish_reason={finish_reason})")

                print(f"[LLM Router] ✅ {provider['name']} succeeded with Key {idx + 1}")
                return content.strip()

            except Exception as exc:
                err_msg = f"{provider['name']} (Key {idx + 1}): {exc}"
                errors.append(err_msg)
                print(f"[LLM Router] ❌ {err_msg}")
                
                # Short wait before trying next key or provider
                time.sleep(1)

    # All providers and keys exhausted
    raise Exception("All LLM providers failed.\n" + "\n".join(errors))