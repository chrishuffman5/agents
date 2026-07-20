#!/usr/bin/env python3
"""
============================================================================
Python - REST API Client

Purpose : Generic REST API client with auth, pagination, retry, and
          rate limiting. Includes GitHub API example subclass.
Version : 1.0.0
Targets : Python 3.10+
Requires: requests (pip install requests)
Safety  : Read-only by default (GET). Other methods require explicit use.

Usage:
  python3 02-api-client.py --token $GITHUB_TOKEN repos --org python
  python3 02-api-client.py --token $TOKEN rate-limit
  python3 02-api-client.py --token $TOKEN issues cpython
============================================================================
"""

import argparse
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Any, Iterator

try:
    import requests
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry
except ImportError:
    print("Error: requests not installed. Run: pip install requests", file=sys.stderr)
    sys.exit(1)

log = logging.getLogger("api_client")


class APIClient:
    """Generic REST API client with retry, pagination, rate limiting."""

    def __init__(self, base_url: str, token: str | None = None,
                 api_key: str | None = None, timeout: int = 30,
                 max_retries: int = 3, rate_limit_delay: float = 0.0) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self._rate_delay = rate_limit_delay
        self._last_request = 0.0

        self._session = requests.Session()
        self._session.headers["Accept"] = "application/json"
        if token:
            self._session.headers["Authorization"] = f"Bearer {token}"
        if api_key:
            self._session.headers["X-API-Key"] = api_key

        retry = Retry(total=max_retries, backoff_factor=1.0,
                      status_forcelist=[429, 500, 502, 503, 504],
                      respect_retry_after_header=True)
        self._session.mount("https://", HTTPAdapter(max_retries=retry))
        self._session.mount("http://", HTTPAdapter(max_retries=retry))

    def _throttle(self) -> None:
        if self._rate_delay > 0:
            elapsed = time.monotonic() - self._last_request
            if elapsed < self._rate_delay:
                time.sleep(self._rate_delay - elapsed)
        self._last_request = time.monotonic()

    def _request(self, method: str, path: str, **kwargs: Any) -> requests.Response:
        self._throttle()
        url = f"{self.base_url}{path}"
        log.debug("%s %s", method, url)
        resp = self._session.request(method, url, timeout=self.timeout, **kwargs)
        resp.raise_for_status()
        return resp

    def get(self, path: str, **params: Any) -> Any:
        return self._request("GET", path, params=params).json()

    def post(self, path: str, body: dict) -> Any:
        return self._request("POST", path, json=body).json()

    def paginate(self, path: str, per_page: int = 100,
                 items_key: str | None = None) -> Iterator[Any]:
        page = 1
        while True:
            data = self.get(path, page=page, per_page=per_page)
            items = data if isinstance(data, list) else data.get(items_key or "data", [])
            if not items:
                break
            yield from items
            if len(items) < per_page:
                break
            page += 1

    def close(self) -> None:
        self._session.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


class GitHubAPIClient(APIClient):
    def __init__(self, token: str) -> None:
        super().__init__("https://api.github.com", token=token, rate_limit_delay=0.1)
        self._session.headers["X-GitHub-Api-Version"] = "2022-11-28"

    def list_repos(self, org: str) -> list[dict]:
        return list(self.paginate(f"/orgs/{org}/repos"))

    def get_repo(self, owner: str, repo: str) -> dict:
        return self.get(f"/repos/{owner}/{repo}")

    def list_issues(self, owner: str, repo: str, state: str = "open") -> list[dict]:
        return list(self.paginate(f"/repos/{owner}/{repo}/issues"))

    def rate_limit(self) -> dict:
        return self.get("/rate_limit")


def main() -> None:
    parser = argparse.ArgumentParser(description="REST API client (GitHub demo)")
    parser.add_argument("--token", default=os.getenv("GITHUB_TOKEN"))
    parser.add_argument("--org", default="python")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("-v", "--verbose", action="store_true")

    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("repos", help="List repositories")
    sub.add_parser("rate-limit", help="Show rate limit")
    issues_p = sub.add_parser("issues", help="List issues")
    issues_p.add_argument("repo", help="Repository name")

    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.WARNING,
                        format="%(asctime)s %(levelname)-8s %(message)s", datefmt="%H:%M:%S")

    if not args.token:
        print("Error: --token or GITHUB_TOKEN required", file=sys.stderr)
        sys.exit(1)

    with GitHubAPIClient(args.token) as client:
        try:
            if args.cmd == "repos":
                data = client.list_repos(args.org)
                result = [{"name": r["name"], "stars": r["stargazers_count"],
                           "language": r.get("language")} for r in data]
            elif args.cmd == "rate-limit":
                result = client.rate_limit()
            elif args.cmd == "issues":
                data = client.list_issues("python", args.repo)
                result = [{"number": i["number"], "title": i["title"],
                           "state": i["state"]} for i in data]
            else:
                parser.print_help()
                sys.exit(1)
        except requests.HTTPError as e:
            print(f"HTTP Error: {e}", file=sys.stderr)
            sys.exit(1)

    output = json.dumps(result, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
        print(f"Written to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
