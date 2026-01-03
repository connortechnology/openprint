function delete_input( id ) {
  fetch('_input.html?action=delete&id='+id)
    .then(response => {
      if (response.ok) {
        var tr = document.getElementById('i'+id);
        if (tr && tr.parentNode) {
          tr.parentNode.removeChild(tr);
        }
        if (window.SortableTable) SortableTable.load();
      }
    });
}
function copy_input( id ) {
  fetch('_input.html?action=copy&id='+id)
    .then(response => response.text())
    .then(html => {
      const elem = document.getElementById('i'+id);
      if (elem) {
        elem.insertAdjacentHTML('afterend', html);
      }
      if (window.SortableTable) SortableTable.load();
    });
}
function add_input(s_id) {
  fetch('_input.html?action=add&sensor_id='+s_id)
    .then(response => response.text())
    .then(html => {
      const elem = document.getElementById('inputs_body');
      if (elem) {
        elem.insertAdjacentHTML('afterbegin', html);
      }
    });
} // end function add_input
