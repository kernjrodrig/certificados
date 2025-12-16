# Análisis: Comparación del Rol con Documentación Oficial de Red Hat

## Documentación de Referencia
[Replacing the default ingress certificate - OpenShift 4.14](https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html/security_and_compliance/configuring-certificates#replacing-default-ingress_replacing-default-ingress)

## Proceso Oficial según Red Hat

Según la documentación oficial, el proceso correcto para reemplazar el certificado del Ingress por defecto es:

### Paso 1: Crear el secreto TLS
- **Namespace**: `openshift-ingress`
- **Tipo**: `kubernetes.io/tls`
- **Datos requeridos**:
  - `tls.crt`: Certificado (base64 encoded)
  - `tls.key`: Llave privada (base64 encoded)

### Paso 2: Actualizar el IngressController
- **Recurso**: `IngressController` (API `operator.openshift.io/v1`)
- **Namespace**: `openshift-ingress-operator`
- **Nombre**: `default` (por defecto)
- **Campo a actualizar**: `spec.defaultCertificate.name` debe apuntar al nombre del secreto creado

### Paso 3: Verificación
- El operador de OpenShift detecta el cambio automáticamente
- Los pods del router se reinician automáticamente para usar el nuevo certificado

## Análisis del Rol Actual

### ✅ Lo que está CORRECTO

1. **Creación del Secreto TLS** (Líneas 21-37 de `replace_certificate.yml`)
   - ✅ Crea el secreto en el namespace correcto: `openshift-ingress`
   - ✅ Usa el tipo correcto: `kubernetes.io/tls`
   - ✅ Codifica correctamente los datos en base64
   - ✅ Usa `state: present` que crea o actualiza el secreto

2. **Actualización del IngressController** (Líneas 65-79 de `replace_certificate.yml`)
   - ✅ Usa la API correcta: `operator.openshift.io/v1`
   - ✅ Apunta al namespace correcto: `openshift-ingress-operator`
   - ✅ Actualiza el campo correcto: `spec.defaultCertificate.name`
   - ✅ Usa `state: present` para actualizar el recurso

3. **Validaciones Previas**
   - ✅ Valida que el certificado no esté vencido
   - ✅ Valida que el certificado tenga validez mínima
   - ✅ Verifica la existencia del secreto después de crearlo

### ⚠️ Posibles Mejoras (No críticas)

1. **Orden de Operaciones**
   - El rol actual: Crea secreto → Actualiza IngressController
   - Esto es correcto según la documentación oficial

2. **Manejo de Errores**
   - El rol verifica la existencia del secreto después de crearlo
   - Podría agregarse verificación del estado del IngressController después de actualizarlo

3. **Rollout del Deployment**
   - La documentación menciona que los pods se reinician automáticamente
   - El rol no verifica explícitamente el rollout, pero esto es manejado automáticamente por OpenShift

## Conclusión

### ✅ El rol está implementado CORRECTAMENTE según la documentación oficial

El proceso que sigue el rol coincide exactamente con el proceso oficial de Red Hat:

1. ✅ Crea el secreto TLS en el namespace correcto con el formato correcto
2. ✅ Actualiza el IngressController para usar el nuevo secreto
3. ✅ OpenShift maneja automáticamente el reinicio de los pods del router

### Recomendaciones Adicionales (Opcionales)

Aunque el rol funciona correctamente, se podrían agregar las siguientes mejoras opcionales:

1. **Verificación del Rollout** (Opcional)
   ```yaml
   - name: Esperar rollout del deployment del router
     kubernetes.core.k8s_info:
       kind: Deployment
       name: router-default
       namespace: openshift-ingress
     register: router_deployment
     until: router_deployment.resources[0].status.readyReplicas == router_deployment.resources[0].spec.replicas
     retries: 30
     delay: 10
   ```

2. **Verificación del Certificado en Uso** (Opcional)
   ```yaml
   - name: Verificar que el certificado está en uso
     kubernetes.core.k8s_info:
       kind: IngressController
       name: default
       namespace: openshift-ingress-operator
     register: ic_status
     failed_when: ic_status.resources[0].spec.defaultCertificate.name != cluster.secret_name
   ```

3. **Backup del Secreto Antes de Reemplazarlo** ✅ **IMPLEMENTADO**
   - El rol ahora guarda el secreto completo en formato YAML antes de reemplazarlo
   - El backup se guarda en la ruta especificada en `cluster.backup_file`
   - Incluye todos los datos del secreto (certificado, llave, metadatos) para facilitar el rollback
   - Se crea automáticamente el directorio de backup si no existe
   - Permisos de archivo configurables mediante `certificate.backup_file_mode` (default: `0600`)

## Seguridad

### ✅ Aspectos de Seguridad Correctos

1. ✅ Los certificados se manejan como secretos de Kubernetes (no en texto plano)
2. ✅ Los archivos locales tienen permisos restrictivos (`0600`)
3. ✅ Las validaciones previas evitan aplicar certificados inválidos o vencidos

## Impacto en el Cluster

### ✅ Bajo Impacto

- El proceso es **no disruptivo** si se ejecuta correctamente
- OpenShift maneja el rollout de forma gradual (rolling update)
- Los pods del router se reinician automáticamente sin intervención manual
- El tiempo de actualización es típicamente 1-2 minutos

### ⚠️ Consideraciones

1. **Durante el Rollout**: Puede haber una breve interrupción del tráfico mientras los pods se reinician
2. **Validación del Certificado**: El rol valida el certificado antes de aplicarlo, lo cual es correcto
3. **Rollback**: Si algo sale mal, se puede restaurar el secreto anterior manualmente

## Resumen Final

**✅ El rol está implementado correctamente y sigue las mejores prácticas oficiales de Red Hat.**

No se requieren cambios críticos. El proceso es seguro y sigue el procedimiento oficial documentado por Red Hat para OpenShift 4.14.

