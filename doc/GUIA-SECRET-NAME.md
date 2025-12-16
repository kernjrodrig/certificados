# Guía: Qué valor usar en `secret_name`

## ¿Qué es `secret_name`?

`secret_name` es el **nombre del secreto TLS de Kubernetes** que contiene el certificado y la llave privada que se aplicará al Ingress Controller de OpenShift.

Este secreto debe existir en el namespace `openshift-ingress` y ser de tipo `kubernetes.io/tls`.

## Opciones para `secret_name`

### Opción 1: Usar el secreto por defecto de OpenShift (Recomendado)

Si quieres **reemplazar el certificado por defecto** del cluster:

```yaml
secret_name: "router-certs-default"
```

**Ventajas:**
- ✅ Es el secreto estándar que OpenShift crea automáticamente
- ✅ Ya está configurado en el Ingress Controller por defecto
- ✅ El rol solo actualizará el contenido del secreto existente

**Cuándo usarlo:**
- Cuando quieres reemplazar el certificado que ya está en uso
- Cuando es la primera vez que cambias el certificado del Ingress

### Opción 2: Crear un nuevo secreto con nombre personalizado

Si quieres **crear un nuevo secreto** con un nombre específico:

```yaml
secret_name: "ingress-tls-secret"
# o cualquier otro nombre, por ejemplo:
# secret_name: "my-custom-cert-secret"
# secret_name: "uatocp-ingress-cert"
```

**Ventajas:**
- ✅ Puedes tener múltiples certificados y cambiar entre ellos
- ✅ Más control sobre qué certificado está activo

**Cuándo usarlo:**
- Cuando quieres mantener el certificado anterior y crear uno nuevo
- Cuando necesitas cambiar entre diferentes certificados

**⚠️ Importante:** Si usas un nombre nuevo, el rol:
1. Creará el secreto con ese nombre
2. Actualizará el Ingress Controller para que use ese nuevo secreto

## Cómo identificar qué secreto está usando tu cluster actualmente

### Método 1: Verificar el Ingress Controller (Recomendado)

```bash
oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}'
```

Si devuelve un nombre, ese es el secreto que está en uso actualmente.

### Método 2: Listar secretos TLS en openshift-ingress

```bash
oc get secrets -n openshift-ingress | grep "kubernetes.io/tls"
```

Esto mostrará todos los secretos TLS disponibles.

### Método 3: Usar el script de identificación

He creado un script que te ayuda a identificar el secreto:

```bash
./identificar-secret-name.sh <api-url> <token>
```

Ejemplo:
```bash
./identificar-secret-name.sh https://api.uatocp.imss.gob.mx:6443 sha256~TU_TOKEN
```

## Recomendación según tu caso

Basado en tu certificado `apps_uatocp_imss_gob_mx.crt`:

### Si es la primera vez que cambias el certificado:

```yaml
clusters:
  - name: uatocp
    api_url: "https://api.uatocp.imss.gob.mx:6443"
    token: "{{ vault_uatocp_token }}"
    secret_name: "router-certs-default"  # ← Usa el por defecto
    namespace_ingress: "openshift-ingress"
    cert_file_new: "{{ playbook_dir }}/certs/apps_uatocp_imss_gob_mx.crt"
    key_file_new: "{{ playbook_dir }}/certs/apps_uatocp_imss_gob_mx_sinpassw.key"
    # ... resto de configuración
```

### Si ya tienes un certificado personalizado y quieres reemplazarlo:

Primero identifica el nombre actual:
```bash
oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}'
```

Luego usa ese nombre en `vars.yml`:
```yaml
secret_name: "<nombre-que-encontraste>"
```

### Si quieres crear un nuevo secreto sin tocar el actual:

```yaml
secret_name: "uatocp-ingress-cert"  # ← Nombre personalizado
```

## Ejemplos de nombres comunes

- `router-certs-default` - Por defecto de OpenShift
- `ingress-tls-secret` - Nombre común
- `router-certs` - Alternativa común
- `custom-ingress-cert` - Personalizado
- `uatocp-ingress-cert` - Específico para tu cluster

## Resumen

| Escenario | Valor recomendado |
|-----------|-------------------|
| Primera vez cambiando certificado | `router-certs-default` |
| Reemplazar certificado existente | El nombre actual (verificar con `oc get ingresscontroller`) |
| Crear nuevo certificado sin tocar el actual | Cualquier nombre personalizado |

## Verificación después de aplicar

Después de ejecutar el playbook, verifica que el secreto se creó/actualizó correctamente:

```bash
# Ver el secreto
oc get secret router-certs-default -n openshift-ingress

# Ver el certificado dentro del secreto
oc get secret router-certs-default -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -dates
```

