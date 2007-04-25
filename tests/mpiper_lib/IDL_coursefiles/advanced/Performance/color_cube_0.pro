function compute_xy, red, green, blue, xsize=xsize
    compile_opt idl2, hidden

    R = [0., 1.]
    G = [-sqrt(3) / 2., - 1. / 2.]
    B = [sqrt(3) / 2., - 1. / 2.]
    color = R * red + G * green + B * blue
    color = fix((color + 255) * (xsize - 1.) / 510.)

    return, color
end

pro color_cube_0
    compile_opt idl2

    start_t = manual_timer(1)

    xsize = 400
    ysize = 400
    cube = bytarr(3, xsize, ysize)

    for red = 0, 255 do begin
        for green = 0, 255 do begin
            for blue = 0, 255 do begin
                color = compute_xy(red, green, blue, xsize=xsize)
                cube[0, color[0], color[1]] = red
                cube[1, color[0], color[1]] = green
                cube[2, color[0], color[1]] = blue
            endfor
	 endfor
         ;window, /free, xsize=xsize, ysize=ysize
         ;tv, cube, true=1     
    endfor

    end_t = manual_timer(1)

    print, 'Color cube constructed in ' $
        + strtrim(end_t - start_t, 2) + ' seconds'

    window, /free, xsize=xsize, ysize=ysize, retain=2
    tv, cube, true=1
end
