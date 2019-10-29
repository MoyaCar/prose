$(function() {
  // Leer y remover la página actual del storage
  pagina = Number(localStorage.getItem("pagina-actual"));
  localStorage.removeItem("pagina-actual");

  $(".data-table").DataTable({
    language: {
      url: "/js/datatables.es.json"
    },
    pageLength: 5,
    displayStart: 5 * pagina,
    pagingType: "full_numbers",
    lengthChange: false,
    columns: [null, null, { orderable: false }],
    dom:
      "<'row'<'col-md-6'l><'col-md-6'>>" +
      "<'row'<'col-md-12'tr>>" +
      "<'row fondo'<'col-md-12'p>>" +
      "<'row'<'col-md-12'i>>"
  });

  $(".data-table-logs").DataTable({
    language: {
      url: "/js/datatables.es.json"
    },
    pageLength: 15,
    displayStart: 15 * pagina,
    pagingType: "full_numbers",
    lengthChange: false,
    order: [[1, "desc"]],
    dom:
      "<'row'<'col-md-6'l><'col-md-6'>>" +
      "<'row'<'col-md-12'tr>>" +
      "<'row fondo'<'col-md-12'p>" +
      "<'col-md-12'i>>"
  });

  $(".data-table-clientes").DataTable({
    language: {
      url: "/js/datatables.es.json"
    },
    pageLength: 15,
    displayStart: 15 * pagina,
    pagingType: "full_numbers",
    lengthChange: false,
    columns: [null, null, null, null, null, { orderable: false }],
    dom:
      "<'row'<'col-md-6'l><'col-md-6'>>" +
      "<'row'<'col-md-12'tr>>" +
      "<'row fondo'<'col-md-12'p>" +
      "<'col-md-12'i>>",
    initComplete: function() {
      this.api()
        .columns()
        .every(function() {
          var column = this;

          if (column[0][0] == 3) {
            var select = $('<select><option value=""></option></select>')
              .appendTo($(column.footer()).empty())
              .on("change", function() {
                var val = $.fn.dataTable.util.escapeRegex($(this).val());

                column.search(val ? "^" + val + "$" : "", true, false).draw();
              });

            column
              .data()
              .unique()
              .sort()
              .each(function(d, j) {
                select.append('<option value="' + d + '">' + d + "</option>");
              });
          }
        });
    }
  });
});

$(document).on("input", "input.filtro", function() {
  $(".data-table, .data-table-clientes")
    .DataTable()
    .search(this.value)
    .draw();
});

// Guardar la página actual después de cada acción en la tabla
$(document).on("click", ".capturar-pagina", function() {
  pagina = $(".table")
    .DataTable()
    .page();

  localStorage.setItem("pagina-actual", pagina);
});
