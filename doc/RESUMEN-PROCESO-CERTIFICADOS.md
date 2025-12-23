# 📋 Resumen del Proceso de Gestión de Certificados TLS en OpenShift

## 🎯 Objetivo
Automatizar la gestión y renovación de certificados TLS en clusters de OpenShift, verificando su expiración y reemplazándolos cuando sea necesario.

---

## 📁 Estructura del Proceso

### 1. **Playbook Principal** (`playbook-with-role.yml`)
### 2. **Role Principal** (`roles/certificado/tasks/main.yml`)
### 3. **Procesamiento por Cluster** (`roles/certificado/tasks/process_cluster.yml`)
### 4. **Reemplazo de Certificados** (`roles/certificado/tasks/replace_certificate.yml`)

---

## 🔄 Flujo Completo del Proceso

### **FASE 1: Inicialización** (`playbook-with-role.yml`)

#### Paso 1.1: Configuración Inicial
- **Host**: `localhost`
- **Conexión**: Local
- **Gather Facts**: `true` (necesario para fechas y timestamps)
- **Define**: `role_path` para que las variables puedan usarlo

#### Paso 1.2: Carga de Variables
- Carga `vars.yml` que contiene:
  - Lista de clusters a procesar
  - Configuración de certificados (archivos, rutas, nombres)
  - Umbral de días para reemplazo (`replacement_threshold_days: 60`)

#### Paso 1.3: Ejecución del Role
- Ejecuta el role `certificado` para cada cluster definido

---

### **FASE 2: Procesamiento por Cluster** (`process_cluster.yml`)

Este proceso se ejecuta **una vez por cada cluster** definido en `vars.yml`.

#### Paso 2.1: Obtener Secreto TLS Actual
- **Acción**: Consulta el Secret TLS existente en el cluster
- **Recurso**: `Secret` de tipo `kubernetes.io/tls`
- **Namespace**: `openshift-ingress` (configurable)
- **Nombre**: Definido en `cluster.secret_name` (ej: `cert-manager-ingress-cert`)
- **Resultado**: Obtiene el certificado actual del cluster

#### Paso 2.2: Validar Existencia del Secreto
- **Validación**: Verifica que el secreto existe
- **Si no existe**: Falla con mensaje descriptivo
- **Si existe**: Continúa el proceso

#### Paso 2.3: Analizar Certificado Actual
- **Acción**: Lee el certificado directamente del secreto (sin archivos temporales)
- **Módulo**: `community.crypto.x509_certificate_info`
- **Extrae**:
  - Fecha de expiración (`not_after`)
  - Información del certificado

#### Paso 2.4: Calcular Días Restantes
- **Cálculo**: 
  ```
  días_restantes = (fecha_expiración - fecha_actual) / 86400
  ```
- **Timestamp actual**: Usa `ansible_date_time.epoch` o fallback con `date +%s`
- **Muestra**: Días restantes hasta el vencimiento

#### Paso 2.5: Decisión de Reemplazo
- **Condición**: Si `días_restantes < replacement_threshold_days` (por defecto 60 días)
- **Acción**: 
  - ✅ **SÍ**: Ejecuta `replace_certificate.yml`
  - ❌ **NO**: No hace nada, certificado aún válido
- **Nota**: La condición está comentada por defecto (fuerza reemplazo siempre)

---

### **FASE 3: Reemplazo de Certificados** (`replace_certificate.yml`)

Esta fase solo se ejecuta si el certificado necesita ser reemplazado.

#### **3.1. PREPARACIÓN**

##### Paso 3.1.1: Obtener Fecha Actual
- **Formato**: `YYYYMMDD` (ej: `20251223`)
- **Fuente**: `ansible_date_time.date` o fallback con `date +%Y%m%d`

##### Paso 3.1.2: Definir Nombres de Recursos
- **ConfigMap**: `{configmap_name_prefix}-{fecha}` (ej: `custom-ca-dr-ocp-20251223`)
- **Secret**: `{secret_name_prefix}-{fecha}` (ej: `router-certs-dr-ocp-20251223`)
- **Propósito**: Cada ejecución crea recursos nuevos (no sobrescribe)

---

#### **3.2. VALIDACIÓN DE ARCHIVOS**

##### Paso 3.2.1: Verificar Existencia de Archivos
- **Archivos requeridos**:
  1. `cert_file_crt` - Certificado del servidor (wildcard)
  2. `ca_intermedia_file` - CA Intermedia
  3. `ca_raiz_file` - CA Raíz
  4. `key_file_new` - Llave privada
- **Acción**: Verifica que todos existan
- **Si falta alguno**: Falla con mensaje descriptivo

##### Paso 3.2.2: Leer Contenido de Certificados
- **Módulo**: `ansible.builtin.slurp`
- **Lee**: Los 3 archivos de certificados (servidor, intermedia, raíz)

---

#### **3.3. COMBINACIÓN DE CERTIFICADOS**

##### Paso 3.3.1: Unir Certificados
- **Orden de concatenación**:
  1. Certificado del servidor (`cert_file_crt`)
  2. CA Intermedia (`ca_intermedia_file`)
  3. CA Raíz (`ca_raiz_file`)
- **Archivo resultante**: `cert_file_combined` (ej: `cert-combined.crt`)
- **Formato**: PEM (texto plano con `-----BEGIN CERTIFICATE-----`)

##### Paso 3.3.2: Validar Certificado Combinado
- **Validación**: 
  - Verifica que el certificado es válido
  - Extrae información (subject, issuer, fechas)
  - Cuenta certificados en la cadena (debe ser ≥ 3)

##### Paso 3.3.3: Validar Cadena Completa
- **Verifica**: Que hay al menos 3 certificados (servidor + intermedia + raíz)
- **Muestra**: Información del primer certificado (servidor)

---

#### **3.4. VALIDACIÓN DEL NUEVO CERTIFICADO**

##### Paso 3.4.1: Calcular Días Restantes del Nuevo Certificado
- **Cálculo**: Días hasta la expiración del nuevo certificado
- **Muestra**: Información completa (subject, issuer, fechas válidas)

##### Paso 3.4.2: Validar que No Esté Vencido
- **Validación**: El nuevo certificado debe estar vigente
- **Si está vencido**: Falla el proceso

##### Paso 3.4.3: Validar Validez Mínima
- **Validación**: El certificado debe ser válido por al menos 30 días (configurable)
- **Propósito**: Asegurar que el certificado no expire pronto

---

#### **3.5. VALIDACIÓN CERTIFICADO-LLAVE**

##### Paso 3.5.1: Verificar Existencia de Llave
- **Archivo**: `key_file_new`
- **Si no existe**: Falla el proceso

##### Paso 3.5.2: Validar Correspondencia
- **Método**: Compara fingerprints SHA256 del certificado y la llave
- **Módulos**:
  - `community.crypto.x509_certificate_info` (certificado)
  - `community.crypto.openssl_privatekey_info` (llave)
- **Validación**: Los fingerprints SHA256 deben coincidir
- **Si no coinciden**: Falla con mensaje descriptivo

---

#### **3.6. CREACIÓN DE CONFIGMAP**

##### Paso 3.6.1: Preparar Datos del ConfigMap
- **Contenido**: Certificado combinado completo
- **Clave**: `ca-bundle.crt`
- **Fuente**: Archivo `cert_file_combined`

##### Paso 3.6.2: Preparar Metadata
- **Nombre**: `{configmap_name_prefix}-{fecha}` (ej: `custom-ca-dr-ocp-20251223`)
- **Namespace**: `openshift-config`
- **Nota**: Siempre crea uno nuevo (no actualiza existentes)

##### Paso 3.6.3: Crear ConfigMap
- **Módulo**: `kubernetes.core.k8s`
- **Acción**: Crea nuevo ConfigMap con el certificado combinado
- **Resultado**: ConfigMap nuevo con fecha en el nombre

---

#### **3.7. ACTUALIZACIÓN DEL PROXY/CLUSTER**

##### Paso 3.7.1: Aplicar Patch al Proxy
- **Recurso**: `Proxy/cluster` (recurso global de OpenShift)
- **Modificación**: `spec.trustedCA.name` → apunta al nuevo ConfigMap
- **Propósito**: Hace que el cluster confíe en la CA personalizada
- **Efecto**: El cluster usa el nuevo ConfigMap para validar certificados

---

#### **3.8. CREACIÓN DE SECRET TLS**

##### Paso 3.8.1: Leer Contenido
- **Lee**: 
  - Certificado combinado (`cert_file_combined`)
  - Llave privada (`key_file_new`)

##### Paso 3.8.2: Normalizar Contenido
- **Acción**: Elimina saltos de línea al final (`rstrip`)
- **Aplica a**: Certificado y llave
- **Propósito**: Contenido limpio sin espacios/saltos de línea finales

##### Paso 3.8.3: Crear Secret TLS
- **Nombre**: `{secret_name_prefix}-{fecha}` (ej: `router-certs-dr-ocp-20251223`)
- **Namespace**: `openshift-ingress`
- **Tipo**: `kubernetes.io/tls`
- **Datos**:
  - `tls.crt`: Certificado combinado (base64, sin saltos de línea finales)
  - `tls.key`: Llave privada (base64, sin saltos de línea finales)

##### Paso 3.8.4: Verificar Creación
- **Validación**: Verifica que el Secret fue creado exitosamente
- **Muestra**: Información del Secret creado

---

#### **3.9. ACTUALIZACIÓN DEL INGRESS CONTROLLER**

##### Paso 3.9.1: Obtener Información del IngressController
- **Recurso**: `IngressController/default`
- **Namespace**: `openshift-ingress-operator`
- **Propósito**: Obtener configuración actual

##### Paso 3.9.2: Actualizar IngressController
- **Modificación**: `spec.defaultCertificate.name` → apunta al nuevo Secret
- **Efecto**: El Ingress Controller usa el nuevo certificado para las rutas
- **Resultado**: Las aplicaciones expuestas usan el nuevo certificado TLS

##### Paso 3.9.3: Mostrar Resultado
- **Muestra**: Confirmación de actualización exitosa
- **Información**: Nombre del Secret, fecha de aplicación

---

#### **3.10. INFORMACIÓN ADICIONAL**

##### Paso 3.10.1: Obtener Dominio del Cluster
- **Recurso**: `Ingress/cluster` (configuración global)
- **Extrae**: `spec.domain`
- **Muestra**: Dominio del cluster

---

## 📊 Resumen de Recursos Creados/Modificados

### **Recursos Creados (Nuevos)**
1. ✅ **ConfigMap**: `{configmap_name_prefix}-{fecha}` en `openshift-config`
2. ✅ **Secret TLS**: `{secret_name_prefix}-{fecha}` en `openshift-ingress`

### **Recursos Modificados (Actualizados)**
1. ✅ **Proxy/cluster**: Actualiza `spec.trustedCA.name` → nuevo ConfigMap
2. ✅ **IngressController/default**: Actualiza `spec.defaultCertificate.name` → nuevo Secret

### **Recursos NO Modificados (Preservados)**
- ❌ ConfigMaps anteriores (se mantienen intactos)
- ❌ Secrets anteriores (se mantienen intactos)

---

## 🔑 Puntos Clave del Proceso

### ✅ **Características Importantes**

1. **Idempotencia**: Cada ejecución crea recursos nuevos con fecha única
2. **No Destructivo**: No elimina ni sobrescribe recursos existentes
3. **Validación Completa**: 
   - Valida archivos
   - Valida certificados
   - Valida correspondencia certificado-llave
   - Valida fechas de expiración
4. **Trazabilidad**: Nombres con fecha permiten historial de cambios
5. **Seguridad**: Valida fingerprints SHA256 para certificado-llave

### ⚠️ **Consideraciones**

1. **Umbral de Días**: Por defecto 60 días antes de expiración
2. **Forzar Reemplazo**: La condición está comentada (reemplaza siempre)
3. **Archivos Requeridos**: Todos los certificados y la llave deben existir
4. **Orden de Certificados**: Servidor → Intermedia → Raíz
5. **Normalización**: Elimina saltos de línea finales en Secret

---

## 📝 Variables Importantes

### **Variables de Cluster** (`vars.yml`)
- `api_url`: URL del API del cluster
- `token`: Token de autenticación
- `secret_name`: Nombre del Secret actual
- `cert_file_crt`: Certificado del servidor (wildcard)
- `ca_intermedia_file`: CA Intermedia
- `ca_raiz_file`: CA Raíz
- `key_file_new`: Llave privada
- `configmap_name_prefix`: Prefijo para ConfigMap
- `secret_name_prefix`: Prefijo para Secret

### **Variables Globales**
- `certificate.replacement_threshold_days`: Días antes de expiración para reemplazar (default: 60)
- `certificate.min_validity_days`: Días mínimos de validez del nuevo certificado (default: 30)

---

## 🚀 Ejecución

```bash
ansible-navigator run playbook-with-role.yml -m stdout
```

---

## 📌 Notas Finales

- El proceso es **completamente automatizado**
- **No requiere intervención manual** durante la ejecución
- Los recursos antiguos **se mantienen** para rollback si es necesario
- Cada ejecución crea recursos **nuevos con fecha única**
- El cluster **automáticamente** comienza a usar los nuevos recursos

