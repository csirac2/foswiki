function checkAll(form, theCheck) {
  var j = 0;
  for( var i = 0; i < document.forms[form].length; i++ ) {
    var elem = document.forms[form].elements[i];
    var name = elem.getAttribute('name');
    if (elem.type == 'checkbox' && name != 'nonwikiword' && name != 'totrash') {
      elem.checked = theCheck;
    }
  }
}
