; docformat = 'rst'


;+
; Print out debugging information about the system object.
;-
pro doc_system::debug
  compile_opt strictarr
  
  print, 'ROOT = ' + self.root
  print, 'OUTPUT = ' + self.output
end


;+
; Print error messages respecting /QUIET and /SILENT.
;
; :Params:
;    `msg` : in, required, type=string
;       error message to print 
;-
pro doc_system::error, msg
  compile_opt strictarr
  on_error, 2
  
  message, msg, /noname
end


;+
; Print warning messages respecting /QUIET and /SILENT.
;
; :Params:
;    `msg` : in, required, type=string
;       warning message to print 
;-
pro doc_system::warning, msg
  compile_opt strictarr
  
  if (~self.silent) then message, msg, /informational
  ++self.nWarnings
end


;+
; Print messages respecting /QUIET and /SILENT.
;
; :Params:
;    `msg` : in, required, type=string
;       message to print 
;-
pro doc_system::print, msg
  compile_opt strictarr
  
  if (~self.quiet || ~self.silent) then print, msg
end


;+
; Build the tree of directories, files, routines, and parameters.
;-
pro doc_system::parseTree
  compile_opt strictarr
  
  ; search for special files
  proFiles = file_search(self.root, '*.pro', /test_regular, count=nProFiles)
  savFiles = file_search(self.root, '*.sav', /test_regular, count=nSavFiles)
  idldocFiles = file_search(self.root, '*.idldoc', /test_regular, count=nIDLdocFiles)
  
  ; quit if no files found
  if (nProFiles + nSavFiles + nIDLdocFiles eq 0) then return
  
  ; add all the files together...
  dirs = ['']
  if (nProFiles gt 0) then dirs = [dirs, proFiles]
  if (nSavFiles gt 0) then dirs = [dirs, savFiles]
  if (nIDLdocFiles gt 0) then dirs = [dirs, idldocFiles]
  dirs = dirs[1:*]
  
  ; ...then find the unique directories
  dirs = file_dirname(strmid(dirs, strlen(self.root)), /mark_directory)
  dirs = dirs[uniq(dirs, sort(dirs))]
  
  for d = 0L, n_elements(dirs) - 1L do begin
     directory = obj_new('DOCtreeDirectory', location=dirs[d], system=self)
     self.directories->add, directory
  endfor
end


;+
; Generate all output for the run.
;-
pro doc_system::generateOutput
  compile_opt strictarr
  
  ; TODO: finish this
  
  ; generate files per directory
  for d = 0L, self.directories->count() - 1L do begin
    directory = self.directories->get(position=d)
    directory->generateOutput, self.output
  endfor
  
  ; generate index
  
  ; generate warnings page
  
  ; generate help
  
  ; generate index.html
end


;+
; Determine if the output directory can be written to.
;
; :Returns: error code (0 indicates no error)
;-
function doc_system::testOutput
  compile_opt strictarr
  
  testfile = self.output + 'idldoc.test'
  openw, lun, testfile, error=error, /get_lun
  if (error eq 0L) then free_lun, lun
  file_delete, testfile, /allow_nonexistent
  
  return, error
end


;+
; Free resources.
;-
pro doc_system::cleanup
  compile_opt strictarr
  
  obj_destroy, self.directories
end


;+
; Create system object.
; 
; :Returns: 1 for success, 0 for failure
; :Keywords:
;    `root` : in, required, type=string
;       root of directory hierarchy to document
;    `output` : in, optional, type=string
;       directory to place output
;    `quiet` : in, optional, type=boolean
;       if set, don't print info or warning messages, only print errors
;    `silent` : in, optional, type=boolean
;       if set, don't print anything
;-
function doc_system::init, root=root, output=output, $
                           quiet=quiet, silent=silent
  compile_opt strictarr
  on_error, 2
  
  if (n_elements(root) gt 0) then begin
    self.root = file_search(root, /mark_directory, /test_directory)
    if (self.root eq '') then self->error, 'ROOT directory does not exist'
  endif else begin
    self->error, 'ROOT keyword must be defined'
  endelse
  
  if (n_elements(output) gt 0) then begin
    self.output = file_search(output, /mark_directory, /test_directory)
  endif else begin
    self.output = self.root
  endelse
  
  ; get location of IDLdoc in order to find locations of data files like
  ; images, templates, etc.
  self.sourceLocation = mg_src_root()
  
  self.quiet = keyword_set(quiet)
  self.silent = keyword_set(silent)
  
  ; test output directory for write permission
  outputError = self->testOutput()
  if (outputError ne 0L) then self->error, 'unable to write to ' + self.output
  
  self.directories = obj_new('MGcoArrayList', type=11)
  
  ; parse tree of directories, files, routines, parameters 
  self->parseTree
    
  ; generate output for directories, files (of various kinds), index, etc.
  self->generateOutput
  
  return, 1
end


;+
; Define instance variables.
;
; :Fields:
;    `root` 
;       root directory of hierarchy to document; full path ending with slash
;    `output`
;       directory to place output
;    `nWarnings` 
;       number of warning messages printed
;    `quiet`
;       set to only print errors and warnings
;    `silent`
;       don't print anything
;-
pro doc_system__define
  compile_opt strictarr
  
  define = { DOC_System, $
             root: '', $
             output: '', $
             nWarnings: 0L, $
             quiet: 0B, $
             silent: 0B, $
             sourceLocation: '', $
             directories: obj_new() $             
           }
end