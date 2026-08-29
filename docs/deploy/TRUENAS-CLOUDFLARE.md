# Acesso externo com Cloudflare Tunnel (conceitual)

Cloudflare é **infraestrutura** — nunca fica acoplado ao código da aplicação. O container
sempre escuta uma porta HTTP simples; quem decide "isso é `https://app.exemplo.com.br`" é o
Cloudflare Tunnel, configurado fora deste repositório.

## Conceito

```
{{DOMAIN_WEB}}
  ↓
Cloudflare Tunnel
  ↓
web:3000   (rede Docker interna do projeto)


{{DOMAIN_API}}
  ↓
Cloudflare Tunnel
  ↓
api:3001   (rede Docker interna do projeto)
```

O Cloudflare Tunnel (`cloudflared`) roda como mais um container na mesma rede Docker do
projeto (ou como serviço do host), e mapeia cada hostname público para o serviço interno
correspondente pelo **nome do serviço**, nunca por IP.

Isso funciona mesmo quando a API não publica porta no host (`-PublicApi` desligado, `expose:`
em vez de `ports:` — ver `DEPLOY-STANDARD.md#portas-e-exposição-da-api`): o `cloudflared`
conversa com `api:3001` pela rede Docker interna, não pela porta do host. `-PublicApi`
e "a API está acessível pela internet via Cloudflare" são coisas independentes — publicar no
host é só necessário para acesso direto por IP:porta (fora do Tunnel/reverse proxy).

## Por que isso importa

- A aplicação nunca lida com certificado TLS — quem termina HTTPS é a borda do Cloudflare.
- Não é preciso abrir porta nenhuma no roteador/firewall do TrueNAS — o Tunnel é uma conexão
  de saída, iniciada pelo `cloudflared`.
- Trocar Cloudflare por outro reverse proxy (Nginx, Traefik, um load balancer de nuvem) no
  futuro não exige mudar nada dentro do container — só a camada de roteamento externo.

## Configuração (alto nível)

1. Criar o Tunnel no painel/CLI do Cloudflare (`cloudflared tunnel create {{PROJECT_SLUG}}`).
2. Mapear os hostnames públicos para os serviços internos:
   - `{{DOMAIN_WEB}}` → `http://web:3000`
   - `{{DOMAIN_API}}` → `http://api:3001`
3. Rodar `cloudflared` apontando para o arquivo de configuração do Tunnel, na mesma rede Docker
   (`{{PROJECT_SLUG}}-network`) dos serviços `web`/`api`.
4. O token/credencial do Tunnel é um secret — fica em variável de ambiente do host ou num
   secret do orquestrador, **nunca** neste repositório.

Este arquivo é intencionalmente conceitual (sem token, sem domínio real, sem IP) — o
passo a passo exato de configuração do Cloudflare Tunnel muda com a versão da ferramenta;
consulte a documentação oficial do Cloudflare no momento da configuração.

## Regra

A aplicação deve continuar funcionando (em `http://localhost:3000`, por exemplo) mesmo que o
Cloudflare Tunnel esteja completamente fora do ar — Cloudflare é como o tráfego chega até a
aplicação, não uma dependência da aplicação em si.

## Ver também

- [`TRUENAS.md`](./TRUENAS.md)
- [`../../SECURITY-STANDARD.md`](../../SECURITY-STANDARD.md)
