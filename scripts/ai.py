#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx"]
# ///

import argparse
import httpx
import json
import logging
import os
import sys


def main():
    parser = argparse.ArgumentParser(description="Query ai.dimalip.in")
    parser.add_argument("text", nargs="*", help="Prompt text (or pipe via stdin)")
    parser.add_argument("-m", "--model", default="default", help="Model name (default: default)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show network logs")
    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
        logging.getLogger("httpx").setLevel(logging.DEBUG)
        logging.getLogger("httpcore").setLevel(logging.DEBUG)

    api_key = os.environ.get("CLIPROXYAPI_API_KEY") or (os.environ.get("CLIPROXYAPI_API_KEYS") or "").split(",")[0]
    if not api_key:
        print("Error: set CLIPROXYAPI_API_KEY or CLIPROXYAPI_API_KEYS env var", file=sys.stderr)
        sys.exit(1)

    if args.text:
        text = " ".join(args.text)
    elif not sys.stdin.isatty():
        text = sys.stdin.read().strip()
    else:
        print("Error: provide text as argument or pipe via stdin", file=sys.stderr)
        sys.exit(1)

    with httpx.Client(base_url="https://ai.dimalip.in/v1", timeout=120) as client:
        with client.stream(
            "POST",
            "/chat/completions",
            headers={"Authorization": f"Bearer {api_key}"},
            json={
                "model": args.model,
                "messages": [{"role": "user", "content": text}],
                "stream": True,
            },
        ) as resp:
            resp.raise_for_status()
            for line in resp.iter_lines():
                if not line.startswith("data: "):
                    continue
                data = line[6:]
                if data == "[DONE]":
                    break
                chunk = json.loads(data)
                choices = chunk.get("choices", [])
                if not choices:
                    continue
                content = choices[0].get("delta", {}).get("content")
                if content:
                    print(content, end="", flush=True)

    print()


if __name__ == "__main__":
    main()
