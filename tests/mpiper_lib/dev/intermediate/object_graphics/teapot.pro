;===========================================================================
;+
; Event handler for the top-level base widget, called by XMANAGER when
; the user resizes the top-level base.
;
; @param event {in}{type=structure} The event structure.
;-
pro teapot_resize_event, event
    compile_opt idl2, logical_predicate

    widget_control, event.top, get_uvalue=pstate

    ;; Add padding while setting the new draw widget size.
    newx = (event.x - 2 * (*pstate).pad) > 100
    newy = (event.y - 2 * (*pstate).pad) > 100
    widget_control, (*pstate).draw, xsize=newx, ysize=newy

    ;; Use GET_BOUNDS and SET_VIEW to compute a new view volume that
    ;; retains the aspect ratio of the data regardless of the window
    ;; dimensions.
    get_bounds, (*pstate).om, xr, yr, zr
    set_view, (*pstate).ov, (*pstate).ow, $
        xrange=xr, $
        yrange=yr, $
        zrange=zr, $
        /do_aspect, $
        /isotropic

    ;; Reset the center and radius of the trackball.
    center = [newx,newy]/2
    radius = (newx < newy)/2
    (*pstate).ot->reset, center, radius

    ;; Repaint the window.
    (*pstate).ow->draw
end


;===========================================================================
;+
; Event handler for the draw widget, called by XMANAGER when the user
; interacts with the draw widget.
;
; @param event {in}{type=structure} The event structure.
;-
pro teapot_draw_event, event
    compile_opt idl2, logical_predicate

    widget_control, event.top, get_uvalue=pstate

    is_updated = (*pstate).ot->update(event, transform=updated)
    if is_updated then begin
        (*pstate).om->getproperty, transform=old
        (*pstate).om->setproperty, transform=old#updated
    endif

    ;; Repaint the window.
    (*pstate).ow->draw
end


;===========================================================================
;+
; Cleanup routine, called by XMANAGER when the TEAPOT UI is dismissed.
;
; @param tlb {in}{type=long} The top-level base widget identifier.
;-
pro teapot_cleanup, tlb
    compile_opt idl2, logical_predicate

    widget_control, tlb, get_uvalue=pstate
    ptr_free, pstate
end


;===========================================================================
;+
; A view of a teapot, with Object Graphics.
;
; @uses GET_BOUNDS, SET_VIEW
; @requires IDL 6.1
; @author Mark Piper, RSI, 2004
;-
pro teapot
    compile_opt idl2, logical_predicate

    ;; Restore the teapot data.
    file = filepath('teapot.dat', subdir=['examples','demo','demodata'])
    restore, file

    ;; Determine the user's screen resolution.
    ss = get_screen_size()
    xsize = ss[0]*0.3
    ysize = xsize

    ;; Make & realize the widget hierarchy.
    tlb = widget_base( $
                         title='The Long, Dark Teatime of the Soul', $
                         /tlb_size_events)
    draw = widget_draw(tlb, $
                       graphics_level=2, $
                       xsize=xsize, $
                       ysize=ysize, $
                       /button_events, $
                       /motion_events, $
                       /expose_events, $
                       event_pro='teapot_draw_event')
    widget_control, tlb, /realize

    ;; Get the window object from the draw widget.
    widget_control, draw, get_value=ow

    ;; Create the objects necessary to build a visualization based on
    ;; a polygon object.
    op = obj_new('idlgrpolygon', $
        data=transpose([[x],[y],[z]]), $
        polygons=mesh, $
        color=[0,0,200], $
        shading=1, $
        shininess=100.0, $
        specular=[0,0,100], $
        reject=0)
    om = obj_new('idlgrmodel')
    ol1 = obj_new('idlgrlight', $
        type=1)
    ol2 = obj_new('idlgrlight', $
        type=0, $
        intensity=0.4)
    olm = obj_new('idlgrmodel')
    ov = obj_new('idlgrview')
    ovg = obj_new('idlgrviewgroup')

    ;; Build the OGH.
    om->add, op
    olm->add, [ol1, ol2]
    ov->add, om
    ov->add, olm
    ovg->add, ov

    ;; Take 1: Determine the dimensions of the teapot. Translate the
    ;; teapot to the enter of the view volume. Use the largest
    ;; dimension of the teapot to create a new view volume. This is
    ;; not general in that every atom in the OGH needs to be
    ;; considered (to find the largest dimension) in determining the
    ;; size of the view volume.  Furthermore, the viewport will not
    ;; take into consideration the aspect ratio of the destination in
    ;; which the OGH is being rendered.
    op->getproperty, xrange=xr, yrange=yr, zrange=zr
    om->translate, -mean(xr), -mean(yr), -mean(zr)
    bound = max(abs([xr, yr, zr]))
    ov->setproperty, $
        viewplane_rect=[-bound, -bound, 2*bound, 2*bound], $
        zclip=[bound, -bound], $
        eye=sqrt(2)*bound

    ;; Take 2: Use GET_BOUNDS to determine the ranges of all the atoms
    ;; in the OGH. Use this information to translate the data to the
    ;; origin of the coordinate system. Use SET_VIEW to scale the
    ;; coordinate system to the largest dimension of the data, plus a
    ;; little padding. SET_VIEW considers the aspect ratio of the
    ;; destination.
    get_bounds, om, xr, yr, zr
    om->translate, -mean(xr), -mean(yr), -mean(zr)
    set_view, ov, ow, /isotropic

    ;; Position of the directional light source (ol1) to the near
    ;; upper right corner of the view volume.
    ov->getproperty, viewplane_rect=vr, zclip=zc
    ol1->setproperty, location=[vr[0]+vr[2],vr[1]+vr[3],zc[0]]

    ;; Set the GRAPHICS_TREE property of the window object & render
    ;; the OGH to the window.
    ow->setproperty, graphics_tree=ovg
    ow->draw

    ;; Make a trackball. Add it to the viewgroup.
    ot = obj_new('trackball', [xsize,ysize]/2, xsize/2)
    ovg->add, ot

    ;; Get geometry info for the top-level base.
    geom = widget_info(tlb, /geometry)

    ;; Make a state variable.
    state = { $
        ow   : ow, $
        ov   : ov, $
        om   : om, $
        ot   : ot, $
        draw : draw, $
        pad  : geom.xpad $
        }
    pstate = ptr_new(state, /no_copy)
    widget_control, tlb, set_uvalue=pstate

    ;; Call XMANAGER to register widget program & begin event handling.
    xmanager, 'teapot', tlb, $
        /no_block, $
        cleanup='teapot_cleanup', $
        event_handler='teapot_resize_event'
end
