# 🧰 ProxySetup – Utilitário Completo para Gerenciar Traefik via Terminal

**ProxySetup** é um script interativo em Bash que facilita a criação, edição e remoção de configurações para o [Traefik](https://traefik.io/), servindo como uma GUI de linha de comando altamente funcional.

Ideal para sysadmins, devops e entusiastas que desejam configurar rapidamente **proxies, middlewares e serviços** com Traefik — tudo via um menu intuitivo, com exemplos e ajuda embutida.

---

## ✨ Funcionalidades

✔️ Criação de proxies reversos para HTTP, TCP e UDP  
✔️ Redirecionamento de domínios  
✔️ Criação de subcaminhos (ex: `/painel`)  
✔️ Load Balancer com múltiplos servidores  
✔️ Autenticação básica (BasicAuth) com hash seguro  
✔️ CORS, Headers de segurança, Rate Limiting e IP Whitelist  
✔️ Servidores estáticos para sites HTML  
✔️ Interface interativa e explicativa  
✔️ Cancelamento com `<Esc>` em qualquer etapa

---

## 🧾 Requisitos

- **Traefik** rodando em Docker ou host, com configuração dinâmica por arquivos habilitada
- Linux ou macOS com `bash`, `awk`, `sed`, `htpasswd` (Apache utils)
- Volume configurado para: `/data/traefik/config/`

---

## 🚀 Como usar

1. Dê permissão de execução:

   ```bash
   chmod +x proxysetup.sh
   ```

2. Execute o script:

   ```bash
   ./proxysetup.sh
   ```

3. Siga o menu interativo!

---

## 📂 Exemplo de criação de Proxy HTTP

1. Escolha a opção `1) Criar Proxy HTTP`
2. Informe o domínio: `app.empresa.com`
3. IP do destino: `172.72.72.10`
4. Porta do serviço: `8080`  
   ➡️ Será gerado o arquivo:  
   `/data/traefik/config/app.empresa.com_http.yml`

O Traefik aplicará automaticamente a nova rota (hot-reload) se estiver com `providers.file.directory` apontando corretamente.

---

## 🧱 Estrutura recomendada de volumes (Docker)

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
  - /data/traefik/traefik.yml:/traefik.yml:ro
  - /data/traefik/acme.json:/acme.json
  - /data/traefik/config:/config
```

---

## 📖 Recursos implementados

- [x] Proxy HTTP
- [x] Proxy TCP
- [x] Proxy UDP
- [x] Load Balancer
- [x] Basic Auth (com hash seguro)
- [x] Redirecionamento de domínio
- [x] IP Whitelist
- [x] Rate Limit
- [x] CORS (Cross-Origin Resource Sharing)
- [x] Headers de segurança (HSTS, XSS)
- [x] Servidores estáticos
- [x] Subpaths (ex: `/painel`)
- [x] Remoção de configurações existentes

---

## ❤️ Apoie este projeto

Se este projeto te ajudou, considere fazer uma doação para apoiar seu desenvolvimento contínuo:

**👉 [Doar via PayPal](https://www.paypal.com/donate/?business=nilcemar@gmail.com)**  
ou envie diretamente para: `nilcemar@gmail.com`

---

## 📝 Licença

Este projeto está licenciado sob a licença MIT.  
Sinta-se livre para usar, modificar e compartilhar.

---

## 🤝 Contribua

Pull Requests são bem-vindos!  
Sugestões, melhorias e ideias para novos recursos são encorajadas.

---
