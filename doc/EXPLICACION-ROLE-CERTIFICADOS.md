# 📋 Explicación Detallada del Role de Certificados

## 🎯 Objetivo del Role

El role `certificado` gestiona automáticamente la renovación de certificados TLS en clústeres de OpenShift. Detecta certificados próximos a expirar y los reemplaza de forma segura, creando backups y validando la integridad antes de aplicar cambios.

---

## 📊 Flujo General del Role

```
┌─────────────────────────────────────────────────────────────┐
│ 1. INICIO: playbook-with-role.yml                           │
│    - Carga variables desde vars.yml                         │
│    - Invoca el role "certificado"                           │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. MAIN TASK: roles/certificado/tasks/main.yml              │
│    - Itera sobre cada cluster en la lista "clusters"       │
│    - Para cada cluster, incluye process_cluster.yml         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. PROCESS CLUSTER: process_cluster.yml                     │
│    - Extrae certificado actual del cluster                  │
│    - Calcula días hasta expiración                          │
│    - Si < 60 días → incluye replace_certificate.yml         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. REPLACE CERTIFICATE: replace_certificate.yml             │
│    - Crea backup del secreto actual                         │
│    - Valida nuevo certificado                               │
│    - Actualiza Secret en Kubernetes                         │
│    - Actualiza IngressController                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 Paso a Paso Detallado

### **FASE 1: Inicialización (main.yml)**

#### **Tarea 1.1: Debug - Mostrar clusters disponibles**
```yaml
- name: Debug - Mostrar clusters disponibles
  ansible.builtin.debug:
    msg: "Clusters disponibles: {{ clusters | default('undefined') }}"
```

**¿Qué hace?**
- Muestra en consola la lista de clusters configurados en `vars.yml`
- Útil para debugging y verificación

**¿Qué modifica?**
- ❌ No modifica nada, solo muestra información

**Ejemplo de salida:**
```
TASK [certificado : Debug - Mostrar clusters disponibles] 
ok: [localhost] => {
    "msg": "Clusters disponibles: [{'name': 'cluster1', 'api_url': 'https://...', ...}]"
}
```

---

#### **Tarea 1.2: Procesar cada cluster**
```yaml
- name: Procesar cada cluster
  ansible.builtin.include_tasks: process_cluster.yml
  loop: "{{ clusters | default([]) }}"
  loop_control:
    loop_var: current_cluster
    label: "{{ current_cluster.name | default('unknown') }}"
```

**¿Qué hace?**
- Itera sobre cada cluster definido en `vars.yml`
- Para cada cluster, ejecuta todas las tareas de `process_cluster.yml`
- Usa `current_cluster` como variable para el cluster actual

**¿Qué modifica?**
- ❌ No modifica nada directamente, solo invoca otras tareas

**Ejemplo:**
- Si tienes 2 clusters en `vars.yml`, esta tarea se ejecutará 2 veces
- Primera iteración: `current_cluster = cluster1`
- Segunda iteración: `current_cluster = cluster2`

---

### **FASE 2: Análisis del Certificado Actual (process_cluster.yml)**

#### **Tarea 2.1: Obtener secreto TLS del cluster**
```yaml
- name: Obtener secreto TLS del cluster {{ current_cluster.name }}
  kubernetes.core.k8s_info:
    host: "{{ current_cluster.api_url }}"
    api_key: "{{ current_cluster.token }}"
    api_version: v1
    kind: Secret
    name: "{{ current_cluster.secret_name }}"
    namespace: "{{ current_cluster.namespace_ingress }}"
    verify_ssl: false
  register: secret_data
```

**¿Qué hace?**
- Se conecta al cluster de OpenShift usando la API de Kubernetes
- Obtiene el Secret TLS que contiene el certificado actual
- Guarda toda la información del secreto en la variable `secret_data`

**¿Qué modifica?**
- ❌ No modifica el cluster, solo lee información

**Ejemplo de datos obtenidos:**
```yaml
secret_data:
  resources:
    - apiVersion: v1
      kind: Secret
      metadata:
        name: cert-manager-ingress-cert
        namespace: openshift-ingress
      type: kubernetes.io/tls
      data:
        tls.crt: "LS0tLS1CRUdJTi..."  # Certificado en base64
        tls.key: "LS0tLS1CRUdJTi..."  # Llave privada en base64
```

---

#### **Tarea 2.2: Validar existencia del secreto**
```yaml
- name: Validar existencia del secreto en el cluster {{ current_cluster.name }}
  ansible.builtin.fail:
    msg: "El secreto {{ current_cluster.secret_name }} no existe..."
  when: secret_data.resources | length == 0
```

**¿Qué hace?**
- Verifica que el secreto existe en el cluster
- Si no existe, detiene la ejecución con un error

**¿Qué modifica?**
- ❌ No modifica nada, solo valida

**Ejemplo:**
- Si el secreto existe: ✅ Continúa
- Si el secreto NO existe: ❌ Falla con mensaje de error

---

#### **Tarea 2.3: Extraer y guardar certificado en archivo temporal**
```yaml
- name: Extraer y guardar certificado en un archivo temporal
  ansible.builtin.copy:
    content: "{{ secret_data.resources[0].data['tls.crt'] | b64decode }}"
    dest: "{{ current_cluster.cert_file }}"
    mode: '0600'
```

**¿Qué hace?**
- Decodifica el certificado desde base64 (formato almacenado en Kubernetes)
- Guarda el certificado en un archivo temporal en el sistema local
- Establece permisos 0600 (solo lectura para el propietario)

**¿Qué modifica?**
- ✅ **Crea/modifica un archivo temporal en el servidor local**
  - Ruta: `/tmp/cluster1-ingress-cert.pem` (ejemplo)
  - Contenido: Certificado PEM decodificado
  - Permisos: `-rw-------` (0600)

**Ejemplo del archivo creado:**
```pem
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAKZ7Z2Z2Z2Z2MA0GCSqGSIb3DQEBCQUAMEUxCzAJBgNV
...
-----END CERTIFICATE-----
```

---

#### **Tarea 2.4: Obtener información del certificado**
```yaml
- name: Obtener información del certificado del cluster {{ current_cluster.name }}
  community.crypto.x509_certificate_info:
    path: "{{ current_cluster.cert_file }}"
  register: cert_info
```

**¿Qué hace?**
- Lee el archivo del certificado temporal
- Extrae información del certificado X.509:
  - Subject (CN, O, etc.)
  - Issuer (quién emitió el certificado)
  - Fecha de inicio de validez (`not_before`)
  - Fecha de expiración (`not_after`)
  - Número de serie
  - Información de la llave pública

**¿Qué modifica?**
- ❌ No modifica nada, solo lee información

**Ejemplo de datos extraídos:**
```yaml
cert_info:
  subject: CN=*.apps.cluster-qbfmq.dynamic.redhatworkshops.io
  issuer: CN=Let's Encrypt Authority X3
  not_before: 20240101120000Z
  not_after: 20240401120000Z
  serial_number: 1234567890
  public_key: RSA 2048 bits
```

---

#### **Tarea 2.5: Calcular días hasta el vencimiento**
```yaml
- name: Calcular días hasta el vencimiento
  ansible.builtin.set_fact:
    days_to_expiry: "{{ (((expiry_timestamp | int) - (current_timestamp | int)) / 86400) | int }}"
```

**¿Qué hace?**
- Calcula cuántos días faltan hasta que expire el certificado
- Fórmula: `(fecha_expiración - fecha_actual) / 86400 segundos`
- Guarda el resultado en la variable `days_to_expiry`

**¿Qué modifica?**
- ❌ No modifica el cluster, solo calcula y guarda en memoria

**Ejemplo:**
- Si el certificado expira en 30 días: `days_to_expiry = 30`
- Si el certificado expira en 90 días: `days_to_expiry = 90`

---

#### **Tarea 2.6: Decisión - ¿Reemplazar certificado?**
```yaml
- name: Incluir tareas de reemplazo si el certificado expira en menos de 60 días
  ansible.builtin.include_tasks: replace_certificate.yml
  when: days_to_expiry is defined and (days_to_expiry | int) < 60
```

**¿Qué hace?**
- Evalúa si el certificado expira en menos de 60 días (configurable)
- Si SÍ: ejecuta todas las tareas de `replace_certificate.yml`
- Si NO: omite el reemplazo y termina para este cluster

**¿Qué modifica?**
- ❌ No modifica nada directamente, solo decide si continuar

**Ejemplo:**
- Certificado expira en 30 días → ✅ Ejecuta `replace_certificate.yml`
- Certificado expira en 90 días → ⏭️ Omite el reemplazo

---

### **FASE 3: Reemplazo del Certificado (replace_certificate.yml)**

> ⚠️ **IMPORTANTE**: Esta fase solo se ejecuta si el certificado expira en menos de 60 días (configurable).

**Flujo de la Fase 3:**
1. Backup del secreto actual
2. Obtener fecha actual y definir nombres con fecha
3. Verificar y unir certificados (servidor + CA intermedia + CA raíz)
4. Validar certificado combinado y entidades certificantes
5. Crear ConfigMap con certificado combinado
6. Aplicar patch al proxy/cluster para confiar en la CA personalizada
7. Crear Secret TLS con certificado combinado (nombre con fecha)
8. Actualizar IngressController para usar el nuevo Secret

---

#### **Tarea 3.1: Obtener secreto TLS actual para backup**
```yaml
- name: Obtener secreto TLS actual para backup antes del reemplazo
  kubernetes.core.k8s_info:
    host: "{{ cluster.api_url }}"
    api_key: "{{ cluster.token }}"
    kind: Secret
    name: "{{ cluster.secret_name }}"
    namespace: "{{ cluster.namespace_ingress }}"
  register: current_secret_backup
```

**¿Qué hace?**
- Obtiene nuevamente el secreto completo del cluster
- Esta vez específicamente para crear un backup antes de modificarlo

**¿Qué modifica?**
- ❌ No modifica el cluster, solo lee

---

#### **Tarea 3.2: Crear directorio de backup**
```yaml
- name: Crear directorio de backup si no existe
  ansible.builtin.file:
    path: "{{ cluster.backup_file | dirname }}"
    state: directory
    mode: '0700'
```

**¿Qué hace?**
- Crea el directorio donde se guardará el backup (si no existe)
- Establece permisos 0700 (solo el propietario puede acceder)

**¿Qué modifica?**
- ✅ **Crea un directorio en el sistema local**
  - Ejemplo: Crea `/tmp/` si no existe
  - Permisos: `drwx------` (0700)

---

#### **Tarea 3.3: Guardar backup completo del secreto**
```yaml
- name: Guardar backup completo del secreto antes del reemplazo
  ansible.builtin.copy:
    content: "{{ current_secret_backup.resources[0] | to_nice_yaml }}"
    dest: "{{ cluster.backup_file }}"
    mode: "0600"
```

**¿Qué hace?**
- Convierte el secreto completo a formato YAML legible
- Guarda el backup en un archivo local
- Establece permisos 0600 (solo lectura para el propietario)

**¿Qué modifica?**
- ✅ **Crea un archivo de backup en el sistema local**
  - Ruta: `/tmp/ingress-backup-cluster1.yaml` (ejemplo)
  - Contenido: YAML completo del Secret antes de modificarlo
  - Permisos: `-rw-------` (0600)

**Ejemplo del archivo de backup:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cert-manager-ingress-cert
  namespace: openshift-ingress
type: kubernetes.io/tls
data:
  tls.crt: "LS0tLS1CRUdJTi..."  # Certificado actual en base64
  tls.key: "LS0tLS1CRUdJTi..."  # Llave privada actual en base64
```

**💡 Utilidad del backup:**
- Permite hacer rollback manual si algo sale mal
- Documenta el estado anterior del secreto
- Útil para auditoría y troubleshooting

---

#### **Tarea 3.4: Obtener fecha actual y definir nombres de recursos**
```yaml
- name: Obtener fecha actual en formato YYYYMMDD
  ansible.builtin.set_fact:
    current_date: "{{ ansible_date_time.date | replace('-', '') }}"

- name: Definir nombres de recursos con fecha
  ansible.builtin.set_fact:
    configmap_name: "{{ cluster.configmap_name_prefix | default('custom-ca') }}-{{ current_date }}"
    secret_name_with_date: "{{ cluster.secret_name_prefix | default('router-certs') }}-{{ current_date }}"
```

**¿Qué hace?**
- Obtiene la fecha actual en formato YYYYMMDD (ejemplo: 20241225)
- Define nombres dinámicos para el ConfigMap y Secret que incluyen la fecha
- Esto permite tener múltiples versiones de certificados con timestamps

**¿Qué modifica?**
- ❌ No modifica nada, solo calcula valores en memoria

**Ejemplo:**
- Fecha actual: 2024-12-25
- ConfigMap: `custom-ca-20241225`
- Secret: `router-certs-20241225`

---

#### **Tarea 3.5: Verificar existencia de archivos de certificados**
```yaml
- name: Verificar existencia de archivos de certificados
  ansible.builtin.stat:
    path: "{{ item }}"
  register: cert_files_stat
  loop:
    - "{{ cluster.cert_file_crt }}"
    - "{{ cluster.ca_intermedia_file }}"
    - "{{ cluster.ca_raiz_file }}"
```

**¿Qué hace?**
- Verifica que existen los tres archivos necesarios:
  - Certificado del servidor (.crt)
  - CA intermedia (.cer)
  - CA raíz (.cer)

**¿Qué modifica?**
- ❌ No modifica nada, solo verifica

---

#### **Tarea 3.6: Unir certificados (servidor + CA intermedia + CA raíz)**
```yaml
- name: Leer contenido de los certificados individuales
  ansible.builtin.slurp:
    src: "{{ item }}"
  register: cert_contents
  loop:
    - "{{ cluster.cert_file_crt }}"
    - "{{ cluster.ca_intermedia_file }}"
    - "{{ cluster.ca_raiz_file }}"

- name: Unir certificados (servidor + CA intermedia + CA raíz) en archivo .pem
  ansible.builtin.copy:
    content: "{{ cert_contents.results | map(attribute='content') | map('b64decode') | join('') }}"
    dest: "{{ cluster.cert_file_combined }}"
    mode: '0600'
```

**¿Qué hace?**
- **Lee cada archivo de certificado** usando el módulo nativo `ansible.builtin.slurp`
- **Concatena los contenidos** usando filtros de Ansible (`map`, `b64decode`, `join`)
- **Crea el archivo combinado** usando `ansible.builtin.copy` con el contenido concatenado
- Orden: Certificado del servidor + CA intermedia + CA raíz
- Establece permisos `0600` automáticamente

**¿Qué modifica?**
- ✅ **Crea un archivo temporal en el sistema local**
  - Ruta: `/tmp/cluster1-cert-combined.pem` (ejemplo)
  - Contenido: Certificado servidor + CA intermedia + CA raíz concatenados
  - Permisos: `0600` (solo lectura para el propietario)

**Ejemplo del comando equivalente:**
```bash
cat apps_uatocp_imss_gob_mx.crt CA_Intermedia.cer CA_Raiz.crt > ocpuatcrt.pem
```

**💡 Importante:**
- ✅ **Usa módulos nativos de Ansible** (no `shell`)
- ✅ **Más portable y seguro** que usar comandos del sistema
- ✅ **Mejor manejo de errores** integrado
- El orden de concatenación es crítico: servidor primero, luego intermedia, luego raíz
- Este archivo combinado se usará para crear el Secret TLS y el ConfigMap

---

#### **Tarea 3.7: Validar el nuevo certificado combinado**
```yaml
- name: Validar el nuevo certificado combinado antes de actualizar
  community.crypto.x509_certificate_info:
    path: "{{ cluster.cert_file_combined }}"
  register: new_cert_info
```

**¿Qué hace?**
- Lee el archivo del certificado combinado (.pem)
- Extrae información del certificado del servidor (primer certificado en la cadena)
- Valida que el archivo existe y es un certificado válido

**¿Qué modifica?**
- ❌ No modifica nada, solo valida

---

#### **Tarea 3.8: Validar entidades certificantes**
```yaml
- name: Leer contenido del archivo combinado para validar entidades certificantes
  ansible.builtin.slurp:
    src: "{{ cluster.cert_file_combined }}"
  register: combined_cert_content

- name: Contar certificados en el archivo combinado
  ansible.builtin.set_fact:
    cert_count: "{{ (combined_cert_content.content | b64decode | regex_findall('-----BEGIN CERTIFICATE-----') | length) | int }}"

- name: Validar que hay al menos 3 certificados (servidor + intermedia + raíz)
  ansible.builtin.fail:
    msg: "Se esperaban al menos 3 certificados (servidor + CA intermedia + CA raíz), se encontraron {{ cert_count }}"
  when: cert_count | int < 3

- name: Obtener información del primer certificado (servidor) para validación
  community.crypto.x509_certificate_info:
    path: "{{ cluster.cert_file_combined }}"
  register: first_cert_info
```

**¿Qué hace?**
- **Lee el contenido del archivo combinado** usando `ansible.builtin.slurp`
- **Cuenta los certificados** usando filtros de Ansible (`regex_findall` para buscar `-----BEGIN CERTIFICATE-----`)
- **Valida que hay al menos 3 certificados** (servidor + intermedia + raíz)
- **Obtiene información del primer certificado** (servidor) para validación adicional

**¿Qué modifica?**
- ❌ No modifica nada, solo valida

**Ejemplo:**
- Si encuentra 3 certificados: ✅ Continúa
- Si encuentra menos de 3: ❌ Falla con error

**💡 Importante:**
- ✅ **Usa módulos nativos de Ansible** (no `shell` ni `grep`)
- ✅ **Más portable** que comandos del sistema
- ✅ **Mejor integración** con el ecosistema de Ansible

---

#### **Tarea 3.9: Validar que el nuevo certificado no esté vencido**

---

#### **Tarea 3.5: Validar que el nuevo certificado no esté vencido**
```yaml
- name: Validar que el nuevo certificado no esté vencido
  ansible.builtin.fail:
    msg: "El nuevo certificado {{ cluster.cert_file_new }} ya está vencido."
  when: new_cert_info.not_after is defined and 
        (new_cert_info.not_after | to_datetime('%Y%m%d%H%M%SZ')).timestamp() | int 
        < (current_timestamp | int)
```

**¿Qué hace?**
- Compara la fecha de expiración del nuevo certificado con la fecha actual
- Si el certificado ya está vencido, detiene la ejecución

**¿Qué modifica?**
- ❌ No modifica nada, solo valida

**Ejemplo:**
- Certificado válido hasta 2025-12-31, hoy es 2024-12-16 → ✅ Continúa
- Certificado válido hasta 2023-12-31, hoy es 2024-12-16 → ❌ Falla

---

#### **Tarea 3.6: Validar validez mínima del nuevo certificado**
```yaml
- name: Validar que el nuevo certificado sea válido por al menos 30 días
  ansible.builtin.fail:
    msg: "El nuevo certificado debe ser válido por al menos 30 días."
  when: new_cert_info.not_after is defined and 
        ((new_cert_info.not_after | to_datetime('%Y%m%d%H%M%SZ')).timestamp() | int 
         - (current_timestamp | int)) 
        < (30 * 24 * 3600)
```

**¿Qué hace?**
- Verifica que el nuevo certificado sea válido por al menos 30 días (configurable)
- Evita aplicar certificados que expiran muy pronto

**¿Qué modifica?**
- ❌ No modifica nada, solo valida

**Ejemplo:**
- Certificado válido por 60 días → ✅ Continúa
- Certificado válido por 10 días → ❌ Falla

---

#### **Tarea 3.7: Verificar que la llave privada existe**
```yaml
- name: Verificar que la llave privada existe
  ansible.builtin.stat:
    path: "{{ cluster.key_file_new }}"
  register: key_file_stat
```

**¿Qué hace?**
- Verifica que el archivo de la llave privada existe en el sistema local

**¿Qué modifica?**
- ❌ No modifica nada, solo verifica

---

#### **Tarea 3.8: Validar correspondencia certificado-llave**
```yaml
- name: Obtener información del certificado para validar correspondencia con llave
  community.crypto.x509_certificate_info:
    path: "{{ cluster.cert_file_combined }}"
  register: cert_info_for_match

- name: Obtener información de la llave privada
  community.crypto.openssl_privatekey_info:
    path: "{{ cluster.key_file_new }}"
  register: key_info_for_match

- name: Validar correspondencia usando fingerprints SHA256 (método principal y más confiable)
  ansible.builtin.assert:
    that:
      - cert_info_for_match.public_key_fingerprints.sha256 == key_info_for_match.public_key_fingerprints.sha256
    fail_msg: "El certificado y la llave privada NO corresponden. Los fingerprints SHA256 no coinciden."
    success_msg: "✅ Validación: Certificado y llave privada CORRESPONDEN (fingerprints SHA256 coinciden)."
```

**¿Qué hace?**
- **Obtiene información del certificado** usando `community.crypto.x509_certificate_info`
- **Obtiene información de la llave privada** usando `community.crypto.openssl_privatekey_info`
- **Compara los fingerprints SHA256** de ambos para validar correspondencia
- Si coinciden, significa que el certificado y la llave corresponden
- Si no coinciden, detiene la ejecución

**¿Qué modifica?**
- ❌ No modifica nada, solo valida

**Ejemplo:**
- Certificado y llave corresponden (fingerprints SHA256 coinciden) → ✅ Continúa
- Certificado y llave NO corresponden → ❌ Falla con error

**💡 ¿Por qué es importante?**
- Evita aplicar un certificado con una llave privada incorrecta
- Esto causaría que el servidor no pueda usar el certificado
- Resultado: servicios HTTPS dejarían de funcionar

**💡 Ventajas del método actual:**
- ✅ **Usa módulos nativos de Ansible** (no `shell` ni `openssl` directamente)
- ✅ **Más confiable**: Los fingerprints SHA256 son únicos y precisos
- ✅ **Mejor integración** con el ecosistema de Ansible
- ✅ **Más portable** que comandos del sistema operativo

---

#### **Tarea 3.10: Analizar cadena de certificados**
```yaml
- name: Analizar cadena de certificados en el archivo combinado
  ansible.builtin.set_fact:
    cert_chain_info: "{{ cert_count | default(0) | int }}"
    has_chain: "{{ (cert_count | default(0) | int) >= 3 }}"
```

**¿Qué hace?**
- **Usa la variable `cert_count`** ya calculada en la tarea 3.8
- **Analiza la cadena de certificados** para determinar si está completa
- Valida que la cadena está completa (servidor + intermedia + raíz)

**¿Qué modifica?**
- ❌ No modifica nada, solo analiza

**Ejemplo:**
- Archivo con 3 certificados → `cert_chain_info = 3`, `has_chain = true` ✅

**💡 Importancia:**
- La cadena completa mejora la compatibilidad con navegadores
- Algunos clientes requieren la cadena completa para validar correctamente
- ✅ **Usa datos ya calculados** (no vuelve a leer el archivo)
- ✅ **Más eficiente** que ejecutar comandos múltiples veces

---

#### **Tarea 3.11: Crear o actualizar ConfigMap con certificado combinado** ⚠️ **MODIFICA EL CLUSTER**
```yaml
- name: Obtener ConfigMap existente (si existe) para preservar configuración
  kubernetes.core.k8s_info:
    kind: ConfigMap
    name: "{{ configmap_name }}"
    namespace: openshift-config
  register: existing_configmap
  failed_when: false

- name: Crear o actualizar ConfigMap con el certificado combinado preservando configuración existente
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: ConfigMap
      metadata: "{{ configmap_metadata }}"  # Preserva labels y annotations existentes
      data: "{{ configmap_data }}"  # Preserva datos existentes y agrega/actualiza el certificado
```

**¿Qué hace?**
- **Primero obtiene el ConfigMap existente** (si existe) para preservar su configuración
- Si el ConfigMap existe:
  - Preserva todos los datos existentes en el ConfigMap
  - Preserva labels y annotations existentes
  - Agrega o actualiza el certificado combinado (.pem)
- Si el ConfigMap no existe:
  - Crea un nuevo ConfigMap con el certificado combinado
- El nombre del ConfigMap incluye la fecha actual (ejemplo: `custom-ca-20241225`)

**¿Qué modifica?**
- ✅ **MODIFICA EL CLUSTER DE OPENSHIFT**
  - Recurso: `ConfigMap`
  - Namespace: `openshift-config`
  - Nombre: `custom-ca-YYYYMMDD` (con fecha actual)
  - Contenido: Certificado combinado en formato PEM
  - **Preserva**: Labels, annotations y otros datos existentes en el ConfigMap

**Ejemplo de lo que se crea o actualiza:**
```yaml
# Si el ConfigMap ya existía con otros datos:
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-ca-20241225
  namespace: openshift-config
  labels:
    app: custom-ca  # ✅ Preservado
    version: v1     # ✅ Preservado
  annotations:
    description: "CA personalizada"  # ✅ Preservado
data:
  otro-archivo.pem: |  # ✅ Preservado
    ... (contenido existente)
  custom-ca-20241225.pem: |  # ✅ Agregado/Actualizado
    -----BEGIN CERTIFICATE-----
    ... (certificado servidor)
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ... (CA intermedia)
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ... (CA raíz)
    -----END CERTIFICATE-----

# Si el ConfigMap no existía:
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-ca-20241225
  namespace: openshift-config
data:
  custom-ca-20241225.pem: |
    -----BEGIN CERTIFICATE-----
    ... (certificado servidor)
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ... (CA intermedia)
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ... (CA raíz)
    -----END CERTIFICATE-----
```

**💡 Equivalente manual:**
```bash
# Si el ConfigMap ya existe, primero obtenerlo:
oc get configmap custom-ca-uat5 -n openshift-config -o yaml > existing-configmap.yaml

# Luego actualizar preservando datos existentes:
oc create configmap custom-ca-uat5 \
     --from-file=ocpuatcrt.pem=/root/cert-12-25/ocpuatcrt.pem \
     --from-file=otro-archivo.pem=/ruta/existente.pem \
     -n openshift-config \
     --dry-run=client -o yaml | oc apply -f -
```

**💡 Importante:**
- ✅ **Preserva configuración existente**: No se pierden labels, annotations ni otros datos
- ✅ **Idempotente**: Puede ejecutarse múltiples veces sin perder datos
- ✅ **Seguro**: Solo agrega/actualiza el certificado, no elimina otros datos

---

#### **Tarea 3.12: Aplicar patch al proxy/cluster** ⚠️ **MODIFICA EL CLUSTER**
```yaml
- name: Aplicar patch al proxy/cluster para usar la CA personalizada
  kubernetes.core.k8s:
    definition:
      apiVersion: config.openshift.io/v1
      kind: Proxy
      metadata:
        name: cluster
      spec:
        trustedCA:
          name: "{{ configmap_name }}"
```

**¿Qué hace?**
- Actualiza el recurso `Proxy/cluster` de OpenShift
- Configura el cluster para confiar en la CA personalizada del ConfigMap
- Esto permite que el cluster valide certificados emitidos por esta CA

**¿Qué modifica?**
- ✅ **MODIFICA EL CLUSTER DE OPENSHIFT**
  - Recurso: `Proxy` (CRD de OpenShift)
  - Nombre: `cluster`
  - Campo modificado:
    - `spec.trustedCA.name`: Referencia al ConfigMap de CA personalizada

**Ejemplo de lo que se modifica:**
```yaml
# ANTES:
apiVersion: config.openshift.io/v1
kind: Proxy
metadata:
  name: cluster
spec:
  # ... otros campos ...

# DESPUÉS:
apiVersion: config.openshift.io/v1
kind: Proxy
metadata:
  name: cluster
spec:
  trustedCA:
    name: custom-ca-20241225  # ConfigMap creado anteriormente
  # ... otros campos ...
```

**💡 Equivalente manual:**
```bash
oc patch proxy/cluster \
     --type=merge \
     --patch='{"spec":{"trustedCA":{"name":"custom-ca-uat5"}}}'
```

**⚠️ Importante:**
- Esta tarea debe ejecutarse ANTES de crear el Secret TLS
- El cluster necesita confiar en la CA antes de usar certificados emitidos por ella

---

#### **Tarea 3.13: Crear/Actualizar Secret TLS en Kubernetes** ⚠️ **MODIFICA EL CLUSTER**
```yaml
- name: Crear secreto TLS para el certificado de ingreso con nombre que incluye fecha
  kubernetes.core.k8s:
    definition:
      apiVersion: v1
      kind: Secret
      metadata:
        name: "{{ secret_name_with_date }}"
        namespace: "{{ cluster.namespace_ingress }}"
      type: kubernetes.io/tls
      data:
        tls.crt: "{{ lookup('file', cluster.cert_file_combined) | b64encode }}"
        tls.key: "{{ lookup('file', cluster.key_file_new) | b64encode }}"
```

**¿Qué hace?**
- Lee el certificado combinado (.pem) y la llave privada desde archivos locales
- Codifica ambos en base64 (formato requerido por Kubernetes)
- Crea o actualiza el Secret TLS en el cluster de OpenShift
- El Secret se crea/actualiza en el namespace `openshift-ingress`
- **El nombre del Secret incluye la fecha actual** (ejemplo: `router-certs-20241225`)

**¿Qué modifica?**
- ✅ **MODIFICA EL CLUSTER DE OPENSHIFT**
  - Recurso: `Secret` de tipo `kubernetes.io/tls`
  - Namespace: `openshift-ingress` (o el especificado)
  - Nombre: `router-certs-YYYYMMDD` (con fecha actual)
  - Campos modificados:
    - `data.tls.crt`: Certificado combinado en base64 (servidor + CA intermedia + CA raíz)
    - `data.tls.key`: Nueva llave privada en base64

**Ejemplo de lo que se crea en el cluster:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: router-certs-20241225
  namespace: openshift-ingress
type: kubernetes.io/tls
data:
  tls.crt: "LS0tLS1CRUdJTi...NUEVO..."    # Certificado combinado (servidor + CA intermedia + CA raíz)
  tls.key: "LS0tLS1CRUdJTi...NUEVO..."    # Llave privada
```

**💡 Equivalente manual:**
```bash
oc create secret tls router-certs-uat2 \
     --cert=/root/cert-12-25/ocpuatcrt.pem \
     --key=/root/cert-12-25/apps_uatocp_imss_gob_mx_sinpassw.key \
     -n openshift-ingress
```

**💡 Importante:**
- Si el Secret no existe, se crea
- Si el Secret ya existe, se actualiza (reemplaza los valores)
- El nombre con fecha permite tener múltiples versiones de certificados
- El certificado usado es el archivo combinado (.pem) que incluye la cadena completa

---

#### **Tarea 3.11: Verificar existencia del secreto**
```yaml
- name: Verificar existencia del secreto
  kubernetes.core.k8s_info:
    kind: Secret
    name: "{{ cluster.secret_name }}"
    namespace: "{{ cluster.namespace_ingress }}"
    host: "{{ cluster.api_url }}"
    api_key: "{{ cluster.token }}"
  register: secret_check
  failed_when: secret_check.resources | length == 0
```

**¿Qué hace?**
- Verifica que el Secret se creó/actualizó correctamente
- Si no existe, detiene la ejecución con error

**¿Qué modifica?**
- ❌ No modifica nada, solo verifica

---

#### **Tarea 3.14: Actualizar IngressController** ⚠️ **MODIFICA EL CLUSTER**
```yaml
- name: Actualizar Ingress Controller con el certificado que incluye fecha
  kubernetes.core.k8s:
    state: present
    kind: IngressController
    api_version: operator.openshift.io/v1
    name: "{{ cluster.ingress_controller_name | default('default') }}"
    namespace: "{{ cluster.namespace_ingress_operator | default('openshift-ingress-operator') }}"
    definition:
      spec:
        defaultCertificate:
          name: "{{ secret_name_with_date }}"
```

**¿Qué hace?**
- Actualiza el recurso `IngressController` de OpenShift
- Configura el IngressController para usar el Secret TLS con nombre que incluye fecha
- Esto hace que OpenShift use el nuevo certificado para todas las rutas
- **El nombre del Secret incluye la fecha actual** (ejemplo: `router-certs-20241225`)

**¿Qué modifica?**
- ✅ **MODIFICA EL CLUSTER DE OPENSHIFT**
  - Recurso: `IngressController` (CRD de OpenShift)
  - Namespace: `openshift-ingress-operator`
  - Nombre: `default` (o el especificado)
  - Campo modificado:
    - `spec.defaultCertificate.name`: Referencia al Secret TLS con fecha

**Ejemplo de lo que se modifica:**
```yaml
# ANTES:
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  defaultCertificate:
    name: router-certs-20241101  # Secret anterior
  # ... otros campos ...

# DESPUÉS:
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  defaultCertificate:
    name: router-certs-20241225  # Nuevo Secret con fecha actual
  # ... otros campos ...
```

**💡 Equivalente manual:**
```bash
oc patch ingresscontroller.operator default \
     --type=merge -p \
     '{"spec":{"defaultCertificate": {"name": "router-certs-uat2"}}}' \
     -n openshift-ingress-operator
```

**💡 Importante:**
- El IngressController ahora referencia el nuevo Secret con fecha
- OpenShift detecta el cambio y recarga automáticamente
- Los pods del router de OpenShift se reinician para usar el nuevo certificado
- El nombre con fecha permite rastrear cuándo se aplicó cada certificado

---

#### **Tarea 3.13: Obtener información del recurso ingresses.config/cluster**
```yaml
- name: Obtener información del recurso ingresses.config/cluster
  kubernetes.core.k8s_info:
    api_version: config.openshift.io/v1
    kind: Ingress
    name: "cluster"
    host: "{{ cluster.api_url }}"
    api_key: "{{ cluster.token }}"
  register: ingress_config_info
```

**¿Qué hace?**
- Obtiene la configuración global de Ingress del cluster
- Extrae información como el dominio base del cluster

**¿Qué modifica?**
- ❌ No modifica nada, solo lee información

**Ejemplo de datos obtenidos:**
```yaml
ingress_config_info:
  resources:
    - spec:
        domain: apps.cluster-qbfmq.dynamic.redhatworkshops.io
```

---

## 📝 Resumen de Modificaciones

### **Archivos Locales Creados/Modificados:**

1. **Archivo temporal del certificado actual:**
   - Ruta: `/tmp/cluster1-ingress-cert.pem` (ejemplo)
   - Contenido: Certificado actual extraído del cluster
   - Permisos: `0600`
   - Se crea en: Tarea 2.3

2. **Archivo de backup del Secret:**
   - Ruta: `/tmp/ingress-backup-cluster1.yaml` (ejemplo)
   - Contenido: YAML completo del Secret antes de modificarlo
   - Permisos: `0600`
   - Se crea en: Tarea 3.3

3. **Archivo combinado de certificados:**
   - Ruta: `/tmp/cluster1-cert-combined.pem` (ejemplo)
   - Contenido: Certificado servidor + CA intermedia + CA raíz concatenados
   - Permisos: `0600`
   - Se crea en: Tarea 3.6

### **Recursos del Cluster Modificados:**

1. **ConfigMap (CA personalizada):**
   - Namespace: `openshift-config`
   - Nombre: `custom-ca-YYYYMMDD` (con fecha actual, ejemplo: `custom-ca-20241225`)
   - Campos creados:
     - `data.{configmap_name}.pem`: Certificado combinado (servidor + CA intermedia + CA raíz)
   - Se crea en: Tarea 3.11

2. **Proxy (config.openshift.io/v1):**
   - Nombre: `cluster`
   - Campo modificado:
     - `spec.trustedCA.name`: Referencia al ConfigMap de CA personalizada
   - Se modifica en: Tarea 3.12

3. **Secret TLS (`kubernetes.io/tls`):**
   - Namespace: `openshift-ingress`
   - Nombre: `router-certs-YYYYMMDD` (con fecha actual, ejemplo: `router-certs-20241225`)
   - Campos modificados:
     - `data.tls.crt`: Certificado combinado en base64 (servidor + CA intermedia + CA raíz)
     - `data.tls.key`: Nueva llave privada en base64
   - Se modifica en: Tarea 3.13

4. **IngressController (OpenShift CRD):**
   - Namespace: `openshift-ingress-operator`
   - Nombre: `default` (o el especificado)
   - Campo modificado:
     - `spec.defaultCertificate.name`: Referencia al Secret TLS con fecha
   - Se modifica en: Tarea 3.14

---

## 🔄 Flujo de Ejecución Completo con Ejemplo

### **Escenario:**
- Cluster: `cluster1`
- Certificado actual expira en: 30 días
- Nuevo certificado: `/path/to/new-cert.pem`
- Nueva llave: `/path/to/new-key.pem`

### **Ejecución Paso a Paso:**

```
1. [main.yml] Debug - Mostrar clusters disponibles
   → Muestra: [cluster1]

2. [main.yml] Procesar cada cluster
   → Itera sobre cluster1

3. [process_cluster.yml] Obtener secreto TLS
   → Lee Secret "cert-manager-ingress-cert" del cluster

4. [process_cluster.yml] Validar existencia
   → ✅ Secret existe

5. [process_cluster.yml] Extraer certificado
   → Crea: /tmp/cluster1-ingress-cert.pem

6. [process_cluster.yml] Obtener información
   → Detecta: Expira en 30 días

7. [process_cluster.yml] Calcular días
   → days_to_expiry = 30

8. [process_cluster.yml] Decisión
   → 30 < 60 → ✅ Ejecuta replace_certificate.yml

9. [replace_certificate.yml] Backup del secreto
   → Crea: /tmp/ingress-backup-cluster1.yaml

10. [replace_certificate.yml] Obtener fecha actual
    → current_date = 20241225

11. [replace_certificate.yml] Definir nombres con fecha
    → configmap_name = custom-ca-20241225
    → secret_name_with_date = router-certs-20241225

12. [replace_certificate.yml] Verificar archivos de certificados
    → ✅ Certificado servidor, CA intermedia y CA raíz existen

13. [replace_certificate.yml] Unir certificados
    → ✅ Crea: /tmp/cluster1-cert-combined.pem
    → Contenido: servidor + CA intermedia + CA raíz

14. [replace_certificate.yml] Validar certificado combinado
    → ✅ Certificado válido, expira en 365 días

15. [replace_certificate.yml] Validar entidades certificantes
    → ✅ 3 certificados encontrados (servidor + intermedia + raíz)

16. [replace_certificate.yml] Validar no vencido
    → ✅ No está vencido

17. [replace_certificate.yml] Validar validez mínima
    → ✅ Válido por más de 30 días

18. [replace_certificate.yml] Verificar llave privada
    → ✅ Llave existe

19. [replace_certificate.yml] Validar correspondencia certificado-llave
    → ✅ Certificado y llave corresponden (fingerprints SHA256 coinciden)

20. [replace_certificate.yml] Crear ConfigMap
    → ✅ MODIFICA EL CLUSTER
    → ConfigMap custom-ca-20241225 creado en openshift-config

21. [replace_certificate.yml] Aplicar patch al proxy/cluster
    → ✅ MODIFICA EL CLUSTER
    → Proxy configurado para confiar en la CA personalizada

22. [replace_certificate.yml] Crear/Actualizar Secret
    → ✅ MODIFICA EL CLUSTER
    → Secret router-certs-20241225 creado con certificado combinado

23. [replace_certificate.yml] Verificar Secret
    → ✅ Secret existe y está actualizado

24. [replace_certificate.yml] Actualizar IngressController
    → ✅ MODIFICA EL CLUSTER
    → IngressController configurado con router-certs-20241225

25. [replace_certificate.yml] Obtener dominio del cluster
    → Lee: apps.cluster-qbfmq.dynamic.redhatworkshops.io
```

---

## ⚠️ Puntos Críticos y Consideraciones

### **1. Backup Automático:**
- ✅ El role crea un backup automático antes de modificar
- 📁 Ubicación: `/tmp/ingress-backup-{cluster-name}.yaml`
- 🔄 Permite rollback manual si es necesario

### **2. Validaciones Múltiples:**
- ✅ Verifica que el nuevo certificado no esté vencido
- ✅ Verifica validez mínima (30 días por defecto)
- ✅ Verifica correspondencia certificado-llave usando fingerprints SHA256 (método confiable)
- ✅ Verifica existencia de archivos
- ✅ Valida que hay al menos 3 certificados en la cadena (servidor + intermedia + raíz)
- ✅ Usa módulos nativos de Ansible para todas las validaciones (no comandos shell)

### **3. Modificaciones en el Cluster:**
- ⚠️ **El role MODIFICA recursos en el cluster de OpenShift**
- ⚠️ Los cambios son inmediatos
- ⚠️ Los pods del router se reinician automáticamente
- ⚠️ Puede haber una breve interrupción del servicio (segundos)
- ⚠️ Se crea un ConfigMap en `openshift-config` con la CA personalizada
- ⚠️ Se actualiza el recurso `Proxy/cluster` para confiar en la CA personalizada
- ⚠️ Los nombres de recursos incluyen la fecha actual para rastreabilidad

### **4. Archivos Temporales:**
- Los archivos temporales se crean en `/tmp/`
- Se pueden eliminar manualmente después de la ejecución
- No se eliminan automáticamente por el role

### **5. Permisos Requeridos:**
- El token debe tener permisos para:
  - Leer Secrets en `openshift-ingress`
  - Crear/Actualizar Secrets en `openshift-ingress`
  - Leer/Actualizar IngressController en `openshift-ingress-operator`

---

## 🎯 Conclusión

El role `certificado` es un sistema automatizado que:

1. **Analiza** certificados existentes en clústeres de OpenShift
2. **Detecta** certificados próximos a expirar (< 60 días)
3. **Valida** nuevos certificados antes de aplicarlos usando módulos nativos de Ansible
4. **Une certificados** (servidor + CA intermedia + CA raíz) usando módulos nativos
5. **Crea backups** automáticos antes de modificar
6. **Crea ConfigMap** con la CA personalizada preservando configuración existente
7. **Aplica patch** al proxy/cluster para confiar en la CA personalizada
8. **Actualiza** el Secret TLS en el cluster con nombre que incluye fecha
9. **Configura** el IngressController para usar el nuevo Secret

**Modifica:**
- ✅ ConfigMap en el namespace `openshift-config` (CA personalizada)
- ✅ Proxy/cluster (config.openshift.io/v1) para confiar en la CA personalizada
- ✅ Secret TLS en el namespace `openshift-ingress` (con nombre que incluye fecha)
- ✅ IngressController en el namespace `openshift-ingress-operator`
- ✅ Archivos temporales en el sistema local (backups y certificados combinados)

**No modifica:**
- ❌ Otros recursos del cluster
- ❌ Configuraciones fuera de certificados TLS
- ❌ Archivos fuera de `/tmp/` (excepto backups configurados)

**Características técnicas:**
- ✅ **Usa módulos nativos de Ansible** (no comandos `shell`)
- ✅ **Portable y seguro** - funciona en diferentes sistemas operativos
- ✅ **Idempotente** - puede ejecutarse múltiples veces sin efectos secundarios
- ✅ **Preserva configuración existente** en ConfigMaps
- ✅ **Validación robusta** usando fingerprints SHA256

