;	CREATE_VOLUME: Builds an object graphics hierarchy based
;	on a volume object.  Optionally return this hierarchy to
;	the calling level.

pro create_volume, voxel, volume=oVolume, model=oModel, $
	view=oView, lightmodel=oLightModel
compile_opt idl2
@catch_procedure

;	Create default data.
if n_params() eq 0 then begin
	n = 20
	plate = dist(n)
	voxel = fltarr(n,n,n)
	for i = 0, n-1 do voxel[*,*,i] = plate*abs(n/2-i)
endif

;	Create view, model and volume objects.
oVolume = obj_new('IDLgrVolume', voxel)
oModel = obj_new('IDLgrModel')
oView = obj_new('IDLgrView', color=[200,200,200])

;	Build the object graphics hierarchy.
oView -> Add, oModel
oModel -> Add, oVolume

;	Get x, y and z data ranges from the surface object.
oVolume -> GetProperty, xrange=xr, yrange=yr, zrange=zr

;	Use NORM_COORD to find scaling factors to shrink the surface
;	data down to the unit cube.
xs = norm_coord(xr)
ys = norm_coord(yr)
zs = norm_coord(zr)

;	Shift the offsets by 0.5.
xs[0] = xs[0] - 0.5
ys[0] = ys[0] - 0.5
zs[0] = zs[0] - 0.5

;	Apply the scaling factors to the volume object.
oVolume -> SetProperty, xcoord_conv=xs, ycoord_conv=ys, $
	zcoord_conv=zs

;	Set the default orientation of the volume object within
;	the view.
oModel -> Rotate, [1,0,0], -90
oModel -> Rotate, [0,1,0], 30
oModel -> Rotate, [1,0,0], 30

;	Create a light object & a model object for it.
oLight = obj_new('IDLgrLight', type=1, location=[1,1,1])
oLightModel = obj_new('IDLgrModel')

;	Add the light object and its model to the object graphics
;	hierarchy.
oLightModel -> Add, oLight
oView -> Add, oLightModel

end