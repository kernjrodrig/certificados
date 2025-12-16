# Guía: Qué Certificados Agregar en vars.yml

## Certificados Disponibles en `certs/`

Basado en el análisis, tienes los siguientes archivos:

1. **Certificado del servidor**: `apps_uatocp_imss_gob_mx.crt`
   - Subject: `*.apps.uatocp.imss.gob.mx`
   - Válido hasta: 11/12/2026 (360 días restantes)
   - **Este es el certificado principal que se aplicará al Ingress**

2. **Llave privada**: `apps_uatocp_imss_gob_mx_sinpassw.key`
   - RSA 4096 bits
   - Sin contraseña
   - **Debe corresponder con el certificado**

3. **CA Intermedia**: `CA_Intermedia.cer` (opcional)
   - DigiCert Global Root G2

4. **CA Raíz**: `CA_Raiz.crt` (opcional)
   - RapidSSL TLS RSA CA G1

## Configuración en vars.yml

### Opción 1: Solo Certificado del Servidor (Recomendado para OpenShift)

OpenShift puede usar solo el certificado del servidor, ya que los navegadores tienen las CAs raíz en su almacén de confianza.

```yaml
clusters:
  - name: uatocp
    api_url: "https://api.uatocp.imss.gob.mx:6443"  # Ajusta según tu cluster
    token: "{{ vault_uatocp_token }}"  # Usa Ansible Vault
    secret_name: "router-certs-default"  # o el nombre que uses
    namespace_ingress: "openshift-ingress"
    cert_file: "/tmp/uatocp-ingress-cert.pem"
    # Rutas a los certificados en el directorio certs/
    cert_file_new: "{{ playbook_dir }}/certs/apps_uatocp_imss_gob_mx.crt"
    key_file_new: "{{ playbook_dir }}/certs/apps_uatocp_imss_gob_mx_sinpassw.key"
    backup_file: "/tmp/ingress-backup-uatocp.yaml"
    namespace_ingress_operator: openshift-ingress-operator
    ingress_controller_name: default
```

### Opción 2: Certificado con Cadena Completa (Mejor compatibilidad)

Si quieres incluir la cadena completa (certificado + intermedios), primero necesitas concatenar los certificados:

```bash
# Crear certificado con cadena completa
cat certs/apps_uatocp_imss_gob_mx.crt certs/CA_Raiz.crt > certs/apps_uatocp_imss_gob_mx-chain.crt
```

Luego en vars.yml:

```yaml
clusters:
  - name: uatocp
    api_url: "https://api.uatocp.imss.gob.mx:6443"
    token: "{{ vault_uatocp_token }}"
    secret_name: "router-certs-default"
    namespace_ingress: "openshift-ingress"
    cert_file: "/tmp/uatocp-ingress-cert.pem"
    # Usar certificado con cadena completa
    cert_file_new: "{{ playbook_dir }}/certs/apps_uatocp_imss_gob_mx-chain.crt"
    key_file_new: "{{ playbook_dir }}/certs/apps_uatocp_imss_gob_mx_sinpassw.key"
    backup_file: "/tmp/ingress-backup-uatocp.yaml"
    namespace_ingress_operator: openshift-ingress-operator
    ingress_controller_name: default
```

## Archivos Necesarios

### Mínimo Requerido:
- ✅ `cert_file_new`: Certificado del servidor (`.crt` o `.pem`)
- ✅ `key_file_new`: Llave privada (`.key`)

### Opcional (para cadena completa):
- `CA_Raiz.crt`: Certificado de CA intermedia
- `CA_Intermedia.cer`: Certificado de CA raíz

## Notas Importantes

1. **Rutas**: Usa `{{ playbook_dir }}` para rutas relativas al directorio del playbook
2. **Seguridad**: Los certificados están en `.gitignore`, no se subirán al repo
3. **Validaciones**: El rol ahora valida automáticamente:
   - Que el certificado y la llave correspondan
   - Que el certificado no esté vencido
   - Que tenga validez mínima (30 días por defecto)
   - Detecta si la cadena completa está incluida

## Ejemplo Completo de vars.yml

```yaml
---
clusters:
  - name: uatocp
    api_url: "https://api.uatocp.imss.gob.mx:6443"
    token: "{{ vault_uatocp_token }}"  # Protege con Ansible Vault
    secret_name: "router-certs-default"
    namespace_ingress: "openshift-ingress"
    cert_file: "/tmp/uatocp-ingress-cert.pem"
    cert_file_new: "{{ playbook_dir }}/certs/apps_uatocp_imss_gob_mx.crt"
    key_file_new: "{{ playbook_dir }}/certs/apps_uatocp_imss_gob_mx_sinpassw.key"
    backup_file: "/tmp/ingress-backup-uatocp.yaml"
    namespace_ingress_operator: openshift-ingress-operator
    ingress_controller_name: default
```

