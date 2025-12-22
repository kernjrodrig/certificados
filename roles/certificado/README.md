# Rol de Ansible para Gestión de Certificados de OpenShift

Este rol automatiza la gestión de certificados TLS en clusters de OpenShift, incluyendo la extracción, verificación de expiración y reemplazo automático de certificados.

## Características

- ✅ Extracción automática de certificados TLS existentes
- ✅ Verificación de fechas de expiración
- ✅ Reemplazo automático cuando faltan menos de 60 días
- ✅ Validación de nuevos certificados antes del reemplazo
- ✅ Actualización automática del Ingress Controller
- ✅ Respaldos de configuración
- ✅ Soporte para múltiples clusters

## Requisitos

### Ansible
- Ansible 2.9 o superior
- Python 3.6 o superior

### Colecciones de Ansible
```bash
ansible-galaxy collection install community.crypto
ansible-galaxy collection install kubernetes.core
```

### Dependencias del Sistema
- `openssl` para validación de certificados
- Acceso a la API de Kubernetes/OpenShift

## Instalación

### Desde Ansible Galaxy
```bash
ansible-galaxy install tuusuario.certificado
```

### Desde el repositorio local
```bash
# Copiar el rol a tu directorio de roles
cp -r certificado /path/to/ansible/roles/
```

## Uso Básico

### Playbook Principal
```yaml
---
- name: Gestión de Certificados de OpenShift
  hosts: localhost
  gather_facts: true
  roles:
    - role: certificado
      vars:
        clusters:
          - name: cluster1
            api_url: "https://api.cluster1.example.com:6443"
            token: "{{ vault_token }}"  # gestiona con Ansible Vault
            secret_name: "ingress-tls-secret"
            cert_file_new: "new-cert.pem"
            key_file_new: "new-key.pem"
```

### Variables Requeridas

| Variable | Descripción | Requerido |
|----------|-------------|-----------|
| `cluster.api_url` | URL de la API del cluster | Sí |
| `cluster.token` | Token de autenticación | Sí |
| `cluster.secret_name` | Nombre del secreto TLS | Sí |
| `cluster.cert_file_new` | Ruta al nuevo certificado | Sí (para reemplazo) |
| `cluster.key_file_new` | Ruta a la nueva clave privada | Sí (para reemplazo) |

### Variables Opcionales

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `cluster.namespace_ingress` | Namespace del ingress | `openshift-ingress` |
| `cluster.ingress_controller_name` | Nombre del IC | `default` |
| `certificate.replacement_threshold_days` | Días para reemplazo | `60` |
| `certificate.min_validity_days` | Días mínimos de validez | `30` |

## Ejemplos de Uso

### Ejemplo 1: Verificar Certificados Existentes
```yaml
---
- name: Verificar estado de certificados
  hosts: localhost
  gather_facts: true
  roles:
    - role: certificado
      vars:
        clusters:
          - name: production
            api_url: "https://api.prod.example.com:6443"
            token: "{{ vault_prod_token }}"
            secret_name: "prod-ingress-cert"
```

### Ejemplo 2: Reemplazar Certificados
```yaml
---
- name: Reemplazar certificados
  hosts: localhost
  gather_facts: true
  roles:
    - role: certificado
      vars:
        clusters:
          - name: staging
            api_url: "https://api.staging.example.com:6443"
            token: "{{ vault_staging_token }}"
            secret_name: "staging-ingress-cert"
            cert_file_new: "{{ playbook_dir }}/certs/staging-cert.pem"
            key_file_new: "{{ playbook_dir }}/certs/staging-key.pem"
```

### Ejemplo 3: Múltiples Clusters
```yaml
---
- name: Gestión de múltiples clusters
  hosts: localhost
  gather_facts: true
  roles:
    - role: certificado
      vars:
        clusters:
          - name: cluster-east
            api_url: "https://api-east.example.com:6443"
            token: "{{ vault_east_token }}"
            secret_name: "east-ingress-cert"
            cert_file_new: "{{ role_path }}/files/east-cert.pem"
            key_file_new: "{{ role_path }}/files/east-key.pem"
          
          - name: cluster-west
            api_url: "https://api-west.example.com:6443"
            token: "{{ vault_west_token }}"
            secret_name: "west-ingress-cert"
            cert_file_new: "{{ role_path }}/files/west-cert.pem"
            key_file_new: "{{ role_path }}/files/west-key.pem"
```

## Estructura del Rol

```
certificado/
├── defaults/          # Variables por defecto
├── handlers/          # Handlers del rol
├── meta/             # Metadatos del rol
├── tasks/            # Tareas principales
│   ├── main.yml      # Tarea principal
│   └── replace_certificate.yml  # Reemplazo de certificados
├── templates/         # Plantillas (si las hay)
├── tests/            # Tests del rol
├── vars/             # Variables del rol
└── README.md         # Este archivo
```

## Flujo de Trabajo

1. **Extracción**: El rol extrae el certificado TLS actual del cluster
2. **Validación**: Verifica la fecha de expiración del certificado
3. **Análisis**: Calcula los días restantes hasta la expiración
4. **Decisión**: Si faltan menos de 60 días, procede al reemplazo
5. **Reemplazo**: Valida el nuevo certificado y actualiza el cluster
6. **Verificación**: Confirma que los cambios se aplicaron correctamente

## Seguridad

- Los tokens de autenticación deben almacenarse en Ansible Vault
- Los certificados y claves privadas deben tener permisos restrictivos (600)
- Se recomienda usar certificados con al menos 30 días de validez

## Troubleshooting

### Error: "El secreto no existe"
- Verifica que el `secret_name` y `namespace_ingress` sean correctos
- Confirma que tienes permisos para acceder al namespace

### Error: "Certificado ya vencido"
- Verifica la fecha de expiración del nuevo certificado
- Asegúrate de que el certificado sea válido

### Error: "Fallo en la actualización del Ingress Controller"
- Verifica que tienes permisos de administrador en el cluster
- Confirma que el Ingress Controller existe y es accesible

## Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Crea un Pull Request

## Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## Soporte

Para soporte y preguntas:
- Abre un issue en GitHub
- Contacta al equipo de desarrollo
- Consulta la documentación oficial de Ansible
