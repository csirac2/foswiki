(function($){$.superfish={};$.superfish.o=[];$.superfish.op={};$.superfish.defaults={hoverClass:'sfHover',pathClass:'overideThisToUse',delay:800,animation:{opacity:'show'},speed:'normal',oldJquery:false,disableHI:false,onInit:function(){},onBeforeShow:function(){},onShow:function(){},onHide:function(){}};$.fn.superfish=function(op){var bcClass='sfbreadcrumb',over=function(){var $$=$(this),menu=getMenu($$);getOpts(menu,true);clearTimeout(menu.sfTimer);$$.showSuperfishUl().siblings().hideSuperfishUl();},out=function(){var $$=$(this),menu=getMenu($$);var o=getOpts(menu,true);clearTimeout(menu.sfTimer);if(!$$.is('.'+bcClass)){menu.sfTimer=setTimeout(function(){$$.hideSuperfishUl();if(o.$path.length){over.call(o.$path);}},o.delay);}},getMenu=function($el){return $el.parents('ul.superfish:first')[0];},getOpts=function(el,menuFound){el=menuFound?el:getMenu(el);return $.superfish.op=$.superfish.o[el.serial];},hasUl=function(){return $.superfish.op.oldJquery?'li[ul]':'li:has(ul)';};return this.each(function(){var s=this.serial=$.superfish.o.length;var o=$.extend({},$.superfish.defaults,op);o.$path=$('li.'+o.pathClass,this).each(function(){$(this).addClass(o.hoverClass+' '+bcClass)
.filter(hasUl()).removeClass(o.pathClass);});$.superfish.o[s]=$.superfish.op=o;$(hasUl(),this)[($.fn.hoverIntent&&!o.disableHI)?'hoverIntent':'hover'](over,out)
.not('.'+bcClass)
.hideSuperfishUl();var $a=$('a',this);$a.each(function(i){var $li=$a.eq(i).parents('li');$a.eq(i).focus(function(){over.call($li);}).blur(function(){out.call($li);});});o.onInit.call(this);}).addClass('superfish');};$.fn.extend({hideSuperfishUl:function(){var o=$.superfish.op,$ul=$('li.'+o.hoverClass,this).add(this).removeClass(o.hoverClass)
.find('>ul').hide().css('visibility','hidden');o.onHide.call($ul);return this;},showSuperfishUl:function(){var o=$.superfish.op,$ul=this.addClass(o.hoverClass)
.find('>ul:hidden').css('visibility','visible');o.onBeforeShow.call($ul);$ul.animate(o.animation,o.speed,function(){o.onShow.call(this);});return this;}});$(window).unload(function(){$('ul.superfish').each(function(){$('li',this).unbind('mouseover','mouseout','mouseenter','mouseleave');});});})(jQuery);;
