# Rutas y acciones comunes:
#
# GET     /                             - Bienvenida a la terminal
# GET     /dni                          - Ingreso del DNI del Usuario
# POST    /dni                          - Verifica el DNI y redirige a /codigo
# GET     /codigo                       - Ingreso del Código de acceso del Usuario
# POST    /codigo                       - Verifica el Código y redirige según tipo de Usuario
# GET     /admin-login                  - Ingreso de Legajo y Código del Admin
# POST    /admin-login                  - Verifica Legajo y Código del Admin
#
# Rutas y acciones de clientes:
#
# GET     /extraccion                   - Inicio del proceso de extracción de sobres
# GET     /saliendo                     - Aviso de salida al cliente
# POST    /extraccion                   - Completa el proceso de extracción de un Sobre
#
# Rutas y acciones de administradores:
#
# GET     /admin/usuarios               - ABM de Usuarios administradores
# GET     /admin/usuarios/nuevo         - Formulario de carga de administrador
# POST    /admin/usuarios/crear         - Cargar un administrador
# GET     /admin/usuarios/:id/editar    - Formulario de edición de administrador
# POST    /admin/usuarios/:id/editar    - Modificar un administrador
# POST    /admin/usuarios/:id/eliminar  - Eliminar un administrador
# GET     /admin/clientes               - ABM de clientes administradores
# POST    /admin/clientes/:id/sobres    - Carga un sobre nuevo para este usuario
# GET     /admin/logs                   - Visualización de logs del sistema

begin
  listener = Listen.to(Configuracion.path_base_novedades) do |modified, added, removed|
    if added.any?
      added.each do |a|
        Novedad.parsear(a)
        File.delete(a) if File.exist?(a)
      end
    end
    if modified.any?
      modified.each do |m|
        Novedad.parsear(m)
        File.delete(m) if File.exist?(m)
      end
    end
  end
  listener.start
rescue Exception => e
  Log.error e.message
end

begin
  scheduler = Rufus::Scheduler.new
  scheduler.cron "00 14 * * *" do
    Exportador.new.exportar!
  end
rescue Exception => e
  Log.error e.message
end

Cuba.define do
  on get do
    on root do
      # Limpiamos la sesión
      session.delete(:usuario_actual_id)
      session.delete(:usuario_actual_tipo)
      Log.usuario_actual = nil

      # Inicializar el motor y la posición cero
      begin
        Nucleo.get_estado
      rescue => e
        fallo!(e.respond_to?(:codigo) ? e.codigo : e.message)
      end

      render "inicio", titulo: "Retirá tu tarjeta", admin: false, refresh: false
    end

    on "dni" do
      render "dni", titulo: "Ingresa tu documento", admin: false
    end

    on "codigo" do
      render "codigo", titulo: "Ingresa tu clave de retiro", admin: false
    end

    on "admin-login" do
      render "admin_login", titulo: "Ingrese su legajo y contraseña", admin: false
    end

    on "reboot" do
      `sudo reboot`
    end

    # Verificamos que exista un sobre para este cliente o redirigimos
    on "extraccion" do
      cliente = Cliente.find session[:usuario_actual_id] if usuario_actual_cliente?

      if cliente.present? && cliente.sobres.montados.any?
        if cliente.sobres.montados.count > 1
          render "extraccion", titulo: "Bienvenido #{cliente.nombre} Tenés #{cliente.sobres.montados.count} tarjetas para retirar", admin: false, x: cliente.sobres.montados.count, logged: true
        else
          render "extraccion", titulo: "Bienvenido #{cliente.nombre} Tenés #{cliente.sobres.montados.count} tarjeta para retirar", admin: false, x: cliente.sobres.montados.count, logged: true
        end
      else
        flash[:mensaje] = "No tiene tarjetas disponibles."
        flash[:tipo] = "alert-danger"

        res.redirect "/"
      end
    end

    on "saliendo" do
      render "saliendo", titulo: "Saliendo", admin: false, logged: true, refresh: false
    end

    # Control de acceso de administradores para el bloque completo
    on "admin" do
      garantizar_admin!

      # Panel de configuración
      on "panel" do
        render "panel", titulo: "Panel de configuración", admin: true, config: Configuracion.config, logged: true
      end

      # Inicio de carga de usuarios administradores
      on "usuarios" do
        garantizar_superadmin!

        on root do
          render "index_usuarios", titulo: "Administración de usuarios", admin: true, usuarios: Admin.normal, logged: true
        end

        on "nuevo" do
          render "nuevo_usuario", titulo: "Carga de usuario administrador", admin: true, logged: true
        end

        on ":id/editar" do |id|
          usuario = Admin.normal.find(id)

          render "editar_usuario", titulo: "Editar usuario #{usuario.nombre}", usuario: usuario, admin: true, logged: true
        end
      end

      # Inicio de carga de clientes
      on "clientes" do
        on root do
          render "index_clientes", titulo: "Administración de clientes y sobres", admin: true, tarjetas: Tarjeta.includes(:cliente, :sobre), logged: true
        end
      end

      on "logs" do
        render "index_logs", titulo: "Logs del sistema", admin: true, logs: Log.includes(:usuario).order(created_at: :desc), logged: true
      end

      on "vaciado_logico" do
        Sobre.montados.update_all estado: "no_montado", posicion: nil

        flash[:mensaje] = "Vaciado lógico realizado correctamente."
        flash[:tipo] = "alert-success"

        res.redirect "/admin/clientes"
      end

      on "extraccion_directa" do
        begin
          estado, sub_estado, flags, resp, _ = Nucleo.extraccion_directa!.values_at(:estado, :sub_estado, :flags, :resp)
        rescue NoMethodError => e
          flash[:mensaje] = "No se puede extraer."
          flash[:tipo] = "alert-danger"

          res.redirect "/admin/clientes"
        rescue => e
          fallo!(e.respond_to?(:codigo) ? e.codigo : e.message)
        end

        if estado
          case estado
          # Si se extrajo el sobre
          when :en_espera
            flash[:mensaje] = "Sobre retirado."
            flash[:tipo] = "alert-success"

            case sub_estado
            when :extraccion_correcta
              Log.info "Sobre retirado mediante extracción directa"
            else
              Log.info "SubEstado de extracción directa desconocido"

              flash[:mensaje] = "Ocurrió un error."
              flash[:tipo] = "alert-danger"
            end
          when :modo_manual
            flash[:mensaje] = "Modo manual."
            flash[:tipo] = "alert-danger"
          when :emergencia_superable
            flash[:mensaje] = "Emergencia."
            flash[:tipo] = "alert-danger"
          else
            Log.info "Error en extracción directa"

            flash[:mensaje] = "Ocurrió un error."
            flash[:tipo] = "alert-danger"
          end

          res.redirect "/admin/clientes"
        end
      end
    end
  end

  on post do
    # Recibe el DNI cargado por el Cliente
    on "dni" do
      on param("dni"), param("tipo") do |dni, tipo|
        # Guardamos el documento para el próximo request y le pedimos el código
        session[:dni] = dni
        session[:tipo] = tipo

        res.redirect "/codigo"
      end
    end

    # Recibe el Código de acceso cargado por el Cliente
    on "codigo" do
      on param("codigo") do |codigo|
        dni = session[:dni]
        tipo = session[:tipo]

        usuario = Cliente.where(nro_documento: dni, tipo_documento: tipo).take

        if usuario.try(:validar!, codigo)
          session.delete(:dni)
          session.delete(:tipo)
          #flash[:mensaje] = "Le damos la bienvenida #{usuario.nombre}."
          #flash[:tipo] = 'alert-info'

          # Guardamos al usuario para la siguiente solicitud
          session[:usuario_actual_id] = usuario.id
          session[:usuario_actual_tipo] = usuario.class.to_s
          Log.usuario_actual = usuario
          Log.info "Usuario logueado: #{usuario.nombre}"

          res.redirect "/extraccion"
        else
          if usuario && usuario.bloqueado?
            session.delete(:dni)
            session.delete(:tipo)

            Log.error "Usuario bloqueado, intento de ingreso de: #{dni}"
            flash[:mensaje] = "Su usuario ha sido bloqueado."
            flash[:tipo] = "alert-danger"

            res.redirect "/"
          else
            Log.error "Error de identificación, intento de ingreso de: #{dni}"
            flash[:mensaje] = "Hubo un error de identificación. Verifique los datos ingresados."
            flash[:tipo] = "alert-danger"

            res.redirect "/codigo"
          end
        end
      end
    end

    # Recibe las credenciales (Legajo y Código) de los usuarios Admin
    on "admin-login" do
      on param("legajo"), param("codigo") do |legajo, codigo|
        usuario = Admin.where(nro_documento: legajo).take.try(:authenticate, codigo)

        if usuario
          flash[:mensaje] = "Le damos la bienvenida Administrador #{usuario.nombre}."
          flash[:tipo] = "alert-info"

          # Guardamos al usuario para la siguiente solicitud
          session[:usuario_actual_id] = usuario.id
          session[:usuario_actual_tipo] = usuario.class.to_s
          Log.usuario_actual = usuario
          Log.info "Usuario logueado: #{usuario.nombre}"

          res.redirect "/admin/clientes"
        else
          Log.error "Error de identificación de admin, intento de ingreso de: #{legajo}"
          flash[:mensaje] = "Hubo un error de identificación. Verifique los datos ingresados."
          flash[:tipo] = "alert-danger"

          res.redirect "/"
        end
      end
    end

    # Proceso de extracción de un sobre por parte de un cliente
    on "extraccion" do
      cliente = Cliente.find session[:usuario_actual_id] if usuario_actual_cliente?

      # Después de un error o terminar las extracciones volvemos al inicio
      siguiente = "/"

      if cliente.present? && cliente.sobres.montados.any?
        sobre = cliente.sobres.montados.first

        begin
          estado, sub_estado, flags, resp, _ = Nucleo.extraer!(sobre.posicion, true).values_at(:estado, :sub_estado, :flags, :resp)
        rescue => e
          fallo!(e.respond_to?(:codigo) ? e.codigo : e.message)
        end

        case estado
        # Si se extrajo el sobre
        when :en_espera
          flash[:mensaje] = "Gracias por utilizar la terminal."
          flash[:tipo] = "alert-success"

          case sub_estado
          when :extraccion_correcta
            Log.info "Sobre entregado a cliente #{cliente.nro_documento}"

            # En vez de borrar el sobre lo marcamos como entregado
            sobre.update_attributes estado: "entregado", posicion: nil

            # Si todavía hay sobres, continuamos la extracción
            if cliente.sobres.montados.any?
              flash[:mensaje] = "Sobres restantes: #{cliente.sobres.montados.count}."
              siguiente = "/extraccion"
            end
          when :no_hay_sobre_en_rodete
            # Si no hay sobre
            Log.info "No hay sobre #{sobre.posicion} en rodete"

            flash[:mensaje] = "No encontramos tu tarjeta en esta terminal, por favor comunicate con un administrador."
            flash[:tipo] = "alert-danger"
          when :sobre_no_retirado
            # Si no se retiro el sobre
            Log.info "Sobre no retirado. Cliente: #{cliente.nro_documento}. Posicion: #{sobre.posicion}"

            flash[:mensaje] = "Sobre no retirado."
            flash[:tipo] = "alert-danger"
          else
            Log.info "SubEstado de extracción desconocido: #{sub_estado}. #{resp}"

            flash[:mensaje] = "Ocurrió un error."
            flash[:tipo] = "alert-danger"
          end
        when :modo_manual
          flash[:mensaje] = "Modo manual."
          flash[:tipo] = "alert-danger"
        when :emergencia_superable
          flash[:mensaje] = "Emergencia."
          flash[:tipo] = "alert-danger"
        else
          Log.info "Error en extracción de sobre en posición #{sobre.posicion}. #{resp}"

          flash[:mensaje] = "Ocurrió un error."
          flash[:tipo] = "alert-danger"
        end
      else
        flash[:mensaje] = "No tiene tarjetas disponibles."
        flash[:tipo] = "alert-danger"
      end

      res.redirect siguiente
    end

    # Control de acceso de administradores para el bloque completo
    on "admin" do
      garantizar_admin!

      on "configurar" do
        on param("nombre_archivo_novedades"), param("prefijo_nro_proveedor") do |nombre_archivo_novedades, prefijo_nro_proveedor|
          Configuracion.config.update_attributes(
            nombre_archivo_novedades: nombre_archivo_novedades,
            prefijo_nro_proveedor: prefijo_nro_proveedor,
          )

          mensaje = "Configuración actualizada."
          Log.info mensaje
          flash[:mensaje] = mensaje
          flash[:tipo] = "alert-info"

          # Siempre volvemos al inicio del administrador
          res.redirect "/admin/panel"
        end
      end

      on "usuarios" do
        garantizar_superadmin!

        # Procesar nuevo usuario
        on "crear" do
          on param("nombre"), param("nro_documento"), param("password") do |nombre, nro_documento, password|
            usuario = Admin.create nombre: nombre, nro_documento: nro_documento, password: password

            if usuario.persisted?
              mensaje = "El usuario #{nombre} ha sido creado"
              Log.info mensaje
              flash[:mensaje] = mensaje
              flash[:tipo] = "alert-success"
            else
              mensaje = "No pudo crearse el usuario. #{usuario.errors.full_messages.to_sentence}"
              Log.error mensaje
              flash[:mensaje] = mensaje
              flash[:tipo] = "alert-danger"
            end

            res.redirect "/admin/usuarios"
          end
        end

        on ":id" do |id|
          usuario = Admin.normal.find(id)

          # Técnicamente debería ser un DELETE
          on "eliminar" do
            usuario.destroy

            if usuario.destroyed?
              mensaje = "El usuario #{usuario.nombre} ha sido eliminado"
              Log.info mensaje
              flash[:mensaje] = mensaje
              flash[:tipo] = "alert-success"
            else
              mensaje = "No pudo eliminarse el usuario. #{usuario.errors.full_messages.to_sentence}"
              Log.error mensaje
              flash[:mensaje] = mensaje
              flash[:tipo] = "alert-danger"
            end

            res.redirect "/admin/usuarios"
          end

          # Procesar el formulario de edit
          on "editar" do
            on param("nombre"), param("nro_documento") do |nombre, nro_documento|
              # Password es opcional
              password = req.params["password"]

              if usuario.update nombre: nombre, nro_documento: nro_documento, password: password
                mensaje = "El usuario #{nombre} ha sido modificado"
                Log.info mensaje
                flash[:mensaje] = mensaje
                flash[:tipo] = "alert-success"
              else
                mensaje = "No pudo modificarse el usuario. #{usuario.errors.full_messages.to_sentence}"
                Log.error mensaje
                flash[:mensaje] = mensaje
                flash[:tipo] = "alert-danger"
              end

              res.redirect "/admin/usuarios"
            end
          end
        end
      end

      on "clientes" do
        # Carga el sobre correspondiente
        on ":id/cargar" do |id|
          sobre = Sobre.find id
          posicion_libre = Nucleo.posicion_libre

          if sobre.present? && posicion_libre
            begin
              estado, sub_estado, flags, resp, _ = Nucleo.cargar!(posicion_libre).values_at(:estado, :sub_estado, :flags, :resp)
            rescue => e
              fallo!(e.respond_to?(:codigo) ? e.codigo : e.message)
            end

            case estado
            when :en_espera
              flash[:mensaje] = "El sobre ha sido guardado correctamente."
              flash[:tipo] = "alert-success"

              if flags[10] == "1"
                Log.info "Presentador cargado"

                flash[:mensaje] = "Presentador cargado. Realizar una Extracción Directa"
                flash[:tipo] = "alert-danger"
              else
                case sub_estado
                when :carga_correcta
                  # Si se cargo el sobre
                  Log.info "Sobre cargado en posición #{posicion_libre}"

                  sobre.update_attributes posicion: posicion_libre, estado: "montado"
                when :sobre_no_introducido
                  # Si no introdujo sobre
                  Log.info "Sobre no introducido"

                  flash[:mensaje] = "Sobre no introducido."
                  flash[:tipo] = "alert-danger"
                when :posicion_ocupada
                  # Si no introdujo sobre
                  Log.info "Posición ocupada"

                  flash[:mensaje] = "Posición ocupada en máquina."
                  flash[:tipo] = "alert-danger"
                when :dispenser_lleno
                  # Si no introdujo sobre
                  Log.info "Dispenser lleno"

                  flash[:mensaje] = "Dispenser Lleno!"
                  flash[:tipo] = "alert-danger"
                when :sobre_fuera_de_medida
                  # Si no introdujo sobre
                  Log.info "Sobre fuera de medidas"

                  flash[:mensaje] = "Sobre fuera de medidas."
                  flash[:tipo] = "alert-danger"
                else
                  Log.error "SubEstado de carga desconocido: #{sub_estado}. #{resp}"

                  flash[:mensaje] = "Ocurrió un error."
                  flash[:tipo] = "alert-danger"
                end
              end
            when :modo_manual
              flash[:mensaje] = "Modo manual."
              flash[:tipo] = "alert-danger"
            else
              Log.error "Error en carga de sobre en posición #{posicion_libre}. #{resp}"

              flash[:mensaje] = "Ocurrió un error"
              flash[:tipo] = "alert-danger"
            end
          elsif sobre.present? && !posicion_libre
            flash[:mensaje] = "No hay posiciones libres."
            flash[:tipo] = "alert-danger"
          else
            flash[:mensaje] = "El identificador no pertenece a un sobre válido."
            flash[:tipo] = "alert-danger"
          end

          # Volvemos a la lista de clientes
          res.redirect "/admin/clientes"
        end

        on ":id/manualmente" do |id|
          sobre = Sobre.find id
          begin
            if sobre.present?
              Log.info "Sobre extraido Manualmente"
              sobre.update_attributes estado: "manualmente", posicion: nil
            end
          end
          res.redirect "/admin/clientes"
        end

        on ":id/extraer" do |id|
          sobre = Sobre.find id

          if sobre.present?
            begin
              estado, sub_estado, flags, resp, _ = Nucleo.extraer!(sobre.posicion).values_at(:estado, :sub_estado, :flags, :resp)
            rescue => e
              fallo!(e.respond_to?(:codigo) ? e.codigo : e.message)
            end

            case estado
            when :en_espera
              flash[:mensaje] = "El sobre ha sido descargado."
              flash[:tipo] = "alert-success"

              if flags[10] == "1"
                Log.info "Presentador cargado"

                flash[:mensaje] = "Presentador cargado. Realizar una Extracción Directa"
                flash[:tipo] = "alert-danger"
              else
                case sub_estado
                when :extraccion_correcta
                  # Si se extrajo el sobre
                  Log.info "Sobre descargado de posicion #{sobre.posicion}"

                  # En vez de borrar el sobre lo marcamos como entregado
                  sobre.update_attributes estado: "descargado", posicion: nil
                when :no_hay_sobre_en_rodete
                  # Si no hay sobre
                  Log.info "No hay sobre #{sobre.posicion} en rodete"

                  flash[:mensaje] = "No hay sobre en rodete."
                  flash[:tipo] = "alert-danger"
                when :sobre_no_retirado
                  # Si no se retiro el sobre
                  Log.info "Sobre no retirado"

                  flash[:mensaje] = "Sobre no retirado."
                  flash[:tipo] = "alert-danger"
                else
                  Log.info "SubEstado de extracción desconocido: #{sub_estado}. #{resp}"

                  flash[:mensaje] = "Ocurrió un error."
                  flash[:tipo] = "alert-danger"
                end
              end
            when :modo_manual
              flash[:mensaje] = "Modo manual."
              flash[:tipo] = "alert-danger"
            when :emergencia_superable
              flash[:mensaje] = "Emergencia."
              flash[:tipo] = "alert-danger"
            else
              Log.info "Error en descarga de sobre en posición #{sobre.posicion}. #{resp}"

              flash[:mensaje] = "Ocurrió un error"
              flash[:tipo] = "alert-danger"
            end
          else
            flash[:mensaje] = "El identificador no pertenece a un sobre válido."
            flash[:tipo] = "alert-danger"
          end

          # Volvemos a la lista de clientes
          res.redirect "/admin/clientes"
        end
      end
    end
  end
end
