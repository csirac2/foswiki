(function($) {
  $(function() {
    $("#displaycomments_on, #displaycomments_off").change(function() {
      $("#cmtPreferences").animate({opacity:'toggle'});
    });
  });
})(jQuery);

