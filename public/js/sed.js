var noInteraction;

function invocation() {
  var timeout = window.admin ? 60000 : window.logged ? 30000 : 45000;
  var path = window.logged ? "/saliendo" : "/";

  noInteraction = window.setTimeout(function() {
    window.location.replace(path);
  }, timeout);
}

$(function() {
  // Evitar doble submit, con jquery-ujs:
  //
  //   data-disable-with="Enviando..."
  //
  // Igualmente bloqueamos toda la página cuando hay varias acciones posibles
  $(".bloqueador").click(function() {
    $.blockUI({ message: null });
  });

  $(".bloqueador-confirm").click(function(e) {
    e.preventDefault();
    var r = confirm("Está seguro?");
    if (r == true) {
      $.blockUI({ message: null });
      window.location.replace($(this).attr("href"));
    }
  });

  // Volver al login después de 10 segundos sin interacción del cliente
  if ($(".saliendo").length > 0) {
    window.setTimeout(function() {
      window.location.replace("/");
    }, 10000);
  }

  if (window.refresh) {
    $(document).on("touchstart", function() {
      clearTimeout(noInteraction);
      invocation();
    });

    $(document).on("click", function() {
      clearTimeout(noInteraction);
      invocation();
    });

    invocation();
  }
});

// Anular el menú contextual
$(document).on("contextmenu", function(event) {
  event.preventDefault();
});
