; Copyright (c) 1999-2000, Research Systems, Inc.  All rights reserved.
;       Unauthorized reproduction prohibited.
;+
; NAME:
;	CREATE_SURFACE
;
; PURPOSE:
;	This procedure creates an object graphics hierarchy based on a
;	surface graphics atom and optionally returns it to the calling
;	program level.
;
; CATEGORY:
;	Object Graphics.
;
; CALLING SEQUENCE:
;	CREATE_SURFACE[, Data]
;
; OPTIONAL INPUTS:
;	Data: A two-dimensional data array to be displayed as a surface.
;
; KEYWORD PARAMETERS:
;	SURFACE: Set this keyword to a named variable to accept the
;		surface object reference created in CREATE_SURFACE.
;	MODEL: Accepts model object.
;	VIEW: Accepts view object.
;
; EXAMPLE:
;	IDL> data = SHIFT(DIST(40),20,20)
;	IDL> CREATE_SURFACE, data, MODEL=oModel, VIEW=oView, $
;	IDL> 	SURFACE=oSurface
;
; MODIFICATION HISTORY:
;	Written by:     Mark Piper, 5-7-99
;-

pro create_surface, zdata, SURFACE=oS, MODEL=oM, VIEW=oV
compile_opt idl2
on_error, 2

;  Create default data.
if n_params() eq 0 then zdata = dist(30)

;  Create view, model & surface objects.
oV = obj_new('IDLgrView', COLOR=[250,250,250])
oM = obj_new('IDLgrModel')
oS = obj_new('IDLgrSurface', zdata, COLOR=[255,0,0], STYLE=2)

;  Load object hierarchy.
oV -> Add, oM
oM -> Add, oS

;  Get the xyz data ranges, using the GetProperty method.
oS -> GetProperty, XRANGE=xrange, YRANGE=yrange, ZRANGE=zrange

;  Use NORM_COORD to return scaling factors [s0,s1], where s0 is
;  the offset and s1 is the scaling factor.
xs = norm_coord(xrange)
ys = norm_coord(yrange)
zs = norm_coord(zrange)

;  Adjust the offset (s0) to fit in the default viewplane_rect.
xs[0] = xs[0] - 0.5
ys[0] = ys[0] - 0.5
zs[0] = zs[0] - 0.5

;  Set the correct coords using the SetProperty method;
;  e.g., xcoord_conv=xs gives normalized_x = xs[0] + xs[1]*data_x
oS -> SetProperty, XCOORD_CONV=xs, YCOORD_CONV=ys, ZCOORD_CONV=zs

;  Set the default view, using the Rotate method of IDLgrModel.
oM -> Rotate, [1,0,0], -90
oM -> Rotate, [0,1,0], 30
oM -> Rotate, [1,0,0], 30

end