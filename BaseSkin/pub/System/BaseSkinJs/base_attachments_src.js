var COOKIE_SHOWATTACHMENT_DETAILS = 'COOKIE_SHOWATTACHMENT_DETAILS';

jQuery(document).ready(function ($) {

	function sort($el, sort) {
		
		// TODO:

		// sort direction feedback
		// put sort plugin in separate plugin and give author due copyright
		
		var direction = $el.attr('data-sort-direction');
		if (direction === undefined) {
			direction = 1;
		}
		if (sort === 'data-date' || sort === 'data-rev') {
			// latest on top
			direction = -direction;
		}
		var compare;
		var type = 'string';
		if (sort === 'data-size' || sort === 'data-date') {
			// number
			comparator = function(a, b) {
				return parseInt($(a).attr(sort), 10) > parseInt($(b).attr(sort), 10) ? direction : -direction;
			};
		} else {
			// string
			comparator = function(a, b) {
				return $(a).attr(sort) > $(b).attr(sort) ? direction : -direction;
			};
		}
		// find parent with class 'foswikiAttachments
		var $attachments = $el.parents('.foswikiAttachments');
		
		$('.foswikiAttachment', $attachments).sortElements(comparator);
		/*
		direction = -direction;
		$el.attr('data-sort-direction', direction);
		*/
		return false;
	}
	
	// find currently selected value and sort
	$('select.foswikiSort').livequery(function() {
		sort($(this), $(this).val());
		return false;
	});
	
	$('select.foswikiSort').livequery('change', function() {
		sort($(this), $(this).val());
		return false;
	});
	
	function toggleAttachmentDetails($el, showDetails) {			
		// find corresponding foswikiAttachments
		var $attachments = $el.parents('.foswikiAttachments');
		if (showDetails) {
			$attachments.removeClass('bsHideDetails');
		} else {
			$attachments.addClass('bsHideDetails');
		}
	}
	
	$(':checkbox[name="showdetails"]').livequery(function () {
		var pref = parseInt(foswiki.Pref.getPref(COOKIE_SHOWATTACHMENT_DETAILS), 10);
		if (pref) {
			$(this).attr('checked', true);
		} else {
			$(this).removeAttr('checked');
		}
		var showDetails = $(this).is(':checked') ? 1 : 0;
		toggleAttachmentDetails($(this), showDetails);
	});
	
	$(':checkbox[name="showdetails"]').livequery('change', function () {
		var showDetails = $(this).attr('checked') ? 1 : 0;
		toggleAttachmentDetails($(this), showDetails);
		foswiki.Pref.setPref(COOKIE_SHOWATTACHMENT_DETAILS, showDetails);
	});
	
	$('.foswikiAttachment .bsVersions').livequery(function() {
		var PUBURL = foswiki.getPreference('PUBURLPATH') + '/' + foswiki.getPreference('SYSTEMWEB') + '/' + 'BaseSkinJs/';
		
		var url = $(this).attr('href') + ';cover=baseajax;def=history';
		
		//$(this).addClass('jqSimpleModal {url: \'' + url + '\'}');
	});

	$('.foswikiAttachment .bsVersions').bind('hidden', function () {
		console.log("click .foswikiAttachment .bsVersions:" + $(this).attr('href'));
	})
/*
	$('.foswikiAttachment .bsVersions').livequery('click', function() {
		var PUBURL = foswiki.getPreference('PUBURLPATH') + '/' + foswiki.getPreference('SYSTEMWEB') + '/' + 'BaseSkinJs/';
		
		$.facebox.settings.closeImage = PUBURL + 'closelabel.png';
		$.facebox.settings.loadingImage = PUBURL + 'loading.gif';

		console.log("PUBURL=" + PUBURL);
		
		var url = $(this).attr('href') + ';cover=baseajax;def=history';
		console.log(url);
		return false;
	});
*/

});



/**
 * jQuery.fn.sortElements
 * --------------
 * @author James Padolsey (http://james.padolsey.com)
 * @version 0.11
 * @updated 18-MAR-2010
 * --------------
 * @param Function comparator:
 *   Exactly the same behaviour as [1,2,3].sort(comparator)
 *   
 * @param Function getSortable
 *   A function that should return the element that is
 *   to be sorted. The comparator will run on the
 *   current collection, but you may want the actual
 *   resulting sort to occur on a parent or another
 *   associated element.
 *   
 *   E.g. $('td').sortElements(comparator, function(){
 *      return this.parentNode; 
 *   })
 *   
 *   The <td>'s parent (<tr>) will be sorted instead
 *   of the <td> itself.
 */
jQuery.fn.sortElements = (function(){
    
    var sort = [].sort;
    
    return function(comparator, getSortable) {
        
        getSortable = getSortable || function(){return this;};
        
        var placements = this.map(function(){
            
            var sortElement = getSortable.call(this),
                parentNode = sortElement.parentNode,
                
                // Since the element itself will change position, we have
                // to have some way of storing it's original position in
                // the DOM. The easiest way is to have a 'flag' node:
                nextSibling = parentNode.insertBefore(
                    document.createTextNode(''),
                    sortElement.nextSibling
                );
            
            return function() {
                
                if (parentNode === this) {
                    throw new Error(
                        "You can't sort elements if any one is a descendant of another."
                    );
                }
                
                // Insert before flag:
                parentNode.insertBefore(this, nextSibling);
                // Remove flag:
                parentNode.removeChild(nextSibling);
                
            };
            
        });
       
        return sort.call(this, comparator).each(function(i){
            placements[i].call(getSortable.call(this));
        });
        
    };
    
})();