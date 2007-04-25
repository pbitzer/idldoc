function make_cube, pos = pos, radius = rad, _extra = e

; POS - three element vector of the center of the cube (default = 0,0,0)
; RADIUS - radius of the cube (default = .1)
; returns a polygon object - accepts all the keywords that
; the polygon object does
; common keywords:
;  SHADING, COLOR, STYLE, etc

;	Original: Beau Legeer
;	Modified: Mark Piper, 07/30/01


if (n_elements(pos) ne 3) then pos = [0.0,0.0,0.0]
if (n_elements(rad) ne 1) then rad = 0.1

; make a list of verts
xp = pos[0]+rad
xn = pos[0]-rad
yp = pos[1]+rad
yn = pos[1]-rad
zp = pos[2]+rad
zn = pos[2]-rad

verts = [ $
	[xn,yn,zn], $
	[xp,yn,zn], $
	[xp,yp,zn], $
	[xn,yp,zn], $
	[xn,yn,zp], $
	[xp,yn,zp], $
	[xp,yp,zp], $
	[xn,yp,zp] ]

; create a connectivity list
conn = [ $
	[4,3,2,1,0], $
	[4,4,5,6,7], $
	[4,0,1,5,4], $
	[4,1,2,6,5], $
	[4,2,3,7,6], $
	[4,3,0,4,7] ]

return, obj_new('idlgrpolygon',verts, $
	polygon=conn, _extra = e)

end