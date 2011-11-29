jQuery(document).ready(function($) {
	
	$('input.foswikiFocus').livequery(function() {
		$(this).focus();
	});
	
	// stick topic action to top
	var offset = $('.foswikiTopicActions').offset();
	var INITIAL_TOPIC_ACTIONS_Y = offset.top;
	var INITIAL_TOPIC_ACTIONS_LEFT = offset.left;

	$(window).scroll(function() {
    	if ($(window).scrollTop() >= INITIAL_TOPIC_ACTIONS_Y) {
        	$('.foswikiTopicActions').css({
        		position: 'fixed',
        		left: INITIAL_TOPIC_ACTIONS_LEFT,
        		top: 0
        	});
		} else {
			$('.foswikiTopicActions').css({
				position: 'absolute',
				right: 0,
				top: INITIAL_TOPIC_ACTIONS_Y
			});
		}
	});

	var SCROLL_DURATION = 250;
	var SCROLL_ANCHOR_OFFSET = 20;
	var scrollOpts = {
		reset: true,
		lazy: true,
		hash: true,
		duration: SCROLL_DURATION,
		axis: 'y',
		offset: { top:-($('.foswikiTopbar').height() + SCROLL_ANCHOR_OFFSET), left:0 },
		easing: 'swing'
	};
	$('a').localScroll(scrollOpts);

	// also scroll on page load
	var anchor = getAnchor();
	if (anchor) {
		var $target = $('a[name=' + anchor + ']');
		if ($target.length === 0) {
			$target = $('#' + anchor);
		}
		if ($target.length !== 0) {
			$('body').scrollTo( $target, SCROLL_DURATION, scrollOpts );
		}
	}

});



function getAnchor( url ) {
	url = url || location.href;
	return url.replace( /^[^#]*#?(.*)$/, '$1' );
};