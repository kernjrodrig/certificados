#!/bin/bash
# Script para monitorear qué servicios/pods se reinician al actualizar certificados

CLUSTER_NAME="${1:-prd-ocp}"
API_URL="${2:-https://api.prd-ocp.guzdan.com:6443}"
TOKEN="${3:-sha256~1XybYvXKXx-hXHFKOZPgRgr5C4caHoqdRUWlmIveHig}"
NAMESPACE_INGRESS="openshift-ingress"
NAMESPACE_INGRESS_OPERATOR="openshift-ingress-operator"

echo "═══════════════════════════════════════════════════════════════"
echo "🔍 MONITOREO DE SERVICIOS/PODS DEL INGRESS CONTROLLER"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Login al cluster
echo "📋 Conectando al cluster: $CLUSTER_NAME"
oc login --token="$TOKEN" --server="$API_URL" --insecure-skip-tls-verify=true > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Error al conectar al cluster"
    exit 1
fi

echo "✅ Conectado exitosamente"
echo ""

# 1. Mostrar información del Ingress Controller
echo "═══════════════════════════════════════════════════════════════"
echo "1️⃣  INGRESS CONTROLLER"
echo "═══════════════════════════════════════════════════════════════"
oc get ingresscontroller default -n $NAMESPACE_INGRESS_OPERATOR -o yaml | grep -A 10 "defaultCertificate\|status" | head -20
echo ""

# 2. Mostrar Deployment del Router
echo "═══════════════════════════════════════════════════════════════"
echo "2️⃣  DEPLOYMENT DEL ROUTER"
echo "═══════════════════════════════════════════════════════════════"
oc get deployment router-default -n $NAMESPACE_INGRESS -o wide
echo ""

# 3. Mostrar ReplicaSet actual
echo "═══════════════════════════════════════════════════════════════"
echo "3️⃣  REPLICASET ACTUAL"
echo "═══════════════════════════════════════════════════════════════"
oc get replicaset -n $NAMESPACE_INGRESS -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default --sort-by=.metadata.creationTimestamp | tail -5
echo ""

# 4. Mostrar Pods del Router
echo "═══════════════════════════════════════════════════════════════"
echo "4️⃣  PODS DEL ROUTER (estos son los que se reinician)"
echo "═══════════════════════════════════════════════════════════════"
oc get pods -n $NAMESPACE_INGRESS -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default -o wide
echo ""

# 5. Mostrar información detallada de los pods
echo "═══════════════════════════════════════════════════════════════"
echo "5️⃣  INFORMACIÓN DETALLADA DE PODS"
echo "═══════════════════════════════════════════════════════════════"
PODS=$(oc get pods -n $NAMESPACE_INGRESS -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default -o jsonpath='{.items[*].metadata.name}')

for pod in $PODS; do
    echo "📦 Pod: $pod"
    echo "   Estado: $(oc get pod $pod -n $NAMESPACE_INGRESS -o jsonpath='{.status.phase}')"
    echo "   Inicio: $(oc get pod $pod -n $NAMESPACE_INGRESS -o jsonpath='{.status.startTime}')"
    echo "   Edad: $(oc get pod $pod -n $NAMESPACE_INGRESS -o jsonpath='{.status.startTime}' | xargs -I {} date -d {} +%s 2>/dev/null | xargs -I {} expr $(date +%s) - {} 2>/dev/null | xargs -I {} expr {} / 60 2>/dev/null || echo 'N/A') minutos"
    echo ""
done

# 6. Mostrar eventos recientes
echo "═══════════════════════════════════════════════════════════════"
echo "6️⃣  EVENTOS RECIENTES DEL NAMESPACE"
echo "═══════════════════════════════════════════════════════════════"
oc get events -n $NAMESPACE_INGRESS --sort-by='.lastTimestamp' | tail -10
echo ""

# 7. Comandos útiles para monitoreo en tiempo real
echo "═══════════════════════════════════════════════════════════════"
echo "📋 COMANDOS ÚTILES PARA MONITOREO"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "🔍 Ver pods en tiempo real:"
echo "   oc get pods -n $NAMESPACE_INGRESS -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default -w"
echo ""
echo "📊 Ver eventos en tiempo real:"
echo "   oc get events -n $NAMESPACE_INGRESS --watch"
echo ""
echo "📝 Ver logs de un pod específico:"
echo "   oc logs -n $NAMESPACE_INGRESS <pod-name> -f"
echo ""
echo "🔄 Ver rollout del deployment:"
echo "   oc rollout status deployment/router-default -n $NAMESPACE_INGRESS"
echo ""
echo "📈 Ver historial de rollouts:"
echo "   oc rollout history deployment/router-default -n $NAMESPACE_INGRESS"
echo ""

