# Con Tutti Pizza Party — Sitio Web

Sitio web oficial de **Con Tutti Pizza Party**, servicio de catering para eventos (pizza party, empanadas, pernil, picadas y más) en Buenos Aires.

**URL:** https://contuttipizzaparty.com

---

## ¿Qué hace este sitio?

- Muestra información del servicio de catering
- Permite enviar consultas de reserva mediante un formulario
- Las consultas llegan por **email** a `contuttipizzaparty@gmail.com` (no hay base de datos)

---

## Stack tecnológico

| Capa | Tecnología |
|------|------------|
| Frontend | HTML, CSS, JavaScript (sin frameworks) |
| Hosting | Amazon S3 + CloudFront (CDN con HTTPS) |
| Formulario | AWS Lambda + API Gateway |
| Email | Resend |
| DNS | Amazon Route 53 |
| Certificado SSL | AWS Certificate Manager (gratis) |

**Costo mensual estimado:** ~$1 USD (principalmente Route 53)

---

## Estructura del proyecto

```
ConTuttiWeb/
├── index.html                 # Página principal
├── politicadeprivacidad.html  # Política de privacidad
├── styles.css                 # Estilos del sitio
├── js/
│   ├── main.js                # Lógica del formulario y navegación
│   └── config.js              # URL del API (se actualiza al desplegar)
├── images/                    # Fotos, logos y videos
├── infra/
│   ├── deployment.env         # IDs de recursos AWS (generado al desplegar)
│   └── lambda/contact-form/   # Código del backend del formulario
├── scripts/
│   ├── deploy.sh              # Despliega todo en AWS
│   └── cleanup-legacy.sh      # Limpieza de recursos viejos
├── aws/                       # Credenciales AWS (perfil contutti, local)
├── .env.aws.example           # Plantilla variables AWS
├── .env.resend.example        # Plantilla variables Resend
├── agents.md                  # Guía para agentes de IA
└── memory.md                  # Estado del proyecto
```

---

## Cómo editar textos o imágenes

### Cambiar un texto

1. Abrí `index.html` con cualquier editor de texto
2. Buscá la sección que querés modificar (Comidas, Servicios, etc.)
3. Editá el texto entre las etiquetas HTML
4. Guardá el archivo
5. Ejecutá el despliegue (ver abajo)

### Cambiar una imagen

1. Reemplazá el archivo en la carpeta `images/` (manteniendo el mismo nombre), **o**
2. Agregá una imagen nueva y actualizá la ruta en `index.html` (ej: `src="images/mi-foto.jpg"`)

### Cambiar datos de contacto

Buscá en `index.html` el teléfono, email, links de redes sociales y el mapa. Están en las secciones **Contacto** y **footer**.

---

## Cómo desplegar cambios en AWS

Desde la carpeta del proyecto, ejecutá:

```bash
./scripts/deploy.sh
```

Ese script:
1. Sube los archivos del sitio a S3
2. Actualiza la Lambda del formulario si cambió
3. Invalida la caché de CloudFront (para que se vean los cambios al instante)

**Importante:** los cambios pueden tardar 1-2 minutos en verse online por la caché de CloudFront.

### Requisitos previos

- AWS CLI instalado (`~/.local/bin/aws`)
- Perfil `contutti` configurado (copiá `.env.aws.example` → `.env.aws` y `aws/credentials.example` → `aws/credentials`)

```bash
export AWS_PROFILE=contutti
aws sts get-caller-identity   # verificar que funciona
```

---

## Credenciales y configuración

| Archivo | Contenido |
|---------|-----------|
| `.env.aws` | Claves AWS, región, cuenta (local, no versionado) |
| `.env.resend` | API key de Resend, email remitente y destino (local) |
| `.cursor/mcp.json` | MCP de Cursor con claves (local; ver `mcp.json.example`) |
| `infra/deployment.env` | IDs de bucket, CloudFront, Lambda, API (generado automáticamente) |

Los archivos con secretos están en `.gitignore`. Copiá los `.example` y completá con tus claves. GitHub bloquea el push si se incluyen credenciales en el historial.

---

## Infraestructura AWS (despliegue actual)

| Recurso | Valor |
|---------|-------|
| Dominio | `contuttipizzaparty.com` |
| Bucket S3 | `contuttipizzaparty-web-815442486080` |
| CloudFront | `E2FYMGEV5S6RU0` |
| Lambda | `contuttipizzaparty-contact-form` |
| API Gateway | `https://le08r9v6w9.execute-api.us-east-1.amazonaws.com/contact` |
| Route 53 Zone | `Z02034301Y094BS9DFTIE` |
| Región | `us-east-1` |

Detalle completo en `infra/deployment.env`.

---

## DNS — qué tocar y qué no

**No modificar manualmente** salvo que sepas lo que hacés:

- Registros `A` / `AAAA` de `contuttipizzaparty.com` y `www` → apuntan a CloudFront
- Registros `send` y `resend._domainkey` → necesarios para enviar emails con Resend

Si cambiás el dominio o recreás CloudFront, volvé a ejecutar `./scripts/deploy.sh`.

---

## Problemas frecuentes

### El sitio no muestra mis cambios

1. ¿Ejecutaste `./scripts/deploy.sh`?
2. Esperá 1-2 minutos (invalidación de CloudFront)
3. Probá en ventana de incógnito o Ctrl+F5

### El formulario no envía

1. Verificá que `js/config.js` tenga la URL correcta del API
2. Revisá logs de Lambda en AWS Console → CloudWatch
3. Verificá que Resend tenga el dominio verificado (`contuttipizzaparty.com`)

### Error de teléfono en el formulario

Formato válido: código de área + número, ej. `11-30040583` o `1130040583`

---

## Contacto del negocio

- **WhatsApp / Tel:** 11-3004-0583
- **Email:** contuttipizzaparty@gmail.com
- **Instagram:** [@contutti.pizzaparty](https://www.instagram.com/contutti.pizzaparty/)
- **Dirección:** Sourdeaux 898, Bella Vista
