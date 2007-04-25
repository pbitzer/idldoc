pro im_engine::restore_interface
    compile_opt idl2

    if widget_info(self.top, /valid_id) then return
    self->create_widgets
    self->realize
    self->display
    self->start_xmanager
end


;+
; @keyword new_image {in}{type=object} An image object to be set as
;   the current image in the display. 
;-
pro im_engine::set, new_image=oimage_new, kill_object=ko, scr_xsize=scrx, $
             scr_ysize=scry
    compile_opt idl2

    if obj_valid(oimage_new) then begin
        oimage_new->getproperty, data=new
        obj_destroy, oimage_new
        self.oimage->setproperty, data=new
        if self.histogram->is_visible() then self.histogram->display
        self->display
    endif
    
    if keyword_set(ko) then self.kill_object = 1

    if n_elements(scrx) ne 0 then begin
        device, get_screen_size=ss
        self.scr_xsize = scrx < 0.8*ss[0]
        widget_control, self.draw, xsize=self.scr_xsize
    endif

    if n_elements(scry) ne 0 then begin
        device, get_screen_size=ss
        self.scr_ysize = scry < 0.8*ss[1]
        widget_control, self.draw, ysize=self.scr_ysize
    endif
end


pro im_engine::get
    compile_opt idl2

end


;==============================================================================
;+
; This method performs a registered image processing operation, resulting
; in a new image.
;
; @param op {in}{type=object} An image processing operation object, an
;   instance of a subclass of <code>im_operator</code>.
;-
pro im_engine::perform_op, op
    compile_opt idl2

    oimage_new = op->do_it(self.oimage)
    self->set, new_image=oimage_new
end


;==============================================================================
;+
; Creates an image processing operation. If macro recording is on, the
; operation is added to the macro.
;
; @param class_name {in}{type=string} The name of the class in which
;   the image processing operation is defined.
;-
pro im_engine::create_op, class_name
    compile_opt idl2

    op = obj_new(class_name)
    self->perform_op, op
    obj_destroy, op
end


;==============================================================================
;+
; Adds a menu entry in the UI for the requested image operation.
;
; @param class_name {in}{type=string} The name of the class used to
;   define the operation.
; @param menu_name {in}{type=string} The name displayed in the menu
;   entry.
;-
pro im_engine::register_op, class_name, menu_name
    compile_opt idl2

    op_menu = widget_info(self.top, find_by_uname='image_op_menu')
    new_op_button = widget_button(op_menu, value=menu_name, $
                                  uname='image_op:' + class_name)
end


pro im_engine::handle_events, event
    compile_opt idl2

    uname = widget_info(event.id, /uname)
    case uname of
        'draw' : self->display
        'exit' : widget_control, self.top, /destroy
        'histogram' : begin
            if not self.histogram->is_visible() then begin
                self.histogram->create_widgets
                self.histogram->realize
                self.histogram->set, image=self.oimage
                self.histogram->start_xmanager
            endif
        end
        else : begin ; perform an operation
            if (stregex(uname, '^image_op:') ne -1) then begin
                subs = stregex(uname, '^image_op:(.*)', $
                               /subexpr, /extract)
                class_name = subs[1]
                self->create_op, class_name
            endif else begin
                ok = dialog_message('Unknown operation: "' $
                                    + uname + '" occurred.')
            endelse
        end
    endcase
end


pro im_engine::cleanup_widgets, top
    compile_opt idl2

    self.histogram->kill_widgets
    if self.kill_object then obj_destroy, self
end


pro im_engine::start_xmanager
    compile_opt idl2

    xmanager, obj_class(self), self.top, $
        /no_block, $
        event_handler='handle_events', $
        cleanup='cleanup_widgets'
end


pro im_engine::display
    compile_opt idl2

    self.owindow->draw, self.oviewgroup
end


pro im_engine::build_object_tree
    compile_opt idl2

    self.oviewgroup = obj_new('idlgrviewgroup', name='viewgroup')
    self.oimage->getproperty, dimensions=dims
    oview = obj_new('idlgrview', $
                    viewplane_rect=[0, 0, dims[0], dims[1]], $
                    name='view')
    omodel = obj_new('idlgrmodel', name='model')
    omodel->add, self.oimage
    oview->add, omodel
    self.oviewgroup->add, oview
end


pro im_engine::realize
    compile_opt idl2

    widget_control, self.top, /realize
    widget_control, self.draw, get_value=window
    self.owindow = window
end


pro im_engine::create_widgets
    compile_opt idl2

    self.top = widget_base(title='IMaging Engine', uname='top', $
                           mbar=menubar, uvalue=self, /column, $
                           tlb_frame_attr=1)

    ;; File menu
    file_menu = widget_button(menubar, value='File', /menu, $
                              uname='file')
    exit_button = widget_button(file_menu, value='Exit', $
                                 uname='exit', /separator)

    ;; Display menu
    display_menu = widget_button(menubar, value='Display', /menu)
    hist_button = widget_button(display_menu, value='Histogram...', $
                                uname='histogram', /separator)

    ;; Macro menu
    macro_menu = widget_button(menubar, value='Macro', /menu)

    ;; Operations menu
    op_menu = widget_button(menubar, value='Operations', /menu, $
                            uname='image_op_menu')

    self.oimage->getproperty, dimensions=dims
    self.draw = widget_draw(self.top, $
                            /scroll, $
                            xsize=dims[0], ysize=dims[1], $
                            graphics_level=2, $
                            renderer=1, $ ; software rendering!!!
                            /expose_events, $
                            /motion_events, $
                            uname='draw')
    self->set, scr_xsize=dims[0]
    self->set, scr_ysize=dims[1]

    status_row = widget_base(self.top, /row, uname='row')
    self.status = widget_label(status_row, $
                               value='IMaging Engine', $
                               /sunken, xsize=150)
end


pro im_engine::cleanup
    compile_opt idl2

    if widget_info(self.top, /valid_id) then $
        widget_control, self.top, /destroy
    obj_destroy, self.oviewgroup
    obj_destroy, self.histogram
end


function im_engine::init, image
    compile_opt idl2

    self.oimage = obj_new('idlgrimage', image, name='image')
    self->create_widgets
    self->realize
    self->build_object_tree
    self->display
    self->start_xmanager

    self.histogram = obj_new('im_histogram')
    
    return, 1
end


;==============================================================================
;+
; @requires IDL 6.0
; @author Mike Galloy, 2002
; @history mutated almost beyond recognition 2003, Mark Piper
; @copyright RSI
;-
pro im_engine__define
    compile_opt idl2

    define = { im_engine, $
               top              : 0, $
               draw             : 0, $
               scr_xsize        : 0, $
               scr_ysize        : 0, $
               status           : 0, $
               histogram        : obj_new(), $
               owindow          : obj_new(), $
               oviewgroup       : obj_new(), $
               oimage           : obj_new(), $
               kill_object      : 0 $
             }
end
