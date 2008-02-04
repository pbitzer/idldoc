; docformat = 'rst'

;+
; Build all the files necessary for the updates.idldev.com site to give 
; updates for IDLdoc through the IDL Workbench.
;-
pro build_updates_site
  compile_opt strictarr
  
  root = mg_src_root()
  vars = { version: idldoc_version() }
    
  siteTemplateFile = filepath('site.xml.tt', subdir='updates-resources', root=root)
  siteFile = filepath('site.xml', subdir='updates.idldev.com', root=root)
  
  siteTemplate = obj_new('MGffTemplate', siteTemplateFile)
  siteTemplate->process, vars, siteFile
  obj_destroy, siteTemplate
  
  featureResources = filepath('', $
                              subdir=['updates-resources', 'features'], $
                              root=root)
  featureRoot = filepath('', $
                         subdir=['updates.idldev.com', 'features', 'com.idldev.idl.idldoc.feature_' + idldoc_version()], $
                         root=root)
  file_mkdir, featureRoot
  
  featureTemplate = obj_new('MGffTemplate', featureResources + 'feature.properties.tt')
  featureTemplate->process, vars, featureRoot + 'feature.properties'
  obj_destroy, featureTemplate
end