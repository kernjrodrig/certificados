#!/bin/bash
# Script para identificar el nombre del secreto TLS usado por el Ingress Controller

CLUSTER_API="${1:-https://api.uatocp.imss.gob.mx:6443}"
TOKEN="${2}"

if [ -z "$TOKEN" ]; then
    echo "Uso: $0 <api-url> <token>"
    echo "Ejemplo: $0 https://api.uatocp.imss.gob.mx:6443 sha256~TOKEN"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "🔍 IDENTIFICANDO SECRET_NAME PARA EL INGRESS CONTROLLER"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Login al cluster
oc login --token="$TOKEN" --server="$CLUSTER_API" --insecure-skip-tls-verify=true > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Error al conectar al cluster"
    exit 1
fi

echo "✅ Conectado al cluster"
echo ""

# Método 1: Ver qué secreto está configurado en el IngressController
echo "═══════════════════════════════════════════════════════════════"
echo "1️⃣  SECRETO CONFIGURADO EN EL INGRESS CONTROLLER"
echo "═══════════════════════════════════════════════════════════════"
SECRET_NAME=$(oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}' 2>/dev/null)

if [ -n "$SECRET_NAME" ]; then
    echo "✅ Secret Name encontrado: $SECRET_NAME"
    echo ""
    echo "Este es el valor que debes usar en vars.yml:"
    echo "   secret_name: \"$SECRET_NAME\""
else
    echo "⚠️  No hay certificado personalizado configurado"
    echo "   El Ingress Controller está usando el certificado por defecto"
    echo ""
    echo "Opciones:"
    echo "   1. Usar el secreto por defecto: router-certs-default"
    echo "   2. Crear un nuevo secreto con el nombre que prefieras"
fi

echo ""

# Método 2: Listar todos los secretos TLS en openshift-ingress
echo "═══════════════════════════════════════════════════════════════"
echo "2️⃣  SECRETOS TLS DISPONIBLES EN openshift-ingress"
echo "═══════════════════════════════════════════════════════════════"
oc get secrets -n openshift-ingress -o json | jq -r '.items[] | select(.type=="kubernetes.io/tls") | "   - \(.metadata.name) (creado: \(.metadata.creationTimestamp))"' 2>/dev/null || \
oc get secrets -n openshift-ingress | grep "kubernetes.io/tls" | awk '{print "   - " $1}'

echo ""

# Método 3: Verificar el secreto por defecto
echo "═══════════════════════════════════════════════════════════════"
echo "3️⃣  SECRETO POR DEFECTO (router-certs-default)"
echo "═══════════════════════════════════════════════════════════════"
if oc get secret router-certs-default -n openshift-ingress > /dev/null 2>&1; then
    echo "✅ El secreto 'router-certs-default' existe"
    echo "   Este es el secreto estándar usado por OpenShift"
    echo ""
    echo "   Si quieres reemplazar el certificado por defecto, usa:"
    echo "      secret_name: \"router-certs-default\""
else
    echo "⚠️  El secreto 'router-certs-default' no existe"
    echo "   Puede que uses un nombre diferente o que sea un cluster personalizado"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📋 RECOMENDACIÓN"
echo "═══════════════════════════════════════════════════════════════"
if [ -n "$SECRET_NAME" ]; then
    echo "Usa el secreto configurado actualmente:"
    echo "   secret_name: \"$SECRET_NAME\""
else
    echo "Usa el secreto por defecto de OpenShift:"
    echo "   secret_name: \"router-certs-default\""
fi
echo ""

