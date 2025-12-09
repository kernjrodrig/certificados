## Descripción

Este repositorio contiene un rol de Ansible (`certificado`) que automatiza la gestión de certificados TLS en Ingress Controllers de OpenShift: consulta el secreto TLS actual, verifica su expiración y, si faltan menos días que el umbral configurado, reemplaza el secreto y actualiza el Ingress Controller.

## Requisitos

- Ansible y Python recientes
- Colecciones: `community.crypto` y `kubernetes.core`

Instalación rápida de colecciones:

```bash
ansible-galaxy collection install community.crypto kubernetes.core
```

## Uso

1) Define tus clústeres en `vars.yml`. Ejemplo mínimo por clúster:

```yaml
clusters:
  - name: production
    api_url: "https://api.prod.example.com:6443"
    token: "{{ vault_prod_token }}"  # usa Ansible Vault
    secret_name: "ingress-tls-secret"
    namespace_ingress: "openshift-ingress"
    cert_file_new: "{{ playbook_dir }}/certs/prod-cert.pem"  # fuera del repo
    key_file_new: "{{ playbook_dir }}/certs/prod-key.pem"    # fuera del repo
```

2) Ejecuta el playbook del rol:

```bash
ansible-playbook -i localhost, playbook-with-role.yml --ask-vault-pass  # si usas Ansible Vault
```

El rol:
- Extrae y analiza el certificado actual del secreto TLS
- Calcula días restantes de validez
- Si quedan menos que `certificate.replacement_threshold_days` (por defecto 60), valida tus nuevos archivos `cert_file_new`/`key_file_new` y actualiza el secreto e Ingress Controller

## Variables clave

- `clusters`: lista de clústeres a procesar (ver `vars.yml`)
- `certificate.replacement_threshold_days`: umbral de días para reemplazo automático (default 60)
- `certificate.min_validity_days`: días mínimos de validez exigidos al certificado nuevo (default 30)

## Buenas prácticas y seguridad

- No incluyas certificados ni llaves en el repositorio. Ubícalos fuera del repo (por ejemplo, `{{ playbook_dir }}/certs/…`) y referencia sus rutas en `vars.yml`.
- Protege tokens y secretos con Ansible Vault.

## Archivos útiles

- `playbook-with-role.yml`: ejemplo de ejecución del rol con `vars.yml`
- `certificado/`: implementación del rol y su documentación propia (`certificado/README.md`)
- `vars.yml`: variables de tus clústeres (tokens referenciados vía Vault)

### Implementación en Ansible Automation Platform (AAP)

Sigue estos pasos para ejecutar este playbook en AAP (Controller):

1) Proyecto (SCM)
- Crea un Project apuntando a tu repositorio Git.
- Activa la sincronización de colecciones con `requirements.yml`:
  - En AAP 2.3+: marca "Sync Collections" en el Project y añade una credencial de tipo "Ansible Galaxy/Automation Hub" si tu entorno la requiere.

2) Inventario
- Crea un Inventory (p. ej. `Localhost`) y añade un Host `localhost`.

3) Credenciales
- Opcional: crea una credencial de tipo "Ansible Vault" si vas a almacenar secretos cifrados en el repo (`group_vars/all/vault.yml`).
- Opcional: credencial "Ansible Galaxy/Automation Hub" para la sincronización de colecciones.

4) Execution Environment
- Usa un EE que incluya `kubernetes.core` y `community.crypto`.
- Alternativas:
  - `ee-supported-rhel8` (si ya trae las colecciones que necesitas)
  - Un EE personalizado que instale `requirements.yml` en build time

5) Job Template
- Project: el creado en (1)
- Inventory: `Localhost`
- Playbook: `playbook-with-role.yml`
- Execution Environment: el de (4)
- Credentials: agrega la credencial de Vault si corresponde
- Extra Variables (opcional): puedes sobrescribir `clusters` aquí si no usas `vars.yml`.

Ejemplo de Extra Vars para definir clusters directamente en AAP:

```yaml
clusters:
  - name: production
    api_url: "https://api.prod.example.com:6443"
    token: "{{ vault_prod_token }}"   # definido en tu vault o como var sensible
    secret_name: "ingress-tls-secret"
    namespace_ingress: "openshift-ingress"
    cert_file_new: "/runner/project/certs/prod-cert.pem"
    key_file_new: "/runner/project/certs/prod-key.pem"
```

Notas:
- Si usas archivos de cert/llave, colócalos en una ruta accesible desde el EE en runtime (por ejemplo, dentro del Project checkout o montados en el EE). Ajusta las rutas en consecuencia.
- Si almacenas tokens/secretos en `group_vars/all/vault.yml`, encripta con Ansible Vault y asigna la credencial de Vault al Job Template.
- Asegura conectividad desde el EE hacia las APIs de OpenShift de tus clústeres.

## Notas sobre contenidos removidos

Se eliminaron los activos de certificados en `certificado/files/` para evitar almacenar material sensible. Aporta tus propios archivos mediante `cert_file_new` y `key_file_new`.

## Legacy

Se eliminaron playbooks legacy de la raíz que duplicaban la lógica del rol:

- `extract_cert.yml`
- `reemplaza.yml`
- `login-get-certifi.yml`
- `login-openshift.yml`

La fuente de verdad es el rol `certificado` (ver `certificado/tasks/`). Usa `playbook-with-role.yml` para ejecutar el flujo recomendado.