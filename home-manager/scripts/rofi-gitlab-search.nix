{pkgs, ...}: let
  # Python script to handle token refresh and OAuth PKCE flow natively
  authScript =
    pkgs.writeScript "rofi-gitlab-auth.py"
    # python
    ''
      #!/usr/bin/env python3
      import sys, json, os, time, urllib.request, urllib.parse, hashlib, base64
      import webbrowser
      from http.server import BaseHTTPRequestHandler, HTTPServer

      CLIENT_ID = "4fa10a200cd268c5ef6be43a16f28a46c3dac7b0048b36930152a4b3e16c7cdf"
      REDIRECT_URI = "http://127.0.0.1:8888/callback"
      TOKEN_PATH = os.path.expanduser("~/.local/state/gitlab-mcp/token.json")
      GITLAB_URL = "https://gitlab.meetovo.dev"

      os.makedirs(os.path.dirname(TOKEN_PATH), exist_ok=True)

      def read_token():
          if not os.path.exists(TOKEN_PATH): return None
          try:
              with open(TOKEN_PATH, "r") as f:
                  return json.load(f)
          except: return None

      def write_token(data):
          with open(TOKEN_PATH, "w") as f:
              json.dump(data, f)

      def is_valid(token):
          if not token or "expires_in" not in token or "created_at" not in token: return False
          expires_at = token["created_at"]/1000 + token["expires_in"]
          return time.time() < (expires_at - 60)

      def refresh(token):
          if "refresh_token" not in token: return False
          data = urllib.parse.urlencode({
              "client_id": CLIENT_ID,
              "refresh_token": token["refresh_token"],
              "grant_type": "refresh_token",
              "redirect_uri": REDIRECT_URI
          }).encode("utf-8")
          req = urllib.request.Request(f"{GITLAB_URL}/oauth/token", data=data)
          try:
              with urllib.request.urlopen(req) as response:
                  res = json.loads(response.read().decode())
                  res["created_at"] = int(time.time() * 1000)
                  write_token(res)
                  return True
          except:
              return False

      token = read_token()
      if token and is_valid(token):
          sys.exit(0)
      if token and refresh(token):
          sys.exit(0)

      # Need OAuth
      code_verifier = base64.urlsafe_b64encode(os.urandom(32)).rstrip(b'=').decode('ascii')
      code_challenge = base64.urlsafe_b64encode(hashlib.sha256(code_verifier.encode('ascii')).digest()).rstrip(b'=').decode('ascii')

      state = base64.urlsafe_b64encode(os.urandom(16)).rstrip(b'=').decode('ascii')

      params = {
          "client_id": CLIENT_ID,
          "redirect_uri": REDIRECT_URI,
          "response_type": "code",
          "state": state,
          "code_challenge": code_challenge,
          "code_challenge_method": "S256"
      }
      auth_url = f"{GITLAB_URL}/oauth/authorize?{urllib.parse.urlencode(params)}"

      auth_code = None

      class Handler(BaseHTTPRequestHandler):
          def log_message(self, format, *args): pass
          def do_GET(self):
              global auth_code
              url = urllib.parse.urlparse(self.path)
              if url.path == "/callback":
                  query = urllib.parse.parse_qs(url.query)
                  if "code" in query:
                      auth_code = query["code"][0]
                      self.send_response(200)
                      self.send_header("Content-type", "text/html")
                      self.end_headers()
                      self.wfile.write(b"<html><body><h1>Successfully authenticated!</h1><p>You can close this window now.</p><script>window.close()</script></body></html>")
                      return
              self.send_response(400)
              self.end_headers()

      server = HTTPServer(("127.0.0.1", 8888), Handler)
      webbrowser.open(auth_url)
      server.handle_request() # wait for 1 request

      if auth_code:
          data = urllib.parse.urlencode({
              "client_id": CLIENT_ID,
              "code": auth_code,
              "grant_type": "authorization_code",
              "redirect_uri": REDIRECT_URI,
              "code_verifier": code_verifier
          }).encode("utf-8")
          req = urllib.request.Request(f"{GITLAB_URL}/oauth/token", data=data)
          try:
              with urllib.request.urlopen(req) as response:
                  res = json.loads(response.read().decode())
                  res["created_at"] = int(time.time() * 1000)
                  write_token(res)
                  sys.exit(0)
          except Exception as e:
              pass
      sys.exit(1)
    '';

  rofiScript = pkgs.writeShellScript "rofi-gitlab-search" ''
    export PATH="${pkgs.jq}/bin:${pkgs.curl}/bin:${pkgs.wl-clipboard}/bin:${pkgs.libnotify}/bin:$PATH"

    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/tmp}"
    MRS_JSON="$RUNTIME_DIR/rofi_gitlab_mrs.json"
    SEL_JSON="$RUNTIME_DIR/rofi_gitlab_selected.json"

    if [ -z "$@" ]; then
      # 1. Check authentication
      if ! ${pkgs.python3}/bin/python3 ${authScript}; then
        # If it returns non-zero, it means it opened the browser or failed.
        # We exit 0 so rofi closes and gets out of the way.
        exit 0
      fi

      # 2. Fetch MRs
      TOKEN=$(jq -r .access_token ~/.local/state/gitlab-mcp/token.json)
      HDR="Authorization: Bearer $TOKEN"
      URL="https://gitlab.meetovo.dev/api/v4"

      fetch_mrs() {
        local query="$1"
        local label="$2"
        curl -s -H "$HDR" "$URL/merge_requests?state=opened&scope=all&per_page=50&$query=m4r1vs" | \
          jq -c ".[] | {id: .iid, title: .title, url: .web_url, ref: .source_branch, label: \"$label\", project: ((.references.full // \"!\(.iid)\") | sub(\"^.*/\"; \"\") | sub(\"^meetovo-\"; \"\"))}"
      }

      {
        fetch_mrs "assignee_username" "  " &
        fetch_mrs "reviewer_username" "  " &
        wait
      } | jq -s 'unique_by(.url)' > "$MRS_JSON"

      # Print to rofi
      jq -r '.[] | "\(.label)\(.project): \(.title)\u0000info\u001f\(.url)"' "$MRS_JSON"

    elif [[ "$1" == "Open in GitLab" || "$1" == "Copy URL" || "$1" == "Copy Branch" ]]; then
      # 4. Handle Action
      if [ ! -s "$SEL_JSON" ]; then exit 0; fi

      MR_URL=$(jq -r .url "$SEL_JSON" | head -n 1)
      MR_REF=$(jq -r .ref "$SEL_JSON" | head -n 1)

      if [ "$1" == "Open in GitLab" ]; then
        nohup ${pkgs.xdg-utils}/bin/xdg-open "$MR_URL" >/dev/null 2>&1 &
        disown -a
      elif [ "$1" == "Copy URL" ]; then
        echo -n "$MR_URL" | wl-copy
        notify-send "Copied URL" "$MR_URL"
      elif [ "$1" == "Copy Branch" ]; then
        echo -n "$MR_REF" | wl-copy
        notify-send "Copied Branch" "$MR_REF"
      fi
      exit 0
    else
      # 3. An MR was selected
      if [ -n "$ROFI_INFO" ]; then
        URL=$(echo -n "$ROFI_INFO" | tr -d '\n\r')
        jq -c --arg url "$URL" '.[] | select(.url == $url)' "$MRS_JSON" | head -n 1 > "$SEL_JSON"
      else
        jq -c --arg txt "$1" '.[] | select( $txt | contains("\(.project): \(.title)") )' "$MRS_JSON" | head -n 1 > "$SEL_JSON"
      fi

      if [ -s "$SEL_JSON" ]; then
        echo "Open in GitLab"
        echo "Copy URL"
        echo "Copy Branch"
      fi
    fi
  '';
in {
  rofi-gitlab-search = rofiScript;
}
