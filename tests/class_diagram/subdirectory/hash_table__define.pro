;2345678901234567890123456789012345678901234567890123456789012345678901234567890


;+
; Used to iterator over the items in a HASH_TABLE
;
; @bugs not implemented yet
; @returns HASH_TABLE_ITERATOR object reference
;-
function hash_table::iterator
    compile_opt idl2
    on_error, 2

end


;+
; Returns an array with the same number of elements as the hash array.  The
; value each element of the array is the number of elements in that "bin" of
; the hash_table.  This could be useful in determining the effectiveness of the
; hash code calculations.
;
; @private
; @returns long array
;-
function hash_table::get_histogram
    compile_opt idl2
    on_error, 2

    hist = lonarr(self.array_size)
    for i = 0, self.array_size - 1 do begin
        hist[i] = obj_valid((*self.key_array)[i]) $
            ? (*self.key_array)[i]->size() $
            : 0
    endfor

    return, hist
end


;+
; Prints keys and values to a given LUN.  Prints to STDOUT if LUN not given.
;
; @param lun {in}{optional}{type=LUN}{default=-1} logical unit number for output
;-
pro hash_table::print, lun, key_format=key_format, value_format=value_format
    compile_opt idl2

    i_lun = n_elements(lun) eq 0 ? -1 : lun

    keys = self->keys(count)
    values = self->values()

    if (count gt 0) then begin
        for i = 0, count - 1 do begin
            printf, i_lun, $
                string(keys[i], format=key_format) $
                + ' -> ' $
                + string(values[i], format=value_format)
        endfor
    endif
end


;+
; Returns an array of the keys of the hash table.
;
; @returns an array of the keys of the hash table or -1 if no keys
; @param count {out}{optional}{type=integral} number of keys in the hash table
;-
function hash_table::keys, count
    compile_opt idl2
    on_error, 2

    count = self->size()
    if (count le 0) then return, -1
    key_array = make_array(type=self.key_type, count, /nozero)
    idx = 0

    for i = 0, self.array_size - 1 do begin
        vector = (*self.key_array)[i]
        if (obj_valid(vector)) then begin
            key_array[idx] = vector->to_array()
            idx = idx + vector->size()
        endif
    endfor

    return, key_array
end


;+
; Returns an array of the values of the hash table.
;
; @returns an array of the values of the hash table or -1 if no values
; @param count {out}{optional}{type=integral} number of values in the hash table
;-
function hash_table::values, count
    compile_opt idl2
    on_error, 2

    count = self->size()
    if (count le 0) then return, -1
    value_array = make_array(type=self.value_type, count, /nozero)
    idx = 0

    for i = 0, self.array_size - 1 do begin
        vector = (*self.value_array)[i]
        if (obj_valid(vector)) then begin
            value_array[idx] = vector->to_array()
            idx = idx + vector->size()
        endif
    endfor

    return, value_array
end


;+
; Calculates the hash code of the given key.  The index of the array element
; the key's value will be stored in will be the hash code value MOD the array
; size.
;
; <p> If a HASH_TABLE of object references is desired, then the objects should
; implement the HASH_CODE method.  This function should accept no parameters and
; return an unsigned long.
;
; <p> This method should not normally be called directly.
;
; <p> If the given default hash function is not doing well (use the
; get_histogram method to find out how well it's spreading out the keys),
; subclass this class and implement a more appropriate hash function.
;
; @returns hash code (unsigned long integer); 0 if null pointer or object,
;          undefined variable; or an object that does not implement HASH_CODE
; @param key {in}{type=key type} key to find hash code of
;-
function hash_table::calc_hash_code, key
    compile_opt idl2
    on_error, 2

    ; handles the case if key is an object, but without the hash_code method
    error_number = 0
    catch, error_number
    if (error_number) then begin
        catch, /cancel
        return, 0UL
    endif

    type = size(key, /type)
    case type of
     0 : return, 0UL
     1 : return, ulong(key)
     2 : return, ulong(key)
     3 : return, ulong(key)
     4 : return, ulong(key)
     5 : return, ulong(key)
     6 : return, ulong(abs(key))
     7 : begin ; Strings
            ascii = ulong(byte(key))
            total = 0UL
            for i = 0, n_elements(ascii) - 1 do begin
                total = total * 37UL + ascii[i]
                    ; 37UL is a magic number suggested by the literature
            endfor
            return, total
        end
     8 : begin ; Structures
            hash_code = 0UL
            for tag_index = 0, n_tags(key) - 1 do begin
                hash_code = hash_code + self->calc_hash_code(key.(tag_index))
            endfor
            return, hash_code
        end
     9 : return, ulong(abs(key))
    10 : return, ptr_valid(key) ? self->calc_hash_code(*key) : 0UL
    11 : return, obj_valid(key) ? key->hash_code() : 0UL
    12 : return, ulong(key)
    13 : return, ulong(key)
    14 : return, ulong(key)
    15 : return, ulong(key)
    endcase
end


;+
; Finds the value associated with the given key.
;
; @returns the value of the associated key or -1L if not found
; @param key {in}{type=key type} key to look up
; @keyword found {out}{optional}{type=boolean} true if value found for given
;          key
;-
function hash_table::get, key, found=found
    compile_opt idl2
    on_error, 2

    hcode = self->calc_hash_code(key) mod self.array_size

    found = 0
    key_index = 0L
    if (not obj_valid((*self.key_array)[hcode])) then begin
        found = 0
        return, -1L
    endif
    iter = (*self.key_array)[hcode]->iterator()
    while (not iter->done()) do begin
        element = iter->next()
        if (element eq key) then begin
            found = 1
            break
        endif
        key_index = key_index + 1
    endwhile

    obj_destroy, iter
    return, found ? (*self.value_array)[hcode]->get(key_index) : -1L
end


;+
; Puts the key-value pair into the hash table or updates the value for the key
; if it is already in the hash table.
;
; @param key {in}{required}{type=key type} key to place in the table
; @param value {in}{required}{type=value type} value to place in the table
; @keyword found {out}{optional}{type=boolean} pass a named variable that is
;          set to true if the key was already in the table and is updated
;-
pro hash_table::put, key, value, found=found
    compile_opt idl2
    on_error, 2

    if (n_elements(key) gt 1) then begin
        for i = 0, n_elements(key) - 1L do begin
            self->put, key[i], value[i]
        endfor
    endif

    hcode = self->calc_hash_code(key) mod self.array_size
    if (obj_valid((*self.key_array)[hcode])) then begin
        found = 0
        key_index = 0
        iter = (*self.key_array)[hcode]->iterator()
        while (not iter->done()) do begin
            el = iter->next()
            if (el eq key) then begin
                found = 1
                break
            endif
            key_index = key_index + 1
        endwhile
        obj_destroy, iter

        if (found) then begin
            (*self.value_array)[hcode]->change, key_index, value
        endif else begin
            (*self.key_array)[hcode]->add, key
            (*self.value_array)[hcode]->add, value
        endelse
    endif else begin
        found = 0

        if (self.key_type eq 8) then begin ; type 8 = structure
            if (not ptr_valid(self.key_example)) then $
                self.key_example = ptr_new(key)
            (*self.key_array)[hcode] $
                = obj_new('vector', block_size=5, example=*self.key_example)
        endif else begin
            (*self.key_array)[hcode] $
                = obj_new('vector', block_size=5, type=self.key_type)
        endelse
        (*self.key_array)[hcode]->add, key

        if (self.value_type eq 8) then begin ; type 8 = structure
            if (not ptr_valid(self.value_example)) then $
                self.value_example = ptr_new(value)
            (*self.value_array)[hcode] $
                = obj_new('vector', block_size=5, example=*self.value_example)
         endif else begin
            (*self.value_array)[hcode] $
                = obj_new('vector', block_size=5, type=self.value_type)
         endelse
        (*self.value_array)[hcode]->add, value
    endelse
end


;+
; Find the number of key-value pairs in the hash table
;
; @returns the number of key-value pairs in the hash table
;-
function hash_table::size
    compile_opt idl2
    on_error, 2

    size = 0L
    ; Check size of key array only
    for key_index = 0, n_elements(*self.key_array) - 1 do begin
        size = size $
            + (obj_valid((*self.key_array)[key_index]) $
                ? (*self.key_array)[key_index]->size() : 0)
    endfor

    return, size
end


;+
; Determines if the hash table is empty.
;
; @returns 0 if the table is empty, 1 if it contains any key-value pairs
;-
function hash_table::is_empty
    compile_opt idl2
    on_error, 2

    ; Search key array only
    for key_index = 0, n_elements(*self.key_array) - 1 do begin
        test_vector = (*self.key_array)[key_index]
        if (obj_valid(test_vector)) then $
            if (not test_vector->is_empty()) then $
                return, 0
    endfor

    return, 1
end


;+
; Frees HASH_TABLE resources, but not elements in the HASH_TABLE (by default).
;
; @keyword clean {in}{optional}{type=boolean} set to OBJ_DESTROY the elements
;          in the HASH_TABLE
;-
pro hash_table::cleanup, clean=clean
    compile_opt idl2
    on_error, 2

    for i = 0, n_elements(*self.key_array) - 1 do begin
        if (obj_valid((*self.key_array)[i])) then $
            obj_destroy, (*self.key_array)[i], clean=keyword_set(clean)
        if (obj_valid((*self.value_array)[i])) then $
            obj_destroy, (*self.value_array)[i], clean=keyword_set(clean)
    endfor

    ptr_free, self.key_example, self.value_example
    ptr_free, self.key_array, self.value_array
end


;+
; Create a hash table.
;
; @returns 1 if successful; 0 otherwise
; @keyword array_size {in}{optional}{type=integral}{default=101} the size of
;          the hash table; generally a prime is a good choice
; @keyword key_type {in}{type=integral 0-15} type code for keys; key_type or
;          key_example must be present
; @keyword value_type {in}{type=integral 0-15} type code for values;
;          value_type or key_example must be present
; @keyword key_example {in}{type=key type} example of key type; key_type or
;          key_example must be present
; @keyword value_example {in}{type=value type} example of value type;
;          value_type or value_example must be present
;-
function hash_table::init, array_size=array_size, $
    key_type=key_type, value_type=value_type, $
    key_example=key_example, value_example=value_example

    compile_opt idl2
    on_error, 2

    self.array_size = n_elements(array_size) eq 0 ? 101 : array_size

    if (n_elements(key_type) eq 0) then begin
        if (n_elements(key_example) eq 0) then begin
            message, 'type of key must be defined with KEY_TYPE or KEY_EXAMPLE'
        endif else begin
            self.key_type = size(key_example, /type)
        endelse
    endif else begin
        self.key_type = key_type
    endelse

    if (n_elements(value_type) eq 0) then begin
        if (n_elements(value_example) eq 0) then begin
            message, $
                'type of value must be defined with VALUE_TYPE or VALUE_EXAMPLE'
        endif else begin
            self.value_type = size(value_example, /type)
        endelse
    endif else begin
        self.value_type = value_type
    endelse

    self.key_array = ptr_new(objarr(self.array_size))
    self.value_array = ptr_new(objarr(self.array_size))

    return, 1
end


;+
; Define hash table instance variables.
;
; @file_comments A hash table which can hash any kind of IDL variables.  To hash
;                objects, simply make sure each object implements the hash_code
;                method.  See the help for the calc_hash_code method for
;                details.
; @field key_array pointer to array of keys; type of array is specified by
;        KEY_TYPE field for non-structures and by KEY_EXAMPLE field for
;        structures
; @field value_array pointer to array of values; type of array is specified by
;        VALUE_TYPE field for non-structures and by VALUE_EXAMPLE field for
;        structures
; @field array_size size of the key and value arrays
; @field key_type SIZE type of keys; if 8 (structures), examine KEY_EXAMPLE to
;        find type of structure
; @field value_type SIZE type of keys; if 8 (structures), examine VALUE_EXAMPLE
;        to find type of structure
; @field key_example pointer to example structure defining the key type
; @field value_example pointer to example structure defining the value type
;
; @uses vector class
;
; @author Michael D. Galloy
; @copyright Research Systems, Inc 2002
;-
pro hash_table__define
    compile_opt idl2

    define = { hash_table, $
        key_array:ptr_new(), $
        value_array:ptr_new(), $
        array_size:0L, $
        key_type:0L, $
        value_type:0L, $
        key_example:ptr_new(), $ ; used for structures
        value_example:ptr_new() $ ; used for structures
        }
end