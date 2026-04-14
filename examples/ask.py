"""Simple client that asks llama-server a question via its OpenAI-compatible API.

Usage:
    python ask.py "Why is the sky blue?"

Environment:
    LLAMA_SERVER_URL  Base URL of the llama-server (default: http://localhost:8080)
"""

import json
import os
import sys
import urllib.request


def ask(question: str, server_url: str) -> str:
    payload = {
        "messages": [{"role": "user", "content": question}],
        "stream": False,
    }
    request = urllib.request.Request(
        f"{server_url}/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request) as response:
        body = json.loads(response.read().decode("utf-8"))
    return body["choices"][0]["message"]["content"]


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2

    question = " ".join(sys.argv[1:])
    server_url = os.environ.get("LLAMA_SERVER_URL", "http://localhost:8080")

    answer = ask(question, server_url)
    print(answer)
    return 0


if __name__ == "__main__":
    sys.exit(main())
