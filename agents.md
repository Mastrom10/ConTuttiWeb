# agents.md — Guía para agentes de IA

> **Obligatorio:** al iniciar cualquier tarea en este repositorio, leé **`memory.md`** primero y actualizalo al final si cambió algo relevante (infraestructura, decisiones, estado de despliegue, pendientes).

## Qué es este proyecto

Sitio web de **Con Tutti Pizza Party** (`contuttipizzaparty.com`): landing page en español para reservas de catering de pizza party. Repo privado; las credenciales de AWS y Resend viven en archivos del proyecto (decisión explícita del dueño).

## Objetivo de arquitectura (actual — desplegado)

```
Visitante → CloudFront (HTTPS) → S3 (sitio estático)
                ↓
         Formulario POST
                ↓
    API Gateway → Lambda → Resend → contuttipizzaparty@gmail.com
```

- **Sitio en producción:** https://contuttipizzaparty.com
- **Deploy:** `./scripts/deploy.sh`
- **Estado:** ver `memory.md` e `infra/deployment.env`

## Estructura del repositorio

```
ConTuttiWeb/
├── index.html              # Landing principal
├── politicadeprivacidad.html
├── styles.css
├── js/main.js              # Formulario → API Gateway
├── js/config.js            # URL del API (actualizada en deploy)
├── images/                 # Assets del sitio
├── infra/                  # Lambda + deployment.env
├── scripts/deploy.sh       # Despliegue AWS
├── aws/                    # Perfil AWS CLI `contutti`
├── .env.aws                # Credenciales AWS
├── .env.resend             # Credenciales y config Resend
├── .cursor/mcp.json        # MCP: AWS + Resend
├── .venv/                  # Python venv para AWS MCP (gitignored)
├── agents.md               # Este archivo
└── memory.md               # Estado vivo del proyecto
```

## Stack actual vs. target

| Capa | Actual (legacy) | Target |
|------|-----------------|--------|
| Frontend | HTML + Bootstrap 5 + CSS | Igual (estático) |
| Formulario | `fetch` → `php/controller/ContactoController.php` | `fetch` → API Gateway/Lambda |
| Persistencia | MySQL (`contactos`) | Email vía Resend |
| Hosting | Lightsail ~$6–7/mes | S3 + CloudFront |
| DNS | Route 53 | Route 53 (`contuttipizzaparty.com`) |
| Email | Make.com webhook + DB | Resend |

## Formulario de reservas

Campos enviados como JSON:

- `nombre`, `telefono`, `email`, `fecha`, `cantidad_invitados`, `zona`

Validación en cliente (`js/main.js`): teléfono con patrón `[0-9]{4}-?[0-9]{6}`.

## Credenciales y herramientas

| Archivo | Uso |
|---------|-----|
| `.env.aws` | `AWS_PROFILE=contutti`, región `us-east-1`, cuenta `815442486080` |
| `aws/credentials` + `aws/config` | Perfil CLI/MCP |
| `.env.resend` | API key, dominio verificado, remitente y destino |
| `.cursor/mcp.json` | MCP AWS Labs + `resend-mcp` |

**CLI AWS:** `~/.local/bin/aws` con `AWS_PROFILE=contutti`.

**MCP:** reiniciar Cursor tras cambios en `.cursor/mcp.json`.

## Reglas para agentes

1. **Leé `memory.md`** antes de actuar; **actualizalo** si completás o cambiás algo de infra, DNS, despliegue o decisiones.
2. **Respondé en español** al usuario.
3. **No commitear** salvo que el usuario lo pida explícitamente.
4. **Minimizá el scope**: no refactorizar código no relacionado con la tarea.
5. **No exponer secretos** en logs, commits públicos ni respuestas innecesarias; las claves ya están en `.env.*` del repo privado.
6. **PHP es legacy**: no extender `php/` salvo migración temporal; el target es eliminarlo.
7. **Dominio canónico:** `contuttipizzaparty.com` (no `contutti.com.ar`).
8. **Email:** enviar desde `consultas@contuttipizzaparty.com` hacia `contuttipizzaparty@gmail.com`.
9. **Preferir MCP/CLI** configurados antes de pedir credenciales al usuario.
10. **No desplegar** infraestructura sin confirmación explícita del usuario (salvo tareas de setup ya acordadas).

## Tareas típicas

### Desplegar sitio estático
- Bucket S3 privado + CloudFront + OAC
- Certificado ACM en `us-east-1`
- Registros A/AAAA Alias en Route 53 hacia CloudFront

### Formulario con Resend
- Lambda con `RESEND_API_KEY` en env (desde `.env.resend`)
- API Gateway HTTP API con CORS
- Actualizar `js/main.js` con la URL del endpoint
- Nunca poner la API key de Resend en el frontend

### DNS
- Zona activa: `contuttipizzaparty.com` (`Z02034301Y094BS9DFTIE`)
- Registros Resend ya configurados (DKIM + SPF en subdominio `send`)

## Referencias útiles

- [Resend MCP](https://resend.com/docs/mcp-server)
- [AWS API MCP Server](https://awslabs.github.io/mcp/servers/aws-api-mcp-server)
- [Host static website on S3 + CloudFront](https://aws.amazon.com/getting-started/hands-on/host-static-website/)
