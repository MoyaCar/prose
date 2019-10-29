// https://github.com/cozyt/softkey/blob/79c80ff2b602d3759e3b789ab636cff2f4104088/index.html
//
// Está presente en pantalla y es asociado y re-asociado cuando se enfoca en
// los diferentes inputs
var layoutNumerico = [
  [
    '7', '8', '9'
  ], [
    '4', '5', '6'
  ], [
    '1', '2', '3'
  ], [
    '0', 'delete'
  ]
]

var layoutAlfanumerico = [
  [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '_'
  ], [
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', 'delete'
  ], [
    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'shift'
  ], [
    'z', 'x', 'c', 'v', 'b', 'n', 'm', 'space'
  ]
]

// El div donde inicializar el teclado virtual
var elemento = '<div class="teclado"></div>'
// El elemento de 'teclado' actual
var teclado = null

$(document).on('focus', 'input.enfocable', function() {
  // FIXME Ver de ocultar en vez de remover para que funcione shift y capslock
  $(teclado).remove()

  $('.teclado-contenedor').append(elemento)

  layout = $(this).data('teclado') == 'alfanumerico' ? layoutAlfanumerico : layoutNumerico

  teclado = $('.teclado').softkeys({
    target : $(this).data('target'),
    layout : layout
  })
})

$(function() {
  $('.teclado-modal').softkeys({
    target: "input[name='filtro']",
    layout: layoutAlfanumerico
  })
})
