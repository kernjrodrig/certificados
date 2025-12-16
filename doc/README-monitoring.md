# Monitoreo de Actualización de Certificados

Este documento explica cómo monitorear qué servicios/pods se reinician cuando se actualizan los certificados del Ingress Controller en OpenShift.

## Servicios que se reinician

Cuando se actualiza el certificado del Ingress Controller, los siguientes componentes se reinician:

1. **Pods del Router** (`router-default` en namespace `openshift-ingress`)
   - Estos son los pods que manejan el tráfico de entrada
   - Se reinician automáticamente cuando se actualiza el secreto TLS

2. **Deployment del Router** (`router-default`)
   - El deployment se actualiza para usar el nuevo certificado
   - Esto dispara un rollout que reinicia los pods

## Comandos CLI para monitorear

### 1. Ver el Ingress Controller y su configuración

```bash
oc get ingresscontroller default -n openshift-ingress-operator -o yaml
```

### 2. Ver el Deployment del Router

```bash
oc get deployment router-default -n openshift-ingress -o wide
```

### 3. Ver los Pods del Router (estos son los que se reinician)

```bash
# Listar pods
oc get pods -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default

# Ver en tiempo real
oc get pods -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default -w
```

### 4. Monitorear eventos en tiempo real

```bash
oc get events -n openshift-ingress --watch
```

### 5. Ver el estado del rollout

```bash
# Ver estado actual
oc rollout status deployment/router-default -n openshift-ingress

# Ver historial
oc rollout history deployment/router-default -n openshift-ingress
```

### 6. Ver logs de los pods del router

```bash
# Ver logs de todos los pods
oc logs -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default --tail=50

# Ver logs de un pod específico en tiempo real
oc logs -n openshift-ingress <pod-name> -f
```

### 7. Verificar el certificado actual en uso

```bash
# Ver el secreto TLS
oc get secret router-certs-default -n openshift-ingress -o yaml

# Ver información del certificado
oc get secret router-certs-default -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -dates -issuer
```

## Script de monitoreo

Se incluye un script `monitor-certificate-update.sh` que automatiza el monitoreo:

```bash
./monitor-certificate-update.sh [cluster-name] [api-url] [token]
```

Ejemplo:
```bash
./monitor-certificate-update.sh prd-ocp https://api.prd-ocp.guzdan.com:6443 sha256~TOKEN
```

## Proceso de actualización

Cuando se ejecuta el rol de Ansible para actualizar certificados:

1. **Se actualiza el secreto TLS** (`router-certs-default`)
   - El secreto contiene el nuevo certificado y llave

2. **El Ingress Controller detecta el cambio**
   - El operador de OpenShift detecta que el secreto cambió

3. **Se reinician los pods del router**
   - El deployment hace un rollout automático
   - Los pods antiguos se terminan y se crean nuevos con el certificado actualizado

4. **Tiempo estimado**
   - El proceso completo toma aproximadamente 1-2 minutos
   - Durante este tiempo puede haber una breve interrupción del tráfico

## Verificar que la actualización fue exitosa

```bash
# 1. Verificar que los pods están corriendo
oc get pods -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default

# 2. Verificar el certificado en uso
oc get secret router-certs-default -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -dates

# 3. Verificar que no hay errores en los logs
oc logs -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default --tail=100 | grep -i error
```

## Troubleshooting

### Si los pods no se reinician

```bash
# Forzar un rollout manual
oc rollout restart deployment/router-default -n openshift-ingress

# Ver el estado del rollout
oc rollout status deployment/router-default -n openshift-ingress
```

### Si hay problemas con el certificado

```bash
# Ver eventos relacionados con el secreto
oc get events -n openshift-ingress --field-selector involvedObject.name=router-certs-default

# Ver la configuración del Ingress Controller
oc describe ingresscontroller default -n openshift-ingress-operator
```

