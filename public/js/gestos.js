$(function() {
  var superficie = $("#tocable");

  if (superficie.length > 0) {
    var abajo,
      derecha,
      arriba = false;

    // Pasar sólo el primer (y único) elemento
    var manager = new Hammer.Manager(superficie[0]);

    // Reconocedor custom
    var AdminTap = new Hammer.Tap({
      event: "admintap",
      taps: 5,
      // Milisegundos entre taps
      interval: 1000,
      // Milisegundos que puede presionar
      time: 500
    });

    // Agregar el reconocedor al manager
    manager.add(AdminTap);

    // Subscribe to the event.
    manager.on("admintap", function(e) {
      window.location.href = "/admin-login";
    });
  }

  var reboot = $("#reboot");

  if (reboot.length > 0) {
    var abajo,
      derecha,
      arriba = false;

    // Pasar sólo el primer (y único) elemento
    var manager = new Hammer.Manager(reboot[0]);

    // Reconocedor custom
    var RebootTap = new Hammer.Tap({
      event: "reboottap",
      taps: 10,
      // Milisegundos entre taps
      interval: 1000,
      // Milisegundos que puede presionar
      time: 500
    });

    // Agregar el reconocedor al manager
    manager.add(RebootTap);

    // Subscribe to the event.
    manager.on("reboottap", function(e) {
      var c = confirm("Seguro desea reiniciar?");
      if (c === true) {
        window.location.href = "/reboot";
      }
    });
  }
});
