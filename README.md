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
    cert_file_new: "{{ role_path }}/files/prod-cert.pem"  # en roles/certificado/files/
    key_file_new: "{{ role_path }}/files/prod-key.pem"    # en roles/certificado/files/
```

2) Ejecuta el playbook del rol:

**Opción A: Con ansible-playbook tradicional**
```bash
ansible-playbook -i localhost, playbook-with-role.yml --ask-vault-pass  # si usas Ansible Vault
```

**Opción B: Con Ansible Navigator (recomendado)**
```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1 \
  --inventory localhost, \
  --mode interactive
```

Si usas Ansible Vault:
```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1 \
  --inventory localhost, \
  --vault-password-file ~/.vault_pass \
  --mode interactive
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

- No incluyas certificados ni llaves en el repositorio. Ubícalos en `roles/certificado/files/` (por ejemplo, `{{ role_path }}/files/…`) y referencia sus rutas en `vars.yml`.
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
- Usa el Execution Environment: `quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1`
- Este EE incluye las colecciones necesarias (`kubernetes.core` y `community.crypto`)
- Asegúrate de que el EE esté disponible en tu AAP Controller o configúralo para que pueda acceder a Quay.io

5) Job Template
- Project: el creado en (1)
- Inventory: `Localhost`
- Playbook: `playbook-with-role.yml`
- Execution Environment: `quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1`
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
    cert_file_new: "/runner/project/roles/certificado/files/prod-cert.pem"
    key_file_new: "/runner/project/roles/certificado/files/prod-key.pem"
```

Notas:
- Si usas archivos de cert/llave, colócalos en una ruta accesible desde el EE en runtime (por ejemplo, dentro del Project checkout o montados en el EE). Ajusta las rutas en consecuencia.
- Si almacenas tokens/secretos en `group_vars/all/vault.yml`, encripta con Ansible Vault y asigna la credencial de Vault al Job Template.
- Asegura conectividad desde el EE hacia las APIs de OpenShift de tus clústeres.

## Uso con Ansible Navigator

Ansible Navigator es la herramienta moderna recomendada para ejecutar playbooks de Ansible usando Execution Environments.

### Configuración básica

1. **Instalar Ansible Navigator** (si no está instalado):
```bash
pip install ansible-navigator
```

2. **Ejecutar el playbook**:
```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1 \
  --inventory localhost, \
  --mode interactive
```

### Opciones útiles de Ansible Navigator

**Modo interactivo** (recomendado para desarrollo):
```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1 \
  --inventory localhost, \
  --mode interactive
```

**Modo stdout** (similar a ansible-playbook):
```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1 \
  --inventory localhost, \
  --mode stdout
```

**Con Ansible Vault**:
```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1 \
  --inventory localhost, \
  --vault-password-file ~/.vault_pass \
  --mode stdout
```

**Con variables extra**:
```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1 \
  --inventory localhost, \
  --cmdline "-e 'certificate.replacement_threshold_days=30'" \
  --mode stdout
```

**Con archivo de configuración** (ansible-navigator.yml):
```yaml
---
ansible-navigator:
  execution-environment:
    image: quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1
    pull:
      policy: always
```

Nota: En ansible-navigator v2, `playbook` e `inventory` se pasan como argumentos de línea de comandos, no en el archivo de configuración.

Luego ejecuta:
```bash
ansible-navigator run playbook-with-role.yml --inventory localhost,
```

O si quieres especificar todo en la línea de comandos:
```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1 \
  --inventory localhost, \
  --mode interactive
```

### Ventajas de usar Ansible Navigator

- ✅ Ejecución consistente usando Execution Environments
- ✅ Aislamiento de dependencias (no contamina tu sistema local)
- ✅ Mismo entorno que en Ansible Automation Platform
- ✅ Modo interactivo para debugging y exploración
- ✅ Mejor integración con colecciones y roles

## Notas sobre contenidos removidos

Se eliminaron los activos de certificados en `certificado/files/` para evitar almacenar material sensible. Aporta tus propios archivos mediante `cert_file_new` y `key_file_new`.

## Legacy

Se eliminaron playbooks legacy de la raíz que duplicaban la lógica del rol:

- `extract_cert.yml`
- `reemplaza.yml`
- `login-get-certifi.yml`
- `login-openshift.yml`

La fuente de verdad es el rol `certificado` (ver `certificado/tasks/`). Usa `playbook-with-role.yml` para ejecutar el flujo recomendado.