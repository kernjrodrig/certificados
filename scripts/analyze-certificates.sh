#!/bin/bash
# Script para analizar certificados en el directorio roles/certificado/files

CERTS_DIR="$(dirname "$0")/../roles/certificado/files"

echo "═══════════════════════════════════════════════════════════════"
echo "🔍 ANÁLISIS DE CERTIFICADOS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Función para analizar un certificado
analyze_cert() {
    local cert_file="$1"
    local cert_name=$(basename "$cert_file")
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "📄 Certificado: $cert_name"
    echo "═══════════════════════════════════════════════════════════════"
    
    if [ ! -f "$cert_file" ]; then
        echo "❌ Archivo no encontrado"
        echo ""
        return
    fi
    
    # Información básica
    echo "📋 Subject:"
    openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/^/   /'
    
    echo ""
    echo "🏢 Issuer:"
    openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | sed 's/^/   /'
    
    echo ""
    echo "📅 Fechas de validez:"
    openssl x509 -in "$cert_file" -noout -dates 2>/dev/null | sed 's/^/   /'
    
    # Calcular días restantes
    not_after=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$not_after" ]; then
        expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null)
        current_epoch=$(date +%s)
        if [ -n "$expiry_epoch" ]; then
            days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))
            echo ""
            echo "📊 Días restantes: $days_remaining"
        fi
    fi
    
    echo ""
    echo "🔐 Serial Number:"
    openssl x509 -in "$cert_file" -noout -serial 2>/dev/null | sed 's/^/   /'
    
    echo ""
    echo "🔑 Información de la llave:"
    openssl x509 -in "$cert_file" -noout -text 2>/dev/null | grep -A 2 "Public Key Algorithm\|RSA Public-Key" | head -3 | sed 's/^/   /'
    
    echo ""
    echo "🌐 Subject Alternative Names (SANs):"
    openssl x509 -in "$cert_file" -noout -text 2>/dev/null | grep -A 1 "Subject Alternative Name" | grep "DNS:" | sed 's/^/   /' || echo "   No hay SANs configurados"
    
    echo ""
    echo "🔒 Fingerprint:"
    openssl x509 -in "$cert_file" -noout -fingerprint -sha256 2>/dev/null | sed 's/^/   /'
    
    echo ""
}

# Analizar certificados principales
if [ -f "$CERTS_DIR/apps_uatocp_imss_gob_mx.crt" ]; then
    analyze_cert "$CERTS_DIR/apps_uatocp_imss_gob_mx.crt"
fi

if [ -f "$CERTS_DIR/CA_Raiz.crt" ]; then
    analyze_cert "$CERTS_DIR/CA_Raiz.crt"
fi

if [ -f "$CERTS_DIR/CA_Intermedia.cer" ]; then
    analyze_cert "$CERTS_DIR/CA_Intermedia.cer"
fi

# Analizar llave privada
if [ -f "$CERTS_DIR/apps_uatocp_imss_gob_mx_sinpassw.key" ]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo "🔑 Llave Privada: apps_uatocp_imss_gob_mx_sinpassw.key"
    echo "═══════════════════════════════════════════════════════════════"
    
    key_type=$(openssl rsa -in "$CERTS_DIR/apps_uatocp_imss_gob_mx_sinpassw.key" -noout -text 2>/dev/null | grep "Private-Key:" | head -1)
    key_size=$(openssl rsa -in "$CERTS_DIR/apps_uatocp_imss_gob_mx_sinpassw.key" -noout -text 2>/dev/null | grep "RSA Private-Key" | awk '{print $3}')
    
    echo "📋 Tipo: $key_type"
    echo "📊 Tamaño de llave: $key_size bits"
    echo "📁 Archivo: $CERTS_DIR/apps_uatocp_imss_gob_mx_sinpassw.key"
    echo "📏 Tamaño del archivo: $(stat -c%s "$CERTS_DIR/apps_uatocp_imss_gob_mx_sinpassw.key") bytes"
    echo ""
fi

# Verificar si el certificado y la llave coinciden
if [ -f "$CERTS_DIR/apps_uatocp_imss_gob_mx.crt" ] && [ -f "$CERTS_DIR/apps_uatocp_imss_gob_mx_sinpassw.key" ]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo "🔍 Verificación de correspondencia Certificado-Llave"
    echo "═══════════════════════════════════════════════════════════════"
    
    cert_modulus=$(openssl x509 -noout -modulus -in "$CERTS_DIR/apps_uatocp_imss_gob_mx.crt" 2>/dev/null | openssl md5)
    key_modulus=$(openssl rsa -noout -modulus -in "$CERTS_DIR/apps_uatocp_imss_gob_mx_sinpassw.key" 2>/dev/null | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        echo "✅ El certificado y la llave privada CORRESPONDEN"
    else
        echo "❌ ADVERTENCIA: El certificado y la llave privada NO corresponden"
    fi
    echo ""
fi

# Resumen
echo "═══════════════════════════════════════════════════════════════"
echo "📊 RESUMEN"
echo "═══════════════════════════════════════════════════════════════"
echo "Certificados encontrados:"
ls -lh "$CERTS_DIR"/*.{crt,cer,pem} 2>/dev/null | awk '{print "   - " $9 " (" $5 ")"}'
echo ""
echo "Llaves privadas encontradas:"
ls -lh "$CERTS_DIR"/*.key 2>/dev/null | awk '{print "   - " $9 " (" $5 ")"}'
echo ""

