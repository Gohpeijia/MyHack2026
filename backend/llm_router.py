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
) -> str:
    """Call any OpenAI-compatible endpoint and return stripped content."""
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

    # Detect HTML error pages (e.g., Cloudflare blocks or gateway timeouts)
    if "text/html" in response.headers.get("content-type", ""):
        raise Exception(f"Returned HTML error (HTTP {response.status_code})")

    if not response.ok:
        raise Exception(f"HTTP {response.status_code}: {response.text[:200]}")

    data = response.json()
    choices = data.get("choices", [])
    if not choices:
        raise Exception("Returned empty choices array")

    first = choices[0]
    finish_reason = str(first.get("finish_reason", "")).lower()
    content = (first.get("message") or {}).get("content")

    if not content and finish_reason == "length":
        raise Exception("Hit max_tokens with no content (finish_reason=length)")

    if not content:
        raise Exception(f"Returned empty content (finish_reason={finish_reason})")

    return content.strip()


# ---------------------------------------------------------------------------
# Main router
# ---------------------------------------------------------------------------

def call_llm(system_prompt: str, user_prompt: str, temperature: float = 0.2) -> str:
    """Try each provider in order. Returns the first successful response."""
    errors = []

    for provider in PROVIDERS:
        # 支持通过逗号分隔传入多个备用 Key (e.g. KEY1,KEY2)
        keys = [k.strip() for k in os.getenv(provider["env_key"], "").split(",") if k.strip()]

        if not keys:
            print(f"[LLM Router] Skipping {provider['name']} — no API key in .env")
            continue

        for idx, api_key in enumerate(keys):
            try:
                print(f"[LLM Router] Trying {provider['name']} (Key {idx + 1}/{len(keys)})...")

                # 直接调用合并后的核心请求函数
                content = _call_openai_compatible(
                    provider=provider,
                    api_key=api_key,
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    temperature=temperature
                )

                print(f"[LLM Router] ✅ {provider['name']} succeeded with Key {idx + 1}")
                return content

            except Exception as exc:
                err_msg = f"{provider['name']} (Key {idx + 1}): {exc}"
                errors.append(err_msg)
                print(f"[LLM Router] ❌ {err_msg}")
                
                # 容错缓冲，避免请求过快被连续拒绝
                time.sleep(1)

    # 如果所有 Provider 和 Key 全都挂了，抛出汇总异常
    raise Exception("All LLM providers failed.\n" + "\n".join(errors))