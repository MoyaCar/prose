# Utilidades para los controladores
module ControllerHelpers
  def usuario_actual_admin?
    session[:usuario_actual_tipo] == "Admin"
  end

  def usuario_actual_cliente?
    session[:usuario_actual_tipo] == "Cliente"
  end

  def garantizar_admin!
    if usuario_actual_admin?
      usuario = Admin.find(session[:usuario_actual_id])
    else
      no_autorizado!
    end

    no_autorizado! unless usuario.admin?
  rescue ActiveRecord::RecordNotFound
    no_autorizado!
  end

  def garantizar_superadmin!
    usuario = Admin.find(session[:usuario_actual_id])

    no_autorizado! unless usuario.super?
  rescue ActiveRecord::RecordNotFound
    no_autorizado!
  end

  # TODO Ver por qué se limpia el flash al redirigir
  def no_autorizado!
    flash[:tipo] = "alert-danger"
    flash[:mensaje] = "No está autorizado a realizar esta acción."

    render "inicio", titulo: "Retirá tu tarjeta", admin: false, refresh: false

    res.status = 401

    # Cortar la renderización explícitamente
    halt res.finish
  end

  def fallo!(codigo, status: 503)
    Log.error "Error codigo #{codigo}"

    render "error",
      admin: false,
      titulo: "Equipo fuera de servicio",
      error: "Se ha producido un error, por favor contacte a un
      administrador del Banco.",
      codigo: "Error código #{codigo}",
      refresh: false

    res.status = status

    # Cortar la renderización explícitamente
    halt res.finish
  end
end
