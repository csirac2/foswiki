;(function($){$.extend($.fn,{swapClass:function(c1,c2){var c1Elements=this.filter('.'+c1);this.filter('.'+c2).removeClass(c2).addClass(c1);c1Elements.removeClass(c1).addClass(c2);return this;},replaceClass:function(c1,c2){return this.filter('.'+c1).removeClass(c1).addClass(c2).end();},hoverClass:function(className){className=className||"hover";return this.hover(function(){$(this).addClass(className);},function(){$(this).removeClass(className);});},heightToggle:function(animated,callback){animated?this.animate({height:"toggle"},animated,callback):this.each(function(){jQuery(this)[jQuery(this).is(":hidden")?"show":"hide"]();if(callback)
callback.apply(this,arguments);});},heightHide:function(animated,callback){if(animated){this.animate({height:"hide"},animated,callback);}else{this.hide();if(callback)
this.each(callback);}},prepareBranches:function(settings){if(!settings.prerendered){this.filter(":last-child:not(ul)").addClass(CLASSES.last);this.filter((settings.collapsed?"":"."+CLASSES.closed)+":not(."+CLASSES.open+")").find(">ul").hide();}
return this.filter(":has(>ul)");},applyClasses:function(settings,toggler){this.filter(":has(>ul):not(:has(>a))").find(">span").unbind("click.treeview").bind("click.treeview",function(event){if(this==event.target)
toggler.apply($(this).next());}).add($("a",this)).hoverClass();if(!settings.prerendered){this.filter(":has(>ul:hidden)")
.addClass(CLASSES.expandable)
.replaceClass(CLASSES.last,CLASSES.lastExpandable);this.not(":has(>ul:hidden)")
.addClass(CLASSES.collapsable)
.replaceClass(CLASSES.last,CLASSES.lastCollapsable);this.prepend("<div class=\""+CLASSES.hitarea+"\"/>").find("div."+CLASSES.hitarea).each(function(){var classes="";$.each($(this).parent().attr("class").split(" "),function(){classes+=this+"-hitarea ";});$(this).addClass(classes);});}
this.find("div."+CLASSES.hitarea).click(toggler);},treeview:function(settings){settings=$.extend({cookieId:"treeview"},settings);if(settings.add){return this.trigger("add",[settings.add]);}
if(settings.toggle){var callback=settings.toggle;settings.toggle=function(){return callback.apply($(this).parent()[0],arguments);};}
function treeController(tree,control){function handler(filter){return function(){toggler.apply($("div."+CLASSES.hitarea,tree).filter(function(){return filter?$(this).parent("."+filter).length:true;}));return false;};}
$("a:eq(0)",control).click(handler(CLASSES.collapsable));$("a:eq(1)",control).click(handler(CLASSES.expandable));$("a:eq(2)",control).click(handler());}
function toggler(){$(this)
.parent()
.find(">.hitarea")
.swapClass(CLASSES.collapsableHitarea,CLASSES.expandableHitarea)
.swapClass(CLASSES.lastCollapsableHitarea,CLASSES.lastExpandableHitarea)
.end()
.swapClass(CLASSES.collapsable,CLASSES.expandable)
.swapClass(CLASSES.lastCollapsable,CLASSES.lastExpandable)
.find(">ul")
.heightToggle(settings.animated,settings.toggle);if(settings.unique){$(this).parent()
.siblings()
.find(">.hitarea")
.replaceClass(CLASSES.collapsableHitarea,CLASSES.expandableHitarea)
.replaceClass(CLASSES.lastCollapsableHitarea,CLASSES.lastExpandableHitarea)
.end()
.replaceClass(CLASSES.collapsable,CLASSES.expandable)
.replaceClass(CLASSES.lastCollapsable,CLASSES.lastExpandable)
.find(">ul")
.heightHide(settings.animated,settings.toggle);}}
function serialize(){function binary(arg){return arg?1:0;}
var data=[];branches.each(function(i,e){data[i]=$(e).is(":has(>ul:visible)")?1:0;});$.cookie(settings.cookieId,data.join(""));}
function deserialize(){var stored=$.cookie(settings.cookieId);if(stored){var data=stored.split("");branches.each(function(i,e){$(e).find(">ul")[parseInt(data[i])?"show":"hide"]();});}}
this.addClass("treeview");var branches=this.find("li").prepareBranches(settings);switch(settings.persist){case"cookie":var toggleCallback=settings.toggle;settings.toggle=function(){serialize();if(toggleCallback){toggleCallback.apply(this,arguments);}};deserialize();break;case"location":var current=this.find("a").filter(function(){return this.href.toLowerCase()==location.href.toLowerCase();});if(current.length){current.addClass("selected").parents("ul, li").add(current.next()).show();}
break;}
branches.applyClasses(settings,toggler);if(settings.control){treeController(this,settings.control);$(settings.control).show();}
return this.bind("add",function(event,branches){$(branches).prev()
.removeClass(CLASSES.last)
.removeClass(CLASSES.lastCollapsable)
.removeClass(CLASSES.lastExpandable)
.find(">.hitarea")
.removeClass(CLASSES.lastCollapsableHitarea)
.removeClass(CLASSES.lastExpandableHitarea);$(branches).find("li").andSelf().prepareBranches(settings).applyClasses(settings,toggler);});}});var CLASSES=$.fn.treeview.classes={open:"open",closed:"closed",expandable:"expandable",expandableHitarea:"expandable-hitarea",lastExpandableHitarea:"lastExpandable-hitarea",collapsable:"collapsable",collapsableHitarea:"collapsable-hitarea",lastCollapsableHitarea:"lastCollapsable-hitarea",lastCollapsable:"lastCollapsable",lastExpandable:"lastExpandable",last:"last",hitarea:"hitarea"};$.fn.Treeview=$.fn.treeview;})(jQuery);;
