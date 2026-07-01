# memory.md — Memoria del proyecto

> Documento vivo. Los agentes deben leerlo al inicio y actualizarlo cuando cambie el estado.

**Última actualización:** 2026-07-01

---

## Resumen ejecutivo

Sitio web de **Con Tutti Pizza Party** desplegado en AWS (S3 + CloudFront + Lambda + Resend). Dominio: **contuttipizzaparty.com**. Lightsail y zona DNS legacy eliminados.

---

## Estado actual: PRODUCCIÓN

| Componente | Estado |
|------------|--------|
| Frontend rediseñado | ✅ Completado |
| Formulario → email Resend | ✅ Funcional |
| Deploy AWS | ✅ Completado |
| DNS contuttipizzaparty.com | ✅ Apuntando a CloudFront |
| Lightsail apagado | ✅ Instancia `LAMP-ConTutti` eliminada |
| Zona contutti.com.ar | ✅ Eliminada |
| PHP legacy | ✅ Eliminado |

---

## Infraestructura AWS

| Recurso | Valor |
|---------|-------|
| Account ID | `815442486080` |
| Región | `us-east-1` |
| Perfil CLI | `contutti` |
| Bucket S3 | `contuttipizzaparty-web-815442486080` |
| CloudFront ID | `E2FYMGEV5S6RU0` |
| CloudFront domain | `d2bnzkifrnoj0f.cloudfront.net` |
| ACM cert | `arn:aws:acm:us-east-1:815442486080:certificate/55b1920a-989f-480a-9c0c-b79fdc6c27cf` |
| Lambda | `contuttipizzaparty-contact-form` |
| API URL | `https://le08r9v6w9.execute-api.us-east-1.amazonaws.com/contact` |
| Route 53 zone | `Z02034301Y094BS9DFTIE` (contuttipizzaparty.com) |

Ver `infra/deployment.env` para detalle completo.

---

## Resend

| Campo | Valor |
|-------|-------|
| Dominio | `contuttipizzaparty.com` (verified) |
| From | `consultas@contuttipizzaparty.com` |
| To | `contuttipizzaparty@gmail.com` |
| Config | `.env.resend` |

---

## Decisiones tomadas

| Fecha | Decisión |
|-------|----------|
| 2026-07-01 | Migración completa a arquitectura serverless |
| 2026-07-01 | Dominio canónico: contuttipizzaparty.com |
| 2026-07-01 | Eliminar contutti.com.ar (sin redirect) |
| 2026-07-01 | Brochetas Caprese agregada al menú |
| 2026-07-01 | Regex teléfono: 2-4 dígitos área + 6-8 dígitos número |

---

## Despliegue

```bash
./scripts/deploy.sh
```

---

## Notas para agentes

- El script de deploy puede tardar ~5-8 min (espera certificado ACM). Muestra progreso en consola.
- Si el deploy falla en ACM, re-ejecutar: el script ahora agrega registros DNS aunque el cert ya exista.
- CloudFront directo funciona antes que el dominio custom (propagación DNS).
