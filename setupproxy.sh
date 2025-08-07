#!/bin/bash

CONFIG_DIR="/data/traefik/config"
TRAEFIK_YML="/data/traefik/traefik.yml"

mkdir -p "$CONFIG_DIR"

# ===== UTILITÁRIOS =====
checar_esc() {
  [[ "$1" == $'\e' ]] && echo -e "\n↩️ Cancelado." && sleep 1 && menu_principal
}

add_entrypoint() {
    local name="$1"
    local port="$2"

    if ! grep -q "  ${name}:" "$TRAEFIK_YML"; then
        echo "🔧 Adicionando entryPoint '${name}' na porta ${port}..."
        cp "$TRAEFIK_YML" "$TRAEFIK_YML.bak"

        awk -v epname="$name" -v epport="$port" '
        BEGIN {in_ep=0}
        /^entryPoints:/ {in_ep=1; print; next}
        in_ep && /^[^ ]/ {in_ep=0; print}
        {print}
        END {
            if (!in_ep) {
                print "entryPoints:"
                print "  " epname ":"
                print "    address: \"" epport "\""
            } else {
                print "  " epname ":"
                print "    address: \"" epport "\""
            }
        }
        ' "$TRAEFIK_YML" > "${TRAEFIK_YML}.tmp" && mv "${TRAEFIK_YML}.tmp" "$TRAEFIK_YML"

        echo "✅ EntryPoint '${name}' criado. Reinicie o Traefik se necessário."
    fi
}

pausar_explicacao() {
  echo -e "\nPressione ENTER para continuar ou ESC para cancelar..."
  read -rsn1 key
  [[ "$key" == $'\e' ]] && echo -e "\n↩️ Cancelado." && sleep 1 && menu_principal
}

criar_cors() {
  echo -e "
🌍 Criar middleware CORS"
  echo "Permite requisições entre origens diferentes. Útil para APIs."
  echo "Exemplo: habilitar CORS para api.exemplo.com"
  pausar_explicacao

  read -p "Digite o domínio que usará CORS: " dominio; checar_esc "$dominio"

  cat <<EOF > "$CONFIG_DIR/${dominio}_cors.yml"
http:
  routers:
    ${dominio//./_}_cors:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${dominio//./_}_svc
      middlewares:
        - cors
      tls:
        certResolver: letsencrypt
  middlewares:
    cors:
      headers:
        accessControlAllowOriginList:
          - "*"
        accessControlAllowMethods:
          - GET
          - OPTIONS
          - PUT
          - POST
          - DELETE
        accessControlAllowHeaders:
          - "*"
        accessControlAllowCredentials: true
        accessControlMaxAge: 100
  services:
    ${dominio//./_}_svc:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999"
EOF

  echo "✅ Middleware CORS criado para '$dominio'."
}

criar_headers_seg() {
  echo -e "
🛡️ Criar Headers de Segurança"
  echo "Adiciona cabeçalhos HTTP seguros (HSTS, XSS-Protection, etc)."
  echo "Exemplo: proteger site seguro.exemplo.com"
  pausar_explicacao

  read -p "Digite o domínio a proteger: " dominio; checar_esc "$dominio"

  cat <<EOF > "$CONFIG_DIR/${dominio}_headers.yml"
http:
  routers:
    ${dominio//./_}_headers:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${dominio//./_}_svc
      middlewares:
        - secure-headers
      tls:
        certResolver: letsencrypt
  middlewares:
    secure-headers:
      headers:
        frameDeny: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "no-referrer"
        permissionsPolicy:
          camera=(), microphone=(), geolocation=()
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
  services:
    ${dominio//./_}_svc:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999"
EOF

  echo "✅ Headers de segurança aplicados ao domínio '$dominio'."
}

criar_static_files() {
  echo -e "
🗂️ Criar servidor de arquivos estáticos"
  echo "Serve arquivos diretamente, útil para sites HTML simples."
  echo "Exemplo: servir /meusite apontando para /data/sites/meusite"
  pausar_explicacao

  read -p "Digite o domínio: " dominio; checar_esc "$dominio"
  read -p "Caminho absoluto da pasta com os arquivos: " caminho; checar_esc "$caminho"

  cat <<EOF > "$CONFIG_DIR/${dominio}_static.yml"
http:
  routers:
    ${dominio//./_}_static:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${dominio//./_}_svc
      tls:
        certResolver: letsencrypt
  services:
    ${dominio//./_}_svc:
      loadBalancer:
        servers:
          - url: "http://localhost"
  middlewares:
    static-files:
      stripPrefix:
        prefixes:
          - /
EOF

  echo "✅ Servidor estático configurado. Configure volume para '$caminho' no Traefik."
}

adicionar_subpath() {
  echo -e "
📁 Adicionar subcaminho a domínio"
  echo "Permite redirecionar um subpath (/painel) para outro serviço."
  echo "Exemplo: dominio.com/painel → IP 172.72.72.50:3000"
  pausar_explicacao

  read -p "Digite o domínio base (ex: dominio.com): " dominio; checar_esc "$dominio"
  read -p "Digite o subcaminho (ex: /painel): " subpath; checar_esc "$subpath"
  read -p "IP do destino: " ip; checar_esc "$ip"
  read -p "Porta do destino: " porta; checar_esc "$porta"

  path_clean=$(echo "$subpath" | sed 's/^\///')
  cat <<EOF > "$CONFIG_DIR/${dominio}_${path_clean}.yml"
http:
  routers:
    ${dominio//./_}_${path_clean}:
      rule: "Host(\"$dominio\") && PathPrefix(\"$subpath\")"
      entryPoints:
        - websecure
      service: ${dominio//./_}_${path_clean}_svc
      tls:
        certResolver: letsencrypt
  services:
    ${dominio//./_}_${path_clean}_svc:
      loadBalancer:
        servers:
          - url: "http://$ip:$porta"
EOF

  echo "✅ Subcaminho '$subpath' criado no domínio '$dominio'."
}

remover_config() {
  echo -e "
🧹 Remover configuração"
  echo "Permite excluir qualquer arquivo de configuração criado."
  echo "Use com cuidado. As alterações são imediatas."
  pausar_explicacao

  echo "Arquivos encontrados em $CONFIG_DIR:"
  ls "$CONFIG_DIR"

  read -p "Digite o nome exato do arquivo a remover (sem caminho): " arquivo; checar_esc "$arquivo"
  rm "$CONFIG_DIR/$arquivo" && echo "✅ Arquivo removido." || echo "❌ Erro ao remover."
}


criar_http() {
  echo -e "
🌐 Criar Proxy HTTP"
  echo "Redireciona um domínio para um IP e porta HTTP."
  echo "Exemplo: dominio.com → 172.72.72.10:8080"
  pausar_explicacao

  read -p "Digite o domínio: " dominio; checar_esc "$dominio"
  read -p "Digite o IP de destino: " ip; checar_esc "$ip"
  read -p "Digite a porta de destino: " porta; checar_esc "$porta"

  cat <<EOF > "$CONFIG_DIR/${dominio}_http.yml"
http:
  routers:
    ${dominio//./_}:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${dominio//./_}_svc
      tls:
        certResolver: letsencrypt
  services:
    ${dominio//./_}_svc:
      loadBalancer:
        servers:
          - url: "http://$ip:$porta"
EOF

  echo "✅ Proxy HTTP criado para '$dominio'."
}

criar_tcp() {
  echo -e "
🔌 Criar Proxy TCP"
  echo "Redireciona conexões TCP para IP:porta."
  echo "Exemplo: dominio.com porta 3306 (MySQL) → 172.72.72.11:3306"
  pausar_explicacao

  read -p "Digite o domínio: " dominio; checar_esc "$dominio"
  read -p "Porta de escuta (externa): " porta_entrada; checar_esc "$porta_entrada"
  read -p "IP de destino: " ip; checar_esc "$ip"
  read -p "Porta de destino: " porta_destino; checar_esc "$porta_destino"

  add_entrypoint "tcp_$porta_entrada" ":$porta_entrada/tcp"

  cat <<EOF > "$CONFIG_DIR/${dominio}_tcp_$porta_entrada.yml"
tcp:
  routers:
    ${dominio//./_}_tcp_$porta_entrada:
      rule: "HostSNI(\"$dominio\")"
      entryPoints:
        - tcp_$porta_entrada
      service: ${dominio//./_}_tcp_$porta_entrada_svc
  services:
    ${dominio//./_}_tcp_$porta_entrada_svc:
      loadBalancer:
        servers:
          - address: "$ip:$porta_destino"
EOF

  echo "✅ Proxy TCP criado para '$dominio' na porta $porta_entrada."
}

criar_udp() {
  echo -e "
📡 Criar Proxy UDP"
  echo "Redireciona conexões UDP para IP:porta."
  echo "Exemplo: dominio.com porta 51820 (WireGuard) → 172.72.72.11:51820"
  pausar_explicacao

  read -p "Digite o nome do serviço (sem domínio): " nome; checar_esc "$nome"
  read -p "Porta de escuta (externa): " porta_entrada; checar_esc "$porta_entrada"
  read -p "IP de destino: " ip; checar_esc "$ip"
  read -p "Porta de destino: " porta_destino; checar_esc "$porta_destino"

  add_entrypoint "udp_$porta_entrada" ":$porta_entrada/udp"

  cat <<EOF > "$CONFIG_DIR/${nome}_udp_$porta_entrada.yml"
udp:
  routers:
    ${nome}_udp_$porta_entrada:
      entryPoints:
        - udp_$porta_entrada
      service: ${nome}_udp_$porta_entrada_svc
  services:
    ${nome}_udp_$porta_entrada_svc:
      loadBalancer:
        servers:
          - address: "$ip:$porta_destino"
EOF

  echo "✅ Proxy UDP criado na porta $porta_entrada."
}

criar_lb() {
  echo -e "
⚖️ Criar Load Balancer"
  echo "Balanceia requisições entre vários IPs para um mesmo domínio."
  echo "Exemplo: dominio.com → [172.72.72.10:8080, 172.72.72.11:8080]"
  pausar_explicacao

  read -p "Digite o domínio: " dominio; checar_esc "$dominio"
  read -p "Digite a porta de destino dos servidores (ex: 8080): " porta; checar_esc "$porta"

  ips=()
  while true; do
    read -p "Adicione um IP de backend (ou pressione ENTER para finalizar): " ip
    [[ -z "$ip" ]] && break
    ips+=("$ip")
  done

  echo "✅ ${#ips[@]} IPs adicionados."

  echo "Gerando configuração..."

  echo "http:" > "$CONFIG_DIR/${dominio}_lb.yml"
  echo "  routers:" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "    ${dominio//./_}_lb:" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "      rule: \"Host(\\"$dominio\\")\"" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "      entryPoints:" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "        - websecure" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "      service: ${dominio//./_}_svc" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "      tls:" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "        certResolver: letsencrypt" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "  services:" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "    ${dominio//./_}_svc:" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "      loadBalancer:" >> "$CONFIG_DIR/${dominio}_lb.yml"
  echo "        servers:" >> "$CONFIG_DIR/${dominio}_lb.yml"
  for ip in "${ips[@]}"; do
    echo "          - url: \"http://$ip:$porta\"" >> "$CONFIG_DIR/${dominio}_lb.yml"
  done

  echo "✅ Load Balancer criado para '$dominio'."
}

criar_basicauth() {
  echo -e "
🔐 Criar Basic Auth"
  echo "Protege o acesso ao domínio com login e senha."
  echo "Exemplo: admin:senha123 → domínio protegido"
  pausar_explicacao

  read -p "Digite o domínio: " dominio; checar_esc "$dominio"
  read -p "Digite o usuário: " usuario; checar_esc "$usuario"
  read -s -p "Digite a senha: " senha; echo; checar_esc "$senha"

  hash=
  if command -v htpasswd &>/dev/null; then
    hash=$(htpasswd -nbB "$usuario" "$senha" | sed -e 's/\$/\$\$/g')
  else
    echo "❌ 'htpasswd' não encontrado. Instale via 'apt install apache2-utils'"
    return
  fi

  cat <<EOF > "$CONFIG_DIR/${dominio}_auth.yml"
http:
  routers:
    ${dominio//./_}_auth:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${dominio//./_}_svc
      middlewares:
        - auth
      tls:
        certResolver: letsencrypt
  middlewares:
    auth:
      basicAuth:
        users:
          - "$hash"
  services:
    ${dominio//./_}_svc:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999"
EOF

  echo "✅ Basic Auth configurado para '$dominio'."
}

criar_redirect() {
  echo -e "
➡️ Criar redirecionamento de domínio"
  echo "Redireciona permanentemente de um domínio para outro."
  echo "Exemplo: www.site.com → site.com"
  pausar_explicacao

  read -p "Digite o domínio de origem: " origem; checar_esc "$origem"
  read -p "Digite o domínio de destino: " destino; checar_esc "$destino"

  cat <<EOF > "$CONFIG_DIR/${origem}_redirect.yml"
http:
  routers:
    ${origem//./_}_redir:
      rule: "Host(\"$origem\")"
      entryPoints:
        - websecure
      middlewares:
        - redirect-to-dest
      service: noop@internal
      tls:
        certResolver: letsencrypt
  middlewares:
    redirect-to-dest:
      redirectRegex:
        regex: ".*"
        replacement: "https://$destino"
        permanent: true
EOF

  echo "✅ Redirecionamento criado de '$origem' para '$destino'."
}

criar_ipwhitelist() {
  echo -e "
📋 Criar IP Whitelist"
  echo "Permite acesso ao domínio apenas a IPs autorizados."
  echo "Exemplo: acesso restrito a 192.168.0.0/16 e 10.0.0.1"
  pausar_explicacao

  read -p "Digite o domínio a proteger: " dominio; checar_esc "$dominio"

  ips=()
  while true; do
    read -p "Adicione um IP ou faixa CIDR (ENTER para sair): " ip
    [[ -z "$ip" ]] && break
    ips+=("$ip")
  done

  echo "✅ ${#ips[@]} IPs autorizados."

  cat <<EOF > "$CONFIG_DIR/${dominio}_whitelist.yml"
http:
  routers:
    ${dominio//./_}_wl:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      middlewares:
        - whitelist
      service: ${dominio//./_}_svc
      tls:
        certResolver: letsencrypt
  middlewares:
    whitelist:
      ipWhiteList:
        sourceRange:
$(for ip in "${ips[@]}"; do echo "          - $ip"; done)
  services:
    ${dominio//./_}_svc:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999"
EOF

  echo "✅ IP Whitelist configurada para '$dominio'."
}

criar_ratelimit() {
  echo -e "
⏱️ Criar Rate Limit"
  echo "Limita a quantidade de requisições por IP."
  echo "Exemplo: 10 req/s, burst de 20"
  pausar_explicacao

  read -p "Digite o domínio: " dominio; checar_esc "$dominio"
  read -p "Requisições por segundo: " rate; checar_esc "$rate"
  read -p "Burst (pico): " burst; checar_esc "$burst"

  cat <<EOF > "$CONFIG_DIR/${dominio}_ratelimit.yml"
http:
  routers:
    ${dominio//./_}_rl:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      middlewares:
        - ratelimiter
      service: ${dominio//./_}_svc
      tls:
        certResolver: letsencrypt
  middlewares:
    ratelimiter:
      rateLimit:
        average: $rate
        burst: $burst
  services:
    ${dominio//./_}_svc:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999"
EOF

  echo "✅ Rate Limit aplicada ao domínio '$dominio'."
}

menu_principal() {
  clear
  echo "🚀 Bem-vindo ao ProxySetup"
  echo "Escolha uma opção para criar ou gerenciar uma configuração no Traefik:"
  echo ""
  echo "1) Criar Proxy HTTP"
  echo "2) Criar Proxy TCP"
  echo "3) Criar Proxy UDP"
  echo "4) Criar Load Balancer"
  echo "5) Criar Basic Auth"
  echo "6) Criar Redirecionamento"
  echo "7) Criar IP Whitelist"
  echo "8) Criar Rate Limit"
  echo "9) Criar Middleware CORS"
  echo "10) Criar Headers de Segurança"
  echo "11) Criar Servidor Estático"
  echo "12) Adicionar Subpath"
  echo "13) Remover Configuração"
  echo "0) Sair"

  read -p $'
Digite sua opção: ' opcao
  case "$opcao" in
    1) criar_http ;;
    2) criar_tcp ;;
    3) criar_udp ;;
    4) criar_lb ;;
    5) criar_basicauth ;;
    6) criar_redirect ;;
    7) criar_ipwhitelist ;;
    8) criar_ratelimit ;;
    9) criar_cors ;;
    10) criar_headers_seg ;;
    11) criar_static_files ;;
    12) adicionar_subpath ;;
    13) remover_config ;;
    0) exit 0 ;;
    *) echo "❌ Opção inválida." && sleep 1 && menu_principal ;;
  esac
}

menu_principal
