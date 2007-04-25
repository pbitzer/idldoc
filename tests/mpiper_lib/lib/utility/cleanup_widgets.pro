;+
; Cleanup routine for every object-widget program that has a
; "cleanup_widgets" method that takes the top-level base widget
; identifier as its only positional parameter.
;
; @author Michael Galloy, 2002
;-
pro cleanup_widgets, top
	compile_opt idl2

	widget_control, top, get_uvalue=self
	self->cleanup_widgets, top
end
