; >>>> begin comments
;==========================================================================================
;
; >>>> McObject Class: sdi2k_math_windfitz
;
; This file contains the McObject method code for sdi2k_math_windfitz objects:
;
; Mark Conde Fairbanks, October 2000.
;
; >>>> end comments
; >>>> begin declarations
;         menu_name = Wind Vector Fitter
;        class_name = sdi2k_math_windfitz
;       description = SDI Analysis - Fit Winds
;           purpose = SDI analysis
;       idl_version = 5.2
;  operating_system = Windows NT4.0 terminal server
;            author = Mark Conde
; >>>> end declarations

@sdi2k_ncdf.pro

;==========================================================================================
; This is the (required) "new" method for this McObject:

pro sdi2k_math_windfitz_new, instance, dynamic=dyn, creator=cmd
;---First, properties specific to this object:
    cmd = 'instance = {sdi2k_math_windfitz, '
    cmd = cmd + 'specific_cleanup: ''sdi2k_math_windfitz_specific_cleanup'', '
    fitting = {fitting, prompt_for_filename: 1, $
                              skip_old_fits: 0, $
                         exit_on_completion: 0, $
                          menu_configurable: 1, $
                              user_editable: [0,1,2]}
    wind_settings = {ww_st, time_smoothing: 0.9, $
                    space_smoothing: 0.05, $
                    dvdx_assumption: 'dv/dx = 0', $
                          algorithm: 'Fourier Fit', $
                     assumed_height: 120., $
                  menu_configurable: 1, $
                      user_editable: [0,1,2, 3, 4]}

    cmd = cmd + 'fitting: fitting, '
    cmd = cmd + 'Settings: wind_settings, '
;---Now add fields common to all SDI objects. These will be grouped as sub-structures:
    sdi2k_common_fields, cmd, automation=automation, geometry=geometry
;---Next, add the required fields, whose specifications are read from the 'declarations'
;   section of the comments at the top of this file:
    whoami, dir, file
    obj_reqfields, dir+file, cmd, dynamic=dyn
;---Now, create the instance:
    status = execute(cmd)
end

;==========================================================================================
; This is the event handler for events generated by the sdi2k_math_windfitz object:
pro sdi2k_math_windfitz_event, event
    common windfitz_resarr, resarr, smootharr, skyfile
    widget_control, event.top, get_uvalue=info
    wid_pool, 'Settings: ' + info.wtitle, widx, /get
    if not(widget_info(widx, /valid_id)) then return
    widget_control, widx, get_uvalue=windfitz_settings
    if widget_info(event.id, /valid_id) and windfitz_settings.automation.show_on_refresh then widget_control, event.id, /show

;---Check for a timer tick:
    if tag_names(event, /structure_name) eq 'WIDGET_TIMER' then begin
       sdi2k_math_windfitz_tik, info.wtitle
       if windfitz_settings.automation.timer_ticking then widget_control, widx, timer=windfitz_settings.automation.timer_interval
       return
    endif

;---Get the menu name for this event:
    widget_control, event.id, get_uvalue=menu_item
    if n_elements(menu_item) eq 0 then menu_item = 'Nothing valid was selected'
    
    if menu_item eq 'Fit|Smooth Winds' then begin
       wot = resarr.velocity
       print, 'Smoothing Winds in Time...'
       sdi2k_timesmooth_fits, wot, windfitz_settings.settings.time_smoothing, /progress
       print, 'Smoothing Winds in Space...'
       sdi2k_spacesmooth_fits, wot, windfitz_settings.settings.space_smoothing, /progress
       smootharr.velocity(1:*) = wot(1:*,*)
    endif
    sdi2k_wfitter, info.wtitle
    
    if n_elements(menu_item) eq 0 then menu_item = 'Nothing valid was selected'
end

pro sdi2k_batch_windplot, resarr, zz, mm, xx, yy, scale, geo
  geos = size(geo)
  if geos(n_elements(geos)-2) ne 8 then return

  load_pal, culz
  zhi = scale
  timarr   = (resarr.start_time + resarr.end_time)/2.
  ncnzones = n_elements(resarr(0).velocity)
  mapix = min([geo.xsize, geo.ysize])
  mpx = 0.8*mapix
  xcen = geo.xsize/2
  ycen = geo.ysize/2
  maxd = max([xx,yy])

  erase, culz.white
  tvcircle, mpx/2, xcen, ycen, culz.blue, thick=1
  hourangle = 22*!pi/180.
  for zidx=0,ncnzones-1 do begin
      zon = zz(zidx)*cos(hourangle) - $
            mm(zidx)*sin(hourangle)
      mer =-zz(zidx)*sin(hourangle) - $
            mm(zidx)*cos(hourangle)
      cx = 0.5*mpx*xx(zidx)/maxd
      cy = 0.5*mpx*yy(zidx)/maxd
      xb = cx*cos(hourangle) - cy*sin(hourangle) + xcen
      yb =-cx*sin(hourangle) - cy*cos(hourangle) + ycen

;-----Displace beginning positions so that the center of the vector will lie at the observing location:
      xb = xb - mpx*zon/(4*zhi)
      yb = yb - mpx*mer/(4*zhi)
;-----Now add the vector displacement to the vector base, to get the endpoints:
      xe = xb + mpx*zon/(2*zhi)
      ye = yb + mpx*mer/(2*zhi)

;-----Draw the arrow:
      aco = culz.green
      arrow, xb, yb, xe, ye, color=aco, hsize=mpx/25, thick=5
  endfor
end



;==========================================================================================
; This is the routine that handles timer ticks:
pro sdi2k_math_windfitz_tik, wtitle, redraw=redraw, _extra=_extra
@sdi2kinc.pro
end

pro sdi2k_wfitter, wtitle
@sdi2kinc.pro
    common windfitz_resarr, resarr, smootharr, skyfile
    
    wid_pool, wtitle, widx, /get
    if not(widget_info(widx, /valid_id)) then return
    widget_control, widx, get_uvalue=info
    wid_pool, 'Settings: ' + wtitle, sidx, /get
    if not(widget_info(sidx, /valid_id)) then return
    widget_control, sidx, get_uvalue=windfitz_settings

    dvdx_zero = windfitz_settings.settings.dvdx_assumption ne 'dv/dx = 1/epsilon x dv/dt'
    nobs = n_elements(smootharr)
    smootharr.velocity = smootharr.velocity - total(smootharr(1:nobs-2).velocity(0))/n_elements(smootharr(1:nobs-2).velocity(0))
    sdi2k_fit_wind, smootharr, dvdx_zero=dvdx_zero, windfit, windfitz_settings.settings.assumed_height
    sdi2k_ncopen, skyfile, ncid, 0
    sdi2k_add_windvars, ncid, windfit, windfitz_settings.settings
    ncdf_close, host.netcdf(0).ncid
    host.netcdf(0).ncid = -1
    for rcd = 0,nobs-1 do begin
        sdi2k_batch_windplot, smootharr, windfit.zonal_wind(*,rcd), windfit.meridional_wind(*,rcd), $
        windfit.zonal_distances, windfit.meridional_distances, 600., windfitz_settings.geometry
        wait, 0.1
    endfor

end

;==========================================================================================
;   Cleanup jobs:
pro sdi2k_math_windfitz_specific_cleanup, widid
@sdi2kinc.pro
end

;==========================================================================================
; This is the (required) "autorun" method for this McObject. If no autorun action is
; needed, then this routine should simply exit with no action:

pro sdi2k_math_windfitz_autorun, instance
@sdi2kinc.pro
    common windfitz_resarr, resarr, smootharr, skyfile
    instance.geometry.xsize = 950
    instance.geometry.ysize = 950
    instance.automation.timer_interval = 1.
    instance.automation.timer_ticking = 0
    sdi2k_reset_spectra
;    mnu_xwindow_autorun, instance, topname='sdi2ka_top'

    skyfile = sdi2k_filename('sky')
    if instance.fitting.prompt_for_filename then begin
       skyfile = dialog_pickfile(file=skyfile, $
                                 filter='sky' + '*.' + host.operation.header.site_code, $
                                 group=widx, title='Select a file of sky spectra: ', $
                                 path=host.operation.logging.log_directory)
    endif

    sdi2k_ncopen, skyfile, ncid, 0
    sdi2k_build_zone_map
    if n_elements(resarr) gt 0 then undefine, resarr
    sdi2k_build_fitres, ncid, resarr
    smootharr = resarr
    ncdf_close, host.netcdf(0).ncid
    host.netcdf(0).ncid = -1
    sdi2k_drift_correct, resarr, source_file=skyfile
    
    if getenv('SDI_ZERO_VELOCITY_FILE') ne '' then begin
       restore, getenv('SDI_ZERO_VELOCITY_FILE') 
       print, 'Using vzero map: ', getenv('SDI_ZERO_VELOCITY_FILE')
       for j=0,n_elements(resarr) - 1 do begin
           resarr(j).velocity = resarr(j).velocity - vzero
       endfor
    endif

    sdi2k_remove_radial_residual, resarr, parname='VELOCITY'
    sdi2k_physical_units, resarr

    mc_menu, extra_menu, 'Fit',                    1, event_handler='sdi2k_math_windfitz_event', /new
    mc_menu, extra_menu, 'Smooth Winds',           0, event_handler='sdi2k_math_windfitz_event'
    mc_menu, extra_menu, 'Re-Fit',                 2, event_handler='sdi2k_math_windfitz_event'
    mnu_xwindow_autorun, instance, topname='sdi2ka_top', extra_menu=extra_menu
end

;==========================================================================================
; This is the (required) class method for creating a new instance of the sdi2k_math_windfitz object. It
; would normally be an empty procedure.  Nevertheless, it MUST be present, as the last procedure in
; the methods file, and it MUST have the same name as the methods file.  By calling this
; procedure, the caller forces all preceeding routines in the methods file to be compiled,
; and so become available for subsequent use:

pro sdi2k_math_windfitz
end

