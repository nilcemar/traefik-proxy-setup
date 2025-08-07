#!/bin/bash

# ==============================================================================
# PROXYSETUP - Script de Automação para Configurações Dinâmicas do Traefik
# Versão: 2.0
# Autor: Nilcemar Ferreira
# Data: 07 de Agosto de 2025
#
# Este script auxilia na criação e gerenciamento de configurações dinâmicas
# para o Traefik (via File Provider), facilitando a exposição de serviços,
# a aplicação de middlewares de segurança e muito mais.
#
# Pré-requisitos:
# - Traefik instalado e configurado para usar o File Provider (diretório /data/traefik/config).
# - Docker instalado e funcionando (para reiniciar o Traefik).
# - 'htpasswd' instalado (apt install apache2-utils ou dnf install httpd-tools) para Basic Auth.
# - As sysctls 'net.ipv4.ip_forward=1' e 'net.ipv4.conf.all.src_valid_mark=1'
#   devem estar ativas no seu HOST (/etc/sysctl.conf ou /etc/sysctl.d/).
# - Os entryPoints (web:80, websecure:443, e quaisquer portas TCP/UDP personalizadas)
#   devem estar definidos no traefik.yml principal e abertos no seu firewall.
# ==============================================================================

CONFIG_DIR="/data/traefik/config"
TRAEFIK_MAIN_CONFIG="/data/traefik/traefik.yml" # Referência ao arquivo de configuração principal
MIDDLEWARES_COMMON_FILE="$CONFIG_DIR/common_middlewares.yml" # Novo arquivo para middlewares comuns

mkdir -p "$CONFIG_DIR"

# Função para garantir que o arquivo de middlewares comuns exista
criar_middlewares_comuns() {
  if [ ! -f "$MIDDLEWARES_COMMON_FILE" ]; then
    echo "🔧 Criando arquivo de middlewares comuns..."
    cat <<EOF > "$MIDDLEWARES_COMMON_FILE"
http:
  middlewares:
    # Middleware para CORS (Cross-Origin Resource Sharing)
    cors:
      headers:
        accessControlAllowOriginList:
          - "*" # Altere conforme suas necessidades de segurança (domínios específicos)
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

    # Middleware para Headers de Segurança HTTP
    secure-headers:
      headers:
        frameDeny: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "no-referrer"
        permissionsPolicy:
          camera=(), microphone=(), geolocation=()
        stsSeconds: 31536000 # HSTS: 1 ano
        stsIncludeSubdomains: true
        stsPreload: true

    # Middleware de exemplo para StripPrefix (pode ser usado como base)
    # Geralmente, é melhor criar StripPrefixes específicos para cada PathPrefix,
    # mas este é um exemplo de como um genérico poderia existir se fosse reutilizado.
    strip-root-path:
      stripPrefix:
        prefixes:
          - /
EOF
    echo "✅ Arquivo de middlewares comuns criado em $MIDDLEWARES_COMMON_FILE."
  fi
}

# Chama a função para garantir que o arquivo de middlewares comuns exista
criar_middlewares_comuns

# ===== UTILITÁRIOS GERAIS =====

# Checa se a tecla ESC foi pressionada para cancelar
checar_esc() {
  if [[ "$1" == $'\e' ]]; then
    echo -e "\n↩️ Cancelado."
    sleep 1
    menu_principal
  fi
}

# Pausa a execução para explicação e permite cancelar
pausar_explicacao() {
  echo -e "\nPressione ENTER para continuar ou ESC para cancelar..."
  read -rsn1 key
  checar_esc "$key"
}

# Valida um domínio
validar_dominio() {
  if [[ -z "$1" ]]; then
    echo "❌ Domínio não pode ser vazio."
    return 1
  fi
  # Regex básico para domínio (não é 100% exaustivo, mas ajuda)
  if ! [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ Formato de domínio inválido."
    return 1
  fi
  return 0
}

# Valida um endereço IP
validar_ip() {
  if [[ -z "$1" ]]; then
    echo "❌ IP não pode ser vazio."
    return 1
  fi
  # Regex para IPv4 simples (não valida faixas inválidas como 999.999.999.999)
  if ! [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "❌ Formato de IP inválido."
    return 1
  fi
  return 0
}

# Valida uma porta
validar_porta() {
  if [[ -z "$1" ]]; then
    echo "❌ Porta não pode ser vazia."
    return 1
  fi
  if ! [[ "$1" =~ ^[0-9]+$ ]] || (( "$1" < 1 )) || (( "$1" > 65535 )); then
    echo "❌ Porta inválida (deve ser um número entre 1 e 65535)."
    return 1
  fi
  return 0
}

# Reinicia o contêiner Traefik
reiniciar_traefik() {
  read -p "Reiniciar Traefik agora? (s/N): " reiniciar_opcao
  if [[ "$reiniciar_opcao" =~ ^[Ss]$ ]]; then
    echo "🔄 Reiniciando Traefik..."
    docker restart traefik &>/dev/null && echo "✅ Traefik reiniciado." || echo "❌ Falha ao reiniciar Traefik."
  fi
}

# Exibe logs do Traefik
ver_logs_traefik() {
  echo -e "\n👀 Últimos logs do Traefik (pressione Ctrl+C para sair):"
  docker logs traefik -f --tail 50
  pausar_explicacao # Para garantir que o usuário veja a mensagem de Ctrl+C
}

# ==============================================================================
# ===== FUNÇÕES DE CRIAÇÃO DE CONFIGURAÇÕES =====

criar_http() {
  echo -e "\n🌐 Criar Proxy HTTP"
  echo "Redireciona um domínio para um IP e porta HTTP. Inclui Let's Encrypt."
  pausar_explicacao

  local dominio ip porta
  while true; do read -p "Digite o domínio (ex: meuapp.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done
  while true; do read -p "Digite o IP de destino (ex: 10.8.0.2): " ip; checar_esc "$ip"; validar_ip "$ip" && break; done
  while true; do read -p "Digite a porta de destino (ex: 80): " porta; checar_esc "$porta"; validar_porta "$porta" && break; done

  local sanitized_dominio="${dominio//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_http.yml"
http:
  routers:
    ${sanitized_dominio}_router:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${sanitized_dominio}_svc
      tls:
        certResolver: letsencrypt
  services:
    ${sanitized_dominio}_svc:
      loadBalancer:
        servers:
          - url: "http://$ip:$porta"
EOF

  echo "✅ Proxy HTTP criado para '$dominio'. Lembre-se de configurar o DNS!"
  reiniciar_traefik
}

criar_tcp() {
  echo -e "\n🔌 Criar Proxy TCP"
  echo "Redireciona conexões TCP para IP:porta. Não usa Let's Encrypt."
  pausar_explicacao

  local dominio porta_entrada ip porta_destino
  while true; do read -p "Digite o domínio (HostSNI, ex: meuapp.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done
  while true; do read -p "Porta de escuta externa (ex: 3306 para MySQL): " porta_entrada; checar_esc "$porta_entrada"; validar_porta "$porta_entrada" && break; done
  while true; do read -p "IP de destino: " ip; checar_esc "$ip"; validar_ip "$ip" && break; done
  while true; do read -p "Porta de destino: " porta_destino; checar_esc "$porta_destino"; validar_porta "$porta_destino" && break; done

  # Lembrar o usuário de adicionar o entryPoint no traefik.yml principal
  echo -e "\n⚠️ Lembre-se de adicionar o seguinte entryPoint ao seu '$TRAEFIK_MAIN_CONFIG' e reiniciar o Traefik manualmentepara o TCP funcionar:\n"
  echo "entryPoints:"
  echo "  tcp_${porta_entrada}:"
  echo "    address: \":${porta_entrada}/tcp\""
  echo ""
  pausar_explicacao # Pausa para o usuário copiar/entender a instrução

  local sanitized_dominio="${dominio//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_tcp_${porta_entrada}.yml"
tcp:
  routers:
    ${sanitized_dominio}_tcp_${porta_entrada}_router:
      rule: "HostSNI(\"$dominio\")"
      entryPoints:
        - tcp_${porta_entrada}
      service: ${sanitized_dominio}_tcp_${porta_entrada}_svc
  services:
    ${sanitized_dominio}_tcp_${porta_entrada}_svc:
      loadBalancer:
        servers:
          - address: "$ip:$porta_destino"
EOF

  echo "✅ Proxy TCP criado para '$dominio' na porta $porta_entrada."
  reiniciar_traefik # Reiniciar Traefik aqui, mas a porta deve estar no traefik.yml
}

criar_udp() {
  echo -e "\n📡 Criar Proxy UDP"
  echo "Redireciona conexões UDP para IP:porta."
  pausar_explicacao

  local nome_servico porta_entrada ip porta_destino
  read -p "Digite um nome para o serviço (ex: wireguard, sem domínio): " nome_servico; checar_esc "$nome_servico"
  while true; do read -p "Porta de escuta externa (ex: 51820 para WireGuard): " porta_entrada; checar_esc "$porta_entrada"; validar_porta "$porta_entrada" && break; done
  while true; do read -p "IP de destino: " ip; checar_esc "$ip"; validar_ip "$ip" && break; done
  while true; do read -p "Porta de destino: " porta_destino; checar_esc "$porta_destino"; validar_porta "$porta_destino" && break; done

  # Lembrar o usuário de adicionar o entryPoint no traefik.yml principal
  echo -e "\n⚠️ Lembre-se de adicionar o seguinte entryPoint ao seu '$TRAEFIK_MAIN_CONFIG' e reiniciar o Traefik manualmentepara o UDP funcionar:\n"
  echo "entryPoints:"
  echo "  udp_${porta_entrada}:"
  echo "    address: \":${porta_entrada}/udp\""
  echo ""
  pausar_explicacao # Pausa para o usuário copiar/entender a instrução

  local sanitized_nome="${nome_servico//[^a-zA-Z0-9]/_}" # Remove caracteres especiais
  cat <<EOF > "$CONFIG_DIR/${sanitized_nome}_udp_${porta_entrada}.yml"
udp:
  routers:
    ${sanitized_nome}_udp_${porta_entrada}_router:
      entryPoints:
        - udp_${porta_entrada}
      service: ${sanitized_nome}_udp_${porta_entrada}_svc
  services:
    ${sanitized_nome}_udp_${porta_entrada}_svc:
      loadBalancer:
        servers:
          - address: "$ip:$porta_destino"
EOF

  echo "✅ Proxy UDP criado para o serviço '$nome_servico' na porta $porta_entrada."
  reiniciar_traefik # Reiniciar Traefik aqui, mas a porta deve estar no traefik.yml
}

criar_lb() {
  echo -e "\n⚖️ Criar Load Balancer"
  echo "Balanceia requisições entre vários IPs para um mesmo domínio."
  pausar_explicacao

  local dominio porta
  while true; do read -p "Digite o domínio (ex: meuapp.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done
  while true; do read -p "Digite a porta de destino dos servidores (ex: 8080): " porta; checar_esc "$porta"; validar_porta "$porta" && break; done

  local ips=()
  while true; do
    local ip_input
    read -p "Adicione um IP de backend (ou pressione ENTER para finalizar): " ip_input; checar_esc "$ip_input"
    if [[ -z "$ip_input" ]]; then break; fi
    if validar_ip "$ip_input"; then
      ips+=("$ip_input")
    else
      echo "❌ IP inválido, tente novamente."
    fi
  done

  if [ ${#ips[@]} -eq 0 ]; then
    echo "❌ Nenhum IP de backend adicionado. Operação cancelada."
    return
  fi

  echo "✅ ${#ips[@]} IPs adicionados."

  local sanitized_dominio="${dominio//./_}"
  echo "http:" > "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "  routers:" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "    ${sanitized_dominio}_lb_router:" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "      rule: \"Host(\\\"$dominio\\\")\"" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "      entryPoints:" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "        - websecure" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "      service: ${sanitized_dominio}_lb_svc" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "      tls:" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "        certResolver: letsencrypt" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "  services:" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "    ${sanitized_dominio}_lb_svc:" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "      loadBalancer:" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  echo "        servers:" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  for ip in "${ips[@]}"; do
    echo "          - url: \"http://$ip:$porta\"" >> "$CONFIG_DIR/${sanitized_dominio}_lb.yml"
  done

  echo "✅ Load Balancer criado para '$dominio'. Lembre-se de configurar o DNS!"
  reiniciar_traefik
}

criar_basicauth() {
  echo -e "\n🔐 Criar Basic Auth"
  echo "Protege o acesso ao domínio com login e senha. Exige 'htpasswd'."
  pausar_explicacao

  local dominio usuario senha hash
  while true; do read -p "Digite o domínio a proteger (ex: seguro.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done
  read -p "Digite o usuário: " usuario; checar_esc "$usuario"
  read -s -p "Digite a senha: " senha; echo; checar_esc "$senha"

  if ! command -v htpasswd &>/dev/null; then
    echo "❌ 'htpasswd' não encontrado. Instale via 'sudo apt install apache2-utils' ou 'sudo dnf install httpd-tools'."
    return
  fi

  hash=$(htpasswd -nbB "$usuario" "$senha" | sed -e 's/\$/\$\$/g')

  local sanitized_dominio="${dominio//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_auth.yml"
http:
  routers:
    ${sanitized_dominio}_auth_router:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${sanitized_dominio}_svc # Serviço dummy para aplicar middleware
      middlewares:
        - basic-auth@file # Referência ao middleware global, se criado, ou localmente definido
      tls:
        certResolver: letsencrypt
  middlewares:
    basic-auth: # Definição local do middleware de Basic Auth
      basicAuth:
        users:
          - "$hash"
  services:
    ${sanitized_dominio}_svc: # Serviço dummy
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999" # Porta arbitrária, o middleware age antes
EOF

  echo "✅ Basic Auth configurado para '$dominio'. Lembre-se de configurar o DNS!"
  reiniciar_traefik
}

criar_redirect() {
  echo -e "\n➡️ Criar redirecionamento de domínio"
  echo "Redireciona permanentemente de um domínio para outro. Inclui Let's Encrypt."
  pausar_explicacao

  local origem destino
  while true; do read -p "Digite o domínio de origem (ex: www.site.com): " origem; checar_esc "$origem"; validar_dominio "$origem" && break; done
  while true; do read -p "Digite o domínio de destino (ex: site.com): " destino; checar_esc "$destino"; validar_dominio "$destino" && break; done

  local sanitized_origem="${origem//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_origem}_redirect.yml"
http:
  routers:
    ${sanitized_origem}_redir_router:
      rule: "Host(\"$origem\")"
      entryPoints:
        - websecure
      middlewares:
        - redirect-to-${sanitized_origem}@file # Middleware definido localmente
      service: noop@internal # Serviço interno do Traefik para redirecionamentos
      tls:
        certResolver: letsencrypt
  middlewares:
    redirect-to-${sanitized_origem}:
      redirectRegex:
        regex: ".*"
        replacement: "https://$destino"
        permanent: true
EOF

  echo "✅ Redirecionamento criado de '$origem' para '$destino'. Lembre-se de configurar o DNS!"
  reiniciar_traefik
}

criar_ipwhitelist() {
  echo -e "\n📋 Criar IP Whitelist"
  echo "Permite acesso ao domínio apenas a IPs autorizados. Inclui Let's Encrypt."
  pausar_explicacao

  local dominio ips=()
  while true; do read -p "Digite o domínio a proteger (ex: admin.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done

  while true; do
    local ip_input
    read -p "Adicione um IP ou faixa CIDR (ex: 192.168.1.0/24, 10.0.0.1) ou ENTER para finalizar: " ip_input; checar_esc "$ip_input"
    if [[ -z "$ip_input" ]]; then break; fi
    # Validação básica de IP/CIDR (pode ser aprimorada)
    if [[ "$ip_input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/([0-9]|[1-2][0-9]|3[0-2]))?$ ]]; then
      ips+=("$ip_input")
    else
      echo "❌ Formato de IP/CIDR inválido, tente novamente."
    fi
  done

  if [ ${#ips[@]} -eq 0 ]; then
    echo "❌ Nenhum IP/CIDR adicionado. Operação cancelada."
    return
  fi

  echo "✅ ${#ips[@]} IPs autorizados."

  local sanitized_dominio="${dominio//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_whitelist.yml"
http:
  routers:
    ${sanitized_dominio}_wl_router:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${sanitized_dominio}_svc # Serviço dummy
      middlewares:
        - ip-whitelist-${sanitized_dominio}@file # Middleware definido localmente
      tls:
        certResolver: letsencrypt
  middlewares:
    ip-whitelist-${sanitized_dominio}: # Definição local do middleware IP Whitelist
      ipWhiteList:
        sourceRange:
$(for ip in "${ips[@]}"; do echo "          - $ip"; done)
  services:
    ${sanitized_dominio}_svc: # Serviço dummy
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999" # Porta arbitrária
EOF

  echo "✅ IP Whitelist configurada para '$dominio'. Lembre-se de configurar o DNS!"
  reiniciar_traefik
}

criar_ratelimit() {
  echo -e "\n⏱️ Criar Rate Limit"
  echo "Limita a quantidade de requisições por IP. Inclui Let's Encrypt."
  pausar_explicacao

  local dominio rate burst
  while true; do read -p "Digite o domínio a proteger (ex: api.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done
  while true; do read -p "Requisições por segundo (average): " rate; checar_esc "$rate"; [[ "$rate" =~ ^[0-9]+$ ]] && break; echo "❌ Digite um número válido."; done
  while true; do read -p "Burst (pico de requisições): " burst; checar_esc "$burst"; [[ "$burst" =~ ^[0-9]+$ ]] && break; echo "❌ Digite um número válido."; done

  local sanitized_dominio="${dominio//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_ratelimit.yml"
http:
  routers:
    ${sanitized_dominio}_rl_router:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${sanitized_dominio}_svc # Serviço dummy
      middlewares:
        - rate-limiter-${sanitized_dominio}@file # Middleware definido localmente
      tls:
        certResolver: letsencrypt
  middlewares:
    rate-limiter-${sanitized_dominio}: # Definição local do middleware Rate Limit
      rateLimit:
        average: $rate
        burst: $burst
  services:
    ${sanitized_dominio}_svc: # Serviço dummy
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999" # Porta arbitrária
EOF

  echo "✅ Rate Limit aplicada ao domínio '$dominio'. Lembre-se de configurar o DNS!"
  reiniciar_traefik
}

criar_cors() {
  echo -e "\n🌍 Criar middleware CORS"
  echo "Permite requisições entre origens diferentes. Aplicado a um domínio específico."
  pausar_explicacao

  local dominio
  while true; do read -p "Digite o domínio que usará CORS (ex: api.meuapp.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done

  local sanitized_dominio="${dominio//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_cors.yml"
http:
  routers:
    ${sanitized_dominio}_cors_router:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${sanitized_dominio}_svc # Serviço dummy para aplicar middleware
      middlewares:
        - cors@file # Usando o middleware global (common_middlewares.yml)
      tls:
        certResolver: letsencrypt
  services:
    ${sanitized_dominio}_svc: # Serviço dummy
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999" # Porta arbitrária
EOF

  echo "✅ Middleware CORS configurado para '$dominio'. Lembre-se de configurar o DNS!"
  reiniciar_traefik
}

criar_headers_seg() {
  echo -e "\n🛡️ Criar Headers de Segurança"
  echo "Adiciona cabeçalhos HTTP seguros (HSTS, XSS-Protection, etc). Aplicado a um domínio específico."
  pausar_explicacao

  local dominio
  while true; do read -p "Digite o domínio a proteger (ex: meuseguro.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done

  local sanitized_dominio="${dominio//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_headers.yml"
http:
  routers:
    ${sanitized_dominio}_headers_router:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${sanitized_dominio}_svc # Serviço dummy
      middlewares:
        - secure-headers@file # Usando o middleware global (common_middlewares.yml)
      tls:
        certResolver: letsencrypt
  services:
    ${sanitized_dominio}_svc: # Serviço dummy
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9999" # Porta arbitrária
EOF

  echo "✅ Headers de segurança configurados para '$dominio'. Lembre-se de configurar o DNS!"
  reiniciar_traefik
}

criar_static_files() {
  echo -e "\n🗂️ Criar servidor de arquivos estáticos"
  echo "Serve arquivos diretamente de uma pasta no host. Inclui Let's Encrypt."
  pausar_explicacao

  local dominio caminho
  while true; do read -p "Digite o domínio (ex: meuweb.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done
  read -p "Caminho ABSOLUTO da pasta com os arquivos no HOST (ex: /data/www/meusite): " caminho; checar_esc "$caminho"

  echo -e "\n⚠️ Para o servidor estático funcionar, você DEVE montar o caminho '$caminho'"
  echo "   como um volume dentro do contêiner Traefik no seu docker-compose.yml."
  echo "   Exemplo: - '$caminho:/web_root'"
  pausar_explicacao

  local sanitized_dominio="${dominio//./_}"
  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_static.yml"
http:
  routers:
    ${sanitized_dominio}_static_router:
      rule: "Host(\"$dominio\")"
      entryPoints:
        - websecure
      service: ${sanitized_dominio}_static_svc
      tls:
        certResolver: letsencrypt
      middlewares:
        - static-stripprefix-${sanitized_dominio}@file # Middleware para remover prefixo se o backend espera '/'
  services:
    ${sanitized_dominio}_static_svc:
      file:
        directory: "$caminho" # O Traefik serve arquivos diretamente deste diretório (que deve ser um volume montado)
        # enableSymlinks: true # Descomente se precisar de symlinks
  middlewares:
    static-stripprefix-${sanitized_dominio}:
      stripPrefix:
        prefixes:
          - / # Remove o path base, útil para servir diretamente a partir da raiz do volume
EOF

  echo "✅ Servidor estático configurado para '$dominio'."
  reiniciar_traefik
}


adicionar_subpath() {
  echo -e "\n📁 Adicionar subcaminho a domínio"
  echo "Permite redirecionar um subpath (/painel) para outro serviço e remover o prefixo."
  pausar_explicacao

  local dominio subpath ip porta
  while true; do read -p "Digite o domínio base (ex: meuapp.com): " dominio; checar_esc "$dominio"; validar_dominio "$dominio" && break; done
  read -p "Digite o subcaminho (ex: /painel - inclua a barra inicial): " subpath; checar_esc "$subpath"
  while true; do read -p "IP do destino (ex: 10.8.0.3): " ip; checar_esc "$ip"; validar_ip "$ip" && break; done
  while true; do read -p "Porta do destino (ex: 3000): " porta; checar_esc "$porta"; validar_porta "$porta" && break; done

  local sanitized_dominio="${dominio//./_}"
  local path_clean=$(echo "$subpath" | sed 's/^\///') # Remove a barra inicial para nome do arquivo/middleware
  local router_name="${sanitized_dominio}_${path_clean}_router"
  local service_name="${sanitized_dominio}_${path_clean}_svc"
  local middleware_name="${sanitized_dominio}_${path_clean}_stripprefix" # Nome único para o middleware

  cat <<EOF > "$CONFIG_DIR/${sanitized_dominio}_${path_clean}.yml"
http:
  routers:
    ${router_name}:
      rule: "Host(\"$dominio\") && PathPrefix(\"$subpath\")"
      entryPoints:
        - websecure
      service: ${service_name}
      tls:
        certResolver: letsencrypt
      middlewares:
        - ${middleware_name}@file # Referência ao middleware definido localmente
      priority: 100 # <--- Alta prioridade para roteadores de subpath

  services:
    ${service_name}:
      loadBalancer:
        servers:
          - url: "http://$ip:$porta"

  middlewares: # Definição local do middleware para este subpath
    ${middleware_name}:
      stripPrefix:
        prefixes:
          - "$subpath" # Remove o prefixo "/painel" da URL antes de enviar ao backend
EOF

  echo "✅ Subcaminho '$subpath' criado no domínio '$dominio'."
  reiniciar_traefik
}

remover_config() {
  echo -e "\n🧹 Remover configuração"
  echo "Permite excluir qualquer arquivo de configuração criado."
  echo "Use com cuidado. As alterações são imediatas."
  pausar_explicacao

  echo "Arquivos encontrados em $CONFIG_DIR:"
  ls -l "$CONFIG_DIR" | awk '{print $9}' | grep -E '\.yml$|\.toml$'

  read -p "Digite o nome exato do arquivo a remover (ex: meuapp_http.yml): " arquivo; checar_esc "$arquivo"

  if [[ -f "$CONFIG_DIR/$arquivo" ]]; then
    rm "$CONFIG_DIR/$arquivo" && echo "✅ Arquivo '$arquivo' removido." || echo "❌ Erro ao remover '$arquivo'."
  else
    echo "❌ Arquivo '$arquivo' não encontrado em '$CONFIG_DIR'."
  fi
  reiniciar_traefik
}

# ==============================================================================
# ===== MENU PRINCIPAL =====

menu_principal() {
  clear
  echo "🚀 Bem-vindo ao ProxySetup (Traefik Automation Script)"
  echo "Gerencie suas configurações dinâmicas do Traefik de forma fácil."
  echo ""
  echo "   --- Ações Comuns ---"
  echo "1) Criar Proxy HTTP (Domínio -> IP:Porta)"
  echo "2) Adicionar Subpath (Domínio/subpath -> IP:Porta)"
  echo "3) Criar Load Balancer (Domínio -> Múltiplos IPs:Porta)"
  echo ""
  echo "   --- Redes e Protocolos ---"
  echo "4) Criar Proxy TCP (Domínio Porta -> IP:Porta)"
  echo "5) Criar Proxy UDP (Nome Serviço Porta -> IP:Porta)"
  echo "6) Criar Servidor de Arquivos Estáticos (Domínio -> Pasta no Host)"
  echo ""
  echo "   --- Segurança e Middlewares ---"
  echo "7) Criar Basic Auth (Domínio com Login/Senha)"
  echo "8) Criar IP Whitelist (Domínio com Restrição de IPs)"
  echo "9) Criar Rate Limit (Domínio com Limite de Requisições)"
  echo "10) Adicionar CORS a Domínio (Habilita CORS)"
  echo "11) Adicionar Headers de Segurança a Domínio"
  echo "12) Criar Redirecionamento (Domínio Antigo -> Domínio Novo)"
  echo ""
  echo "   --- Manutenção ---"
  echo "13) Remover Configuração (Exclui arquivo .yml)"
  echo "14) Ver Logs do Traefik"
  echo "15) Reiniciar Traefik"
  echo "0) Sair"

  read -p $'\nDigite sua opção: ' opcao
  case "$opcao" in
    1) criar_http ;;
    2) adicionar_subpath ;; # Movido para cima por ser comum
    3) criar_lb ;;
    4) criar_tcp ;;
    5) criar_udp ;;
    6) criar_static_files ;;
    7) criar_basicauth ;;
    8) criar_ipwhitelist ;;
    9) criar_ratelimit ;;
    10) criar_cors ;;
    11) criar_headers_seg ;;
    12) criar_redirect ;;
    13) remover_config ;;
    14) ver_logs_traefik ;;
    15) reiniciar_traefik ;;
    0) exit 0 ;;
    *) echo "❌ Opção inválida. Tente novamente." && sleep 1 && menu_principal ;;
  esac
}

# Inicia o menu principal
menu_principal