# Análisis de Validaciones del Rol

## Validaciones Mencionadas en el Análisis de Certificados

1. ✅ **Certificado válido: X días restantes** - ✅ IMPLEMENTADO
2. ✅ **Certificado y llave coinciden** - ✅ IMPLEMENTADO
3. ✅ **Cadena completa: raíz, intermedia y servidor** - ✅ IMPLEMENTADO (detección)

## Validaciones Actuales del Rol

### ✅ Implementadas

1. **Validación de certificado no vencido** (línea 72-75)
   - ✅ Verifica que el certificado no esté vencido
   - ✅ Compara `not_after` con timestamp actual

2. **Validación de validez mínima** (línea 77-80)
   - ✅ Verifica que el certificado tenga al menos `min_validity_days` (default: 30 días)
   - ✅ Calcula días restantes y compara con el umbral

3. **Validación de existencia del certificado** (línea 44-48)
   - ✅ Verifica que el archivo de certificado exista y sea válido
   - ✅ Obtiene información del certificado usando `x509_certificate_info`

4. **Mostrar información del certificado** (línea 50-70) ✅ NUEVO
   - ✅ Calcula y muestra días restantes en formato legible
   - ✅ Muestra fechas formateadas (DD/MM/YYYY HH:MM:SS UTC)
   - ✅ Muestra Subject, Issuer y validez del certificado

5. **Validación de correspondencia Certificado-Llave** (línea 82-108) ✅ NUEVO
   - ✅ Verifica que la llave privada exista
   - ✅ Compara el módulo RSA del certificado con el de la llave privada
   - ✅ Falla si no corresponden (evita aplicar certificado incorrecto)

6. **Validación de cadena de certificados** (línea 110-125) ✅ NUEVO
   - ✅ Detecta cuántos certificados hay en el archivo
   - ✅ Identifica si la cadena completa está incluida (certificado + intermedios)
   - ✅ Muestra advertencia si solo hay el certificado del servidor

## Resumen de Validaciones

| Validación | Estado | Ubicación |
|------------|--------|-----------|
| Certificado no vencido | ✅ | Línea 72-75 |
| Validez mínima (30 días) | ✅ | Línea 77-80 |
| Días restantes (mostrar) | ✅ | Línea 50-70 |
| Certificado y llave coinciden | ✅ | Línea 92-108 |
| Cadena de certificados (detección) | ✅ | Línea 110-125 |
| Backup del secreto | ✅ | Línea 5-42 |

## Mejoras Implementadas

Todas las validaciones mencionadas en el análisis de certificados están ahora implementadas en el rol, mejorando la seguridad y confiabilidad del proceso de reemplazo de certificados.

