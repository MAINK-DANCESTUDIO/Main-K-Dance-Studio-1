# K-Dance Studio · Puerto Montt

Aplicación inicial basada en el HTML original adjunto. Mantiene la identidad negra/morada con acento amarillo y la adapta a una experiencia tipo app con navegación por secciones, login, roles, horarios, avisos, pagos, merch, entradas y panel administrativo.

## Qué incluye esta entrega

- Aplicación React/Vite con menú lateral en escritorio y navegación compacta en móvil.
- Inicio de sesión mediante Supabase Auth. No existe formulario de registro público.
- Roles `admin`, `coach` y `dancer`.
- Esquema SQL para perfiles, clases, inscripciones, avisos, pagos, productos, pedidos, eventos y entradas.
- Políticas RLS iniciales para limitar el acceso por rol/usuario.
- Funciones Edge `admin-invite` y `admin-user-delete` para invitar usuarios y eliminar cuentas desde administración.
- Funciones Edge `webpay-create` y `webpay-return` para iniciar y confirmar una transacción Webpay Plus con API REST.
- Registro de pagos manuales desde el panel admin y lectura de historial.
- Archivo `original-kdance.html` conservado como referencia.

**Estado importante:** es una base de aplicación que debe configurarse y probarse en tu propio proyecto antes de usar datos reales. No está publicada ni conectada a tus credenciales. El flujo Webpay está preparado para integración, pero no puede procesar cobros reales hasta contratar/activar Webpay, cargar credenciales y completar las pruebas y validación de Transbank. El catálogo y eventos ya leen datos de base de datos; los formularios completos de compra/stock y emisión de tickets todavía necesitan desarrollarse antes de vender merch/entradas en producción.

## 1. Crear el proyecto Supabase

1. Entra a https://supabase.com/ y crea un proyecto para K-Dance Studio.
2. Guarda la contraseña de la base de datos en un lugar seguro.
3. Abre **SQL Editor** y ejecuta el archivo `supabase/schema.sql` una sola vez.
4. En **Project Settings → API** copia Project URL y la clave publicable (puede aparecer como `anon` en proyectos antiguos).
5. En **Authentication → Sign In / Providers** desactiva el registro abierto (Allow new users to sign up). El alta debe ocurrir mediante invitación de administración.
6. Configura el proveedor de correo de Supabase para que las invitaciones puedan enviarse; verifica spam y remitente.

## 2. Preparar el primer administrador

No hay una contraseña maestra dentro de la web. Una persona debe recibir una invitación de Supabase y crear su contraseña de forma segura.

Opción de bootstrap recomendada:

1. Invita manualmente el correo de la persona administradora desde **Authentication → Users → Invite user**.
2. Cuando la cuenta exista, abre **Table Editor → profiles**. Si no existe la fila, crea una con el mismo UUID de `auth.users`, `full_name` y `role = admin`.
3. Si ya existe la fila de perfil, cambia su `role` a `admin` desde el editor.
4. No cambies el rol desde el navegador ni expongas la clave `service_role`.

Después de desplegar la función `admin-invite`, el administrador podrá invitar bailarines y coaches desde el panel.

## 3. Instalar y ejecutar localmente

Necesitas Node.js LTS instalado.

```bash
npm install
cp .env.example .env
```

Edita `.env` y reemplaza:

```env
VITE_SUPABASE_URL=https://TU-PROYECTO.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICABLE
```

Luego ejecuta:

```bash
npm run dev
```

Vite mostrará una dirección local, normalmente `http://localhost:5173`. Para probar el inicio de sesión, utiliza una cuenta invitada y con perfil creado.

Para generar la versión de publicación:

```bash
npm run build
```

Se genera la carpeta `dist/`.

## 4. Desplegar las funciones de Supabase

Instala la CLI de Supabase (https://supabase.com/docs/guides/cli), inicia sesión y vincula este proyecto:

```bash
supabase login
supabase link --project-ref TU_PROJECT_REF
```

Carga secretos **solo en el backend**, nunca en `.env` de Vite ni en el HTML:

```bash
supabase secrets set TBK_API_KEY_ID=TU_CODIGO_COMERCIO
supabase secrets set TBK_API_KEY_SECRET=TU_LLAVE_SECRETA
supabase secrets set TBK_ENVIRONMENT=integration
supabase secrets set FRONTEND_URL=https://TU-DOMINIO
```

Las funciones también requieren las variables gestionadas por Supabase: `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`. La clave `service_role` no debe publicarse ni enviarse al navegador.

Despliega:

```bash
supabase functions deploy admin-invite
supabase functions deploy admin-user-delete
supabase functions deploy webpay-create
supabase functions deploy webpay-return --no-verify-jwt
```

`webpay-return` debe aceptar el retorno del navegador de Transbank sin sesión JWT, por eso se desactiva la verificación JWT solo en esa función. La función valida el token directamente con Transbank antes de actualizar el estado.

## 5. Webpay Plus de Transbank

1. Entra a https://www.transbank.cl/ y solicita/contrata Webpay Plus para ventas por internet. Transbank entrega el código de comercio y las credenciales correspondientes.
2. Lee la documentación oficial: https://transbankdevelopers.com/documentacion/webpay-plus y https://transbankdevelopers.com/documentacion/como_empezar.
3. Comienza en ambiente `integration`; configura `TBK_API_KEY_ID` y `TBK_API_KEY_SECRET` con las credenciales de integración apropiadas.
4. Configura `FRONTEND_URL` con la URL de la aplicación desplegada.
5. Ejecuta pruebas completas: pago aprobado, pago rechazado, cancelación, token vencido, doble retorno y fallo de red. Confirma que solo `status = AUTHORIZED` y `response_code = 0` marca el pago como `paid`.
6. Completa la validación de integración requerida por Transbank antes de activar producción.
7. Cambia `TBK_ENVIRONMENT=production` y las credenciales por las de producción después de la aprobación.

No guardes números de tarjeta ni CVV en tu base de datos. El formulario de tarjeta lo entrega Webpay.

**Nota de alcance:** la función `webpay-create` actual permite crear un cobro desde un monto enviado por la aplicación. Antes de usarla para cobrar mensualidades contractuales o vender productos/entradas, el backend debe calcular el monto desde el registro de deuda, producto o evento en la base de datos, validar stock/capacidad, crear el pedido/ticket y evitar duplicados. No uses el monto enviado por el navegador como fuente autoritativa para cobrar ventas reales.

## 6. Publicar la web

1. Crea un repositorio privado en GitHub y sube esta carpeta (sin `.env`, secretos ni contraseñas).
2. Entra a https://vercel.com/, conecta GitHub y elige el repositorio.
3. Framework: Vite. Build command: `npm run build`. Output directory: `dist`.
4. En Vercel → Project Settings → Environment Variables agrega `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`.
5. Despliega y copia la URL generada. Agrégala en Supabase → Authentication → URL Configuration como Site URL y Redirect URL cuando corresponda.
6. Configura esa URL en el secreto `FRONTEND_URL` de Supabase para los retornos de Webpay.
7. Si tienes dominio propio, conéctalo en Vercel y verifica HTTPS.

## 7. Checklist antes de abrirlo a la academia

- [ ] RLS y permisos probados con una cuenta de cada rol.
- [ ] Bailarines no pueden leer pagos de otros usuarios ni modificar roles.
- [ ] Coaches solo pueden editar su propia información/clases autorizadas.
- [ ] Invitaciones y recuperación de contraseña probadas.
- [ ] Horarios y avisos probados en móvil.
- [ ] Webpay en integración aprobado para éxito, rechazo y cancelación.
- [ ] Mensualidades y precios calculados en backend, no confiados al navegador.
- [ ] Compras de merch con control de stock y emisión de tickets desarrolladas y probadas.
- [ ] Copias de seguridad, política de privacidad, condiciones de compra y datos de contacto preparados.

## Enlaces oficiales

- Supabase Auth: https://supabase.com/docs/guides/auth
- Seguridad RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Edge Functions: https://supabase.com/docs/guides/functions
- Transbank Developers: https://transbankdevelopers.com/
- Webpay Plus: https://transbankdevelopers.com/documentacion/webpay-plus
- Vercel: https://vercel.com/
