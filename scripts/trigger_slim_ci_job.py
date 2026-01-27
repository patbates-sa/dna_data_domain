import os
import json
import urllib.request
import urllib.error


def main():
    token = os.environ["DBT_SERVICE_TOKEN"]
    account_id = os.environ["DBT_ACCOUNT_ID"]
    job_id = os.environ["DBT_JOB_ID"]
    pr_id = os.environ["PR_ID"]
    git_sha = os.environ["GIT_SHA"]
    base_url = os.environ.get("DBT_BASE_URL", "https://cloud.getdbt.com/api/v2")

    url = f"{base_url}/accounts/{account_id}/jobs/{job_id}/run/"

    payload = json.dumps({
        "cause": "GitHub Actions demo slim CI re-run",
        "github_pull_request_id": int(pr_id),
        "git_sha": git_sha,
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": f"Token {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode("utf-8")
            print(body)
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        print(err)
        raise SystemExit(f"Slim CI job trigger failed: HTTP {e.code}")

if __name__ == "__main__":
    main()
