{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.configured.nginx;
  port = 9999;
  serverScript =
    pkgs.writeScriptBin "fastfetch-server"
    /*
    python
    */
    ''
      #!${pkgs.python3}/bin/python3
      from http.server import BaseHTTPRequestHandler, HTTPServer
      import subprocess
      import os

      class Handler(BaseHTTPRequestHandler):
          def do_GET(self):
              self.send_response(200)
              self.send_header('Content-type', 'text/plain; charset=utf-8')
              self.send_header('Access-Control-Allow-Origin', '*')
              self.end_headers()
              try:
                  env = os.environ.copy()
                  env['TERM'] = 'xterm-256color'

                  output = subprocess.check_output(
                      ['${pkgs.fastfetch}/bin/fastfetch', '--pipe', 'false'],
                      text=True,
                      env=env
                  )
                  self.wfile.write(output.encode('utf-8'))
              except Exception as e:
                  self.wfile.write(f"Error: {e}".encode('utf-8'))

      print(f"Starting fastfetch server on 127.0.0.1:{${toString port}}")
      httpd = HTTPServer(('127.0.0.1', ${toString port}), Handler)
      httpd.serve_forever()
    '';
in {
  config = lib.mkIf cfg.enable {
    systemd.services.fastfetch-server = {
      description = "Fastfetch HTTP Server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        ExecStart = "${serverScript}/bin/fastfetch-server";
        Restart = "always";
        User = "nobody";
        DynamicUser = true;
      };
    };

    services.nginx.virtualHosts."fastfetch.${cfg.domain}" = {
      forceSSL = true;
      useACMEHost = cfg.domain;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
      };
    };
  };
}
