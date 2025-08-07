# 🚀 ProxySetup v2.0 - Traefik Automation Script 🎩

Olá! 👋 Bem-vindo ao **ProxySetup**, seu canivete suíço para gerenciar o Traefik diretamente do terminal! 🎉 Este script é a sua "GUI de linha de comando" para configurar proxies reversos, middlewares e serviços de forma super fácil e rápida. É especialmente útil para quem lida com **roteamento para serviços em redes isoladas, como clientes VPN (WireGuard)**.

Diga adeus à edição manual de YAML e olá à automação inteligente! ✨

---

### ✨ **Funcionalidades Mágicas (e Úteis! 😉)**

- **Proxies Reversos Instantâneos:** 🌐 Configure roteadores HTTP (com Let's Encrypt gratuito! 🔒), TCP e UDP em segundos.
- **Redirecionamentos Inteligentes:** ➡️ Desvie o tráfego de um domínio antigo para um novo de forma permanente.
- **Subpaths Dinâmicos:** 📁 Direcione partes da sua URL (ex: `<seudominio.com>/painel`) para serviços diferentes, com remoção automática do prefixo.
- **Load Balancing Simples:** ⚖️ Distribua requisições entre vários servidores para garantir alta disponibilidade.
- **Segurança Robusta:** 🛡️
  - **Basic Auth:** Proteja áreas com login e senha.
  - **IP Whitelist:** Permita acesso apenas para IPs específicos.
  - **Rate Limit:** Controle o fluxo de requisições para evitar abusos.
  - **Headers de Segurança:** Adicione camadas extras de proteção HTTP (HSTS, XSS-Protection).
  - **CORS:** Habilite o Cross-Origin Resource Sharing para suas APIs sem dor de cabeça.
- **Servidor de Arquivos Estáticos:** 🗂️ Sirva sites HTML/CSS/JS diretamente de uma pasta no seu servidor.
- **Interface Amigável:** 🗣️ Um menu intuitivo com explicações claras e a opção de cancelar a qualquer momento (pressionando `<Esc>`).
- **Modularidade Total:** 🧩 As configurações são geradas em arquivos YAML organizados que o Traefik detecta e aplica automaticamente.
- **Manutenção Rápida:** 🛠️ Opções para ver os logs do Traefik e reiniciar o contêiner em um clique.

---

### ⚙️ **O Que Você Precisa Ter (Pré-requisitos)**

Para que o ProxySetup funcione como mágica, certifique-se de ter:

- **Traefik em Docker:** 🐳 Rodando e configurado para usar o **File Provider** com o diretório `/data/traefik/config/` montado.
  - Exemplo no seu `docker-compose.yml` do Traefik:
    ```yaml
    # services:
    #   traefik:
    #     volumes:
    #       - /data/traefik/config:/data/traefik/config # 👈 ESSENCIAL!
    #       # ...
    #     command:
    #       - --providers.file.directory=/data/traefik/config/ # 👈 Não se esqueça!
    #       - --providers.file.watch=true # 👈 Traefik "escuta" mudanças!
    ```
- **Docker Compose:** 📜 Seu orquestrador de contêineres favorito!
- **Ambiente Linux/macOS:** 💻 O script é um shell script Bash e requer `awk`, `sed` e `grep` instalados (quase sempre já vêm).
- **`htpasswd`:** Necessário para a função de Basic Auth.
  - **Debian/Ubuntu:** `sudo apt install apache2-utils`
  - **CentOS/RHEL/Fedora:** `sudo dnf install httpd-tools` (ou `yum install httpd-tools`)
- **Configurações do Kernel (Crucial para VPNs! 🐧):**
  As seguintes `sysctls` devem estar ativas no seu **HOST VPS** e persistir após reinicializações. Isso é crucial para que o Traefik possa rotear para IPs de redes VPN (como `10.8.0.x` do WireGuard). Adicione-as em `/etc/sysctl.conf` ou crie um novo arquivo como `/etc/sysctl.d/99-custom-network.conf` e aplique com `sudo sysctl -p`:
  ```ini
  net.ipv4.ip_forward = 1
  net.ipv4.conf.all.src_valid_mark = 1
  ```
- **EntryPoints do Traefik e Regras de Firewall:** 🔥 As portas que o Traefik escutará (80 para HTTP, 443 para HTTPS, e quaisquer portas TCP/UDP personalizadas que você criar) devem estar:
  1.  Definidas no seu `traefik.yml` principal (arquivo estático).
  2.  Abertas no firewall do seu VPS (ex: UFW, FirewallD).
  3.  Abertas no firewall do seu provedor de nuvem (ex: Oracle Cloud Security List, AWS Security Groups).
  - Exemplo de `entryPoints` em `traefik.yml`:
    ```yaml
    entryPoints:
      web:
        address: ":80"
        http:
          redirections:
            entryPoint:
              to: websecure
              scheme: https
      websecure:
        address: ":443"
      # Adicione aqui entryPoints para TCP e UDP conforme necessário.
      # O script te lembrará! 😉
      # tcp_3306:
      #   address: ":3306/tcp"
      # udp_51820:
      #   address: ":51820/udp"
    ```

---

### 🚀 **Como Começar (É Fácil!)**

1.  **Clone o Repositório:**
    ```bash
    git clone [https://github.com/nilcemar/traefik-proxy-setup.git](https://github.com/nilcemar/traefik-proxy-setup.git)
    cd traefik-proxy-setup
    ```
2.  **Atualize o Script:** Certifique-se de que seu `proxysetup.sh` (ou o nome do seu script principal) esteja com a versão mais recente.
3.  **Dê Permissões Mágicas de Execução:**
    ```bash
    chmod +x proxysetup.sh
    ```
4.  **Execute o Script:**

    ```bash
    ./proxysetup.sh
    ```

    Um menu interativo aparecerá. Siga as instruções! ✨

5.  **Crie suas Configurações:** O script gerará arquivos YAML na pasta `/data/traefik/config/`.

    - **Exemplo: Criando um Proxy HTTP**
      Se você escolher a opção `1) Criar Proxy HTTP`, o script pedirá o domínio e o IP/Porta de destino.
      - **Entrada:**
        ```
        Digite o domínio (ex: meuapp.com): meuapp.<seudominio.com>
        Digite o IP de destino (ex: 10.8.0.2): 10.8.0.5
        Digite a porta de destino (ex: 80): 8080
        ```
      - **Saída (arquivo gerado em `/data/traefik/config/meuapp_seudominio_com_http.yml`):**
        `` yaml
    # meuapp_seudominio_com_http.yml
    http:
      routers:
        meuapp_seudominio_com_router:
          rule: "Host(`myapp.<seudominio.com>`)"
          entryPoints:
            - websecure
          service: meuapp_seudominio_com_svc
          tls:
            certResolver: letsencrypt
      services:
        meuapp_seudominio_com_svc:
          loadBalancer:
            servers:
              - url: "[http://10.8.0.5:8080](http://10.8.0.5:8080)"
     ``
        O Traefik, ao detectar este novo arquivo, automaticamente configurará o roteamento e emitirá um certificado Let's Encrypt (se configurado)! 🔒

6.  **Reinicie o Traefik:** Após cada operação, o script perguntará se você quer reiniciar o contêiner `traefik`. É super recomendado para aplicar as mudanças na hora! 🔄

---

### 💡 **Observações Finais Importantes**

- **Servidor de Arquivos Estáticos:** Para que a mágica do servidor de arquivos estáticos aconteça, você **DEVE** montar a pasta do seu host (com os arquivos HTML/CSS/JS) como um volume dentro do contêiner Traefik no seu `docker-compose.yml`. Exemplo:
  ```yaml
  # No docker-compose.yml do Traefik
  services:
    traefik:
      volumes:
        - /data/traefik/config:/data/traefik/config
        - /caminho/do/seu/site/no/host:/web_root # 👈 E.g., mount your static files!
  ```
  No script, ao criar o servidor estático, você apontaria para `/web_root` (o caminho dentro do contêiner).
- **Logs do Traefik:** Use a opção `14) Ver Logs do Traefik` no menu. É seu melhor amigo para monitorar e depurar! 🕵️‍♀️

---

### 🙏 **Apoie o Projeto!**

Se este script te ajudou a simplificar sua vida e economizar tempo, considere uma pequena doação! Cada contribuição me motiva a continuar melhorando e adicionando novas funcionalidades. Muito obrigado! ❤️

- **PayPal:** [https://www.paypal.com/donate/?business=nilcemar@gmail.com](https://www.paypal.com/donate/?business=nilcemar@gmail.com)
- **PIX (Chave Aleatória):** `2ac01b86-a915-4bf8-999b-b6070567686d`

---

### 🤝 **Contribuição e Feedback**

Sugestões, Pull Requests e novas ideias são mais do que bem-vindas! Se você encontrou um bug ou tem uma funcionalidade em mente, por favor, abra uma `Issue` ou envie um `Pull Request`. Vamos construir juntos! 🚀

---

### 📄 **Licença**

Este projeto está licenciado sob a [Licença MIT](LICENSE).

---

---

# 🇺🇸 **English Version**

---

Hi there! 👋 Welcome to **ProxySetup**, your all-in-one terminal Swiss Army Knife for managing Traefik! 🎩 This script is your "command-line GUI" to effortlessly configure reverse proxies, middlewares, and services. It's especially handy for anyone dealing with **routing to services in isolated networks, such as WireGuard VPN clients**.

Say goodbye to manual YAML editing and hello to smart automation! ✨

---

### ✨ **Key (and Handy!) Features**

- **Instant Reverse Proxies:** 🌐 Set up HTTP (with free Let's Encrypt! 🔒), TCP, and UDP routers in seconds.
- **Smart Redirects:** ➡️ Permanently redirect traffic from an old domain to a new one.
- **Dynamic Subpaths:** 📁 Route specific URL paths (e.g., `<yourdomain.com>/panel`) to different services, with automatic prefix stripping.
- **Simple Load Balancing:** ⚖️ Distribute requests across multiple backend servers for high availability.
- **Robust Security:** 🛡️
  - **Basic Auth:** Protect areas with username/password authentication.
  - **IP Whitelist:** Restrict domain access to authorized IPs only.
  - **Rate Limit:** Control request traffic to prevent abuse.
  - **Security Headers:** Add extra HTTP security layers (HSTS, XSS-Protection, Frame-Deny).
  - **CORS:** Enable Cross-Origin Resource Sharing for your APIs without the headache.
- **Static File Server:** 🗂️ Serve HTML/CSS/JS websites directly from a folder on your host.
- **Friendly Interface:** 🗣️ An intuitive menu with clear explanations and the option to cancel at any time (by pressing `<Esc>`).
- **Full Modularity:** 🧩 Configurations are generated in organized YAML files that Traefik automatically detects and applies.
- **Quick Maintenance:** 🛠️ Options to view Traefik logs and restart the container with a single click.

---

### ⚙️ **What You'll Need (Prerequisites)**

For ProxySetup to work its magic, please ensure your environment meets the following prerequisites:

- **Traefik in Docker:** 🐳 Running and configured to use the **File Provider** with the `/data/traefik/config/` directory mounted.
  - Example Traefik `docker-compose.yml` configuration:
    ```yaml
    # services:
    #   traefik:
    #     volumes:
    #       - /data/traefik/config:/data/traefik/config # 👈 ESSENTIAL!
    #       # ...
    #     command:
    #       - --providers.file.directory=/data/traefik/config/ # 👈 Don't forget!
    #       - --providers.file.watch=true # 👈 Traefik "listens" for changes!
    ```
- **Docker Compose:** 📜 Your favorite container orchestrator!
- **Linux/macOS Environment:** 💻 The script is a Bash shell script and requires `awk`, `sed`, and `grep` installed (usually come by default).
- **`htpasswd`:** Needed for the Basic Auth functionality. Install it with:
  - **Debian/Ubuntu:** `sudo apt install apache2-utils`
  - **CentOS/RHEL/Fedora:** `sudo dnf install httpd-tools` (or `yum install httpd-tools`)
- **Kernel Configurations (Crucial for VPNs! 🐧):**
  The following `sysctls` must be active on your **VPS HOST** and persist after reboots. This is critical for Traefik to route to VPN network IPs (like WireGuard's `10.8.0.x`). Add them to `/etc/sysctl.conf` or create a new file like `/etc/sysctl.d/99-custom-network.conf` and apply with `sudo sysctl -p`:
  ```ini
  net.ipv4.ip_forward = 1
  net.ipv4.conf.all.src_valid_mark = 1
  ```
- **Traefik EntryPoints and Firewall Rules:** 🔥 The ports Traefik will listen on (80 for HTTP, 443 for HTTPS, and any custom TCP/UDP ports you create) must be:
  1.  Defined in your main `traefik.yml` (static configuration file).
  2.  Open in your VPS's firewall (e.g., UFW, FirewallD).
  3.  Open in your cloud provider's firewall (e.g., Oracle Cloud Security List, AWS Security Groups).
  - Example `entryPoints` in `traefik.yml`:
    ```yaml
    entryPoints:
      web:
        address: ":80"
        http:
          redirections:
            entryPoint:
              to: websecure
              scheme: https
      websecure:
        address: ":443"
      # Add entryPoints here for TCP and UDP as needed.
      # The script will remind you! 😉
      # tcp_3306:
      #   address: ":3306/tcp"
      # udp_51820:
      #   address: ":51820/udp"
    ```

---

### 🚀 **How to Get Started (It's Easy!)**

1.  **Clone the Repository:**
    ```bash
    git clone [https://github.com/nilcemar/traefik-proxy-setup.git](https://github.com/nilcemar/traefik-proxy-setup.git)
    cd traefik-proxy-setup
    ```
2.  **Update the Script:** Make sure your `proxysetup.sh` (or your main script file name) is up-to-date with the latest version.
3.  **Grant Magic Execution Permissions:**
    ```bash
    chmod +x proxysetup.sh
    ```
4.  **Run the Script:**

    ```bash
    ./proxysetup.sh
    ```

    An interactive menu will appear. Just follow the prompts! ✨

5.  **Create Your Configurations:** The script will generate YAML files in the `/data/traefik/config/` folder.

    - **Example: Creating an HTTP Proxy**
      If you choose option `1) Criar Proxy HTTP` (Create HTTP Proxy), the script will ask for the domain and target IP/Port.
      - **Input:**
        ```
        Enter the domain (e.g., myapp.com): myapp.<yourdomain.com>
        Enter the destination IP (e.g., 10.8.0.2): 10.8.0.5
        Enter the destination port (e.g., 80): 8080
        ```
      - **Output (generated file in `/data/traefik/config/myapp_yourdomain_com_http.yml`):**
        `` yaml
    # myapp_yourdomain_com_http.yml
    http:
      routers:
        myapp_yourdomain_com_router:
          rule: "Host(`myapp.<yourdomain.com>`)"
          entryPoints:
            - websecure
          service: myapp_yourdomain_com_svc
          tls:
            certResolver: letsencrypt
      services:
        myapp_yourdomain_com_svc:
          loadBalancer:
            servers:
              - url: "[http://10.8.0.5:8080](http://10.8.0.5:8080)"
     ``
        Traefik, upon detecting this new file, will automatically configure the routing and issue a Let's Encrypt certificate (if configured)! 🔒

6.  **Restart Traefik:** After each creation/removal operation, the script will ask if you want to restart the `traefik` container. It's highly recommended to do so for changes to apply instantly! 🔄

---

### 💡 **Important Notes**

- **Static File Server:** For the static file server magic to work, you **MUST** mount the host folder containing your HTML/CSS/JS files as a volume inside the Traefik container in your `docker-compose.yml`. Example:
  ```yaml
  # In Traefik's docker-compose.yml
  services:
    traefik:
      volumes:
        - /data/traefik/config:/data/traefik/config
        - /path/to/your/site/on/host:/web_root # 👈 E.g., mount your static files!
  ```
  When creating the static server via the script, you would then point to `/web_root` (the path inside the container).
- **Traefik Logs:** Use option `14) Ver Logs do Traefik` (View Traefik Logs) in the menu. It's your best friend for monitoring and debugging! 🕵️‍♀️

---

### 🙏 **Support the Project!**

If this script helped you simplify your life and save time, please consider a small donation! Every contribution motivates me to keep improving and adding new features. Thank you so much! ❤️

- **PayPal:** [https://www.paypal.com/donate/?business=nilcemar@gmail.com](https://www.paypal.com/donate/?business=nilcemar@gmail.com)
- **PIX (Random Key):** `2ac01b86-a915-4bf8-999b-b6070567686d`

---

### 🤝 **Contribution & Feedback**

Suggestions, Pull Requests, and new ideas are more than welcome! If you've found a bug or have a feature in mind, please feel free to open an `Issue` or send a `Pull Request`. Let's build together! 🚀

---

### 📄 **License**

This project is licensed under the [MIT License](LICENSE).

---
