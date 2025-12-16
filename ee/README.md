# Execution Environment para el Rol de Certificados

Este directorio contiene todos los archivos necesarios para construir el Execution Environment (EE) con todas las dependencias requeridas para el rol de certificados de OpenShift.

## Archivos Incluidos

- `execution-environment.yml`: Definición del EE para ansible-builder
- `requirements-collections.yml`: Colecciones de Ansible necesarias (community.crypto)
- `requirements.txt`: Dependencias Python (pip)
- `bindep.txt`: Dependencias del sistema operativo
- `README.md`: Esta documentación

## Guía: Construir y Actualizar el Execution Environment

Este documento explica cómo construir un nuevo Execution Environment (EE) con todas las dependencias necesarias para el rol de certificados.

## Requisitos Previos

1. **ansible-builder** instalado:
   ```bash
   pip install ansible-builder
   ```

2. **Podman o Docker** instalado y funcionando:
   ```bash
   # Verificar que podman funciona
   podman ps
   ```

3. **Acceso a Quay.io** (o tu registry de contenedores) para subir la imagen

## Archivos en este Directorio

Este directorio contiene todos los archivos necesarios para construir el EE:

- `execution-environment.yml`: Definición del EE para ansible-builder
- `requirements-collections.yml`: Colecciones de Ansible necesarias (community.crypto)
- `requirements.txt`: Dependencias Python (pip)
- `bindep.txt`: Dependencias del sistema operativo
- `README.md`: Esta documentación

## Proceso de Construcción

### Paso 1: Verificar los archivos

Asegúrate de que todos los archivos estén en el directorio `ee/`:

```bash
cd ee/
ls -la execution-environment.yml requirements-collections.yml requirements.txt bindep.txt
```

### Paso 2: Construir el Execution Environment

```bash
# Construir el EE localmente
ansible-builder build --tag quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2 \
  --container-runtime podman

# O si prefieres usar Docker:
ansible-builder build --tag quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2 \
  --container-runtime docker
```

**Nota:** Cambia `v2` por la versión que quieras usar.

### Paso 3: Verificar la imagen construida

```bash
# Listar imágenes locales
podman images | grep mi-ee-kubernetes

# Probar la imagen localmente
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2 \
  --inventory localhost, \
  --mode stdout
```

### Paso 4: Subir la imagen a Quay.io

```bash
# Login a Quay.io
podman login quay.io

# Subir la imagen
podman push quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2
```

## Opciones de Construcción

### Construir desde una imagen base existente

Si quieres actualizar el EE existente (`mi-ee-kubernetes:v1`), puedes:

1. **Opción A:** Usar la imagen existente como base (recomendado)
   ```yaml
   # En execution-environment.yml
   images:
     base_image:
       name: quay.io/kjavier_rodriguez/mi-ee-kubernetes:v1
   ```

2. **Opción B:** Construir desde cero
   ```yaml
   # En execution-environment.yml
   images:
     base_image:
       name: quay.io/ansible/ansible-runner:latest
   ```

### Construir con caché (más rápido)

```bash
ansible-builder build \
  --tag quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2 \
  --container-runtime podman \
  --build-arg ANSIBLE_GALAXY_CLI_COLLECTION_OPTS=--force \
  --squash new
```

## Verificar Colecciones Instaladas

Para verificar que las colecciones están instaladas en el EE:

```bash
# Ejecutar un comando dentro del contenedor
podman run --rm quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2 \
  ansible-galaxy collection list

# Deberías ver:
# community.crypto
# kubernetes.core
```

## Solución de Problemas

### Error: "ansible-builder: command not found"

```bash
pip install ansible-builder
# o
pip3 install ansible-builder
```

### Error: "No module named 'ansible_builder'"

```bash
# Asegúrate de estar en el entorno virtual correcto
source ansible-env/bin/activate
pip install ansible-builder
```

### Error al construir: "Failed to install collections"

Verifica que `requirements-collections.yml` tenga el formato correcto y que las colecciones estén disponibles en Ansible Galaxy. Asegúrate de estar ejecutando `ansible-builder` desde el directorio `ee/`.

### Error al subir: "unauthorized: access to the resource is denied"

```bash
# Asegúrate de estar autenticado
podman login quay.io
# Ingresa tus credenciales de Quay.io
```

## Actualizar el Playbook para Usar el Nuevo EE

Una vez que hayas construido y subido el nuevo EE, actualiza `ansible-navigator.yml`:

```yaml
---
ansible-navigator:
  execution-environment:
    image: quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2  # Nueva versión
    pull:
      policy: always
```

O usa el flag `--eei` directamente:

```bash
ansible-navigator run playbook-with-role.yml \
  --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2 \
  --inventory localhost,
```

## Resumen de Comandos

```bash
# 1. Construir el EE
ansible-builder build --tag quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2 --container-runtime podman

# 2. Probar localmente
ansible-navigator run playbook-with-role.yml --eei quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2 --inventory localhost, --mode stdout

# 3. Subir a Quay.io
podman login quay.io
podman push quay.io/kjavier_rodriguez/mi-ee-kubernetes:v2
```

