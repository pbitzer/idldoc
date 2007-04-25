;2345678901234567890123456789012345678901234567890123456789012345678901234567890

;+
; Used internally to tell iterator that the underlying vector has been changed.
; Should only be called by methods of vector that change the vector.  This
; will cause the iterator to fail the next time the DONE or NEXT method
; is called (this iterator is "fail-fast").
;
; @private
;-
pro vector_iterator::notify_changed
    compile_opt idl2
    on_error, 2

    self.changed = 1
end


;+
; Determines if there are any more elements of the underlying vector to visit.
;
; @returns 1 if no more elements of the underlying vector, 0 otherwise
;-
function vector_iterator::done
    compile_opt idl2
    on_error, 2

    if (self.changed) then message, 'underlying vector has changed'

    return, self.current_length ge self.vector->size()
end


;+
; Returns the next elements and advances the iterator.  After an iterator is
; created, "next" will return the first element of the vector.
;
; @returns next element of the array
;-
function vector_iterator::next
    compile_opt idl2
    on_error, 2

    if (self.changed) then message, 'underlying vector has changed'

    found = self.current_vec->find_element(self.current_pos, $
        start_vec=self.current_vec, $
        vector=vector, subindex=subindex, element=element)
    self.current_vec = vector
    self.current_pos = subindex + 1
    self.current_length = self.current_length + 1

    return, element
end


;+
; Does not free the underlying VECTOR.  The iterators are freed when the
; underlying VECTOR is destroyed.
;-
pro vector_iterator::cleanup
    compile_opt idl2
    on_error, 2
end


;+
; Creates a vector_iterator allowing traversal of the list.  Any changes to
; the underlying vector will cause the iterator to produce errors if accessed
; (it is "fail-fast").
;
; @param vector {in}{required}{type=vector object} the underlying vector
; @returns success (1) or failure (0)
;-
function vector_iterator::init, vector
    compile_opt idl2
    on_error, 2

    self.vector = vector
    self.current_vec = vector
    self.current_pos = 0 ; haven't started yet
    self.current_length = 0L
    self.changed = 0

    return, 1
end


;+
; Vector_iterator definition.
;
; @examples A typical use of an iterator is:
; <pre>   iter = v->iterator()
;   while (not iter->done()) then begin
;       elem = iter->next()
;       process, elem
;   endwhile</pre>
;-
pro vector_iterator__define
    compile_opt idl2
    on_error, 2

    define = { vector_iterator, $
        vector:obj_new(), $
        current_vec:obj_new(), $
        current_pos:0L, $
        current_length:0L, $
        changed:0L $
        }
end


;+
; Iterators are simply objects used to loop through elements of a container.
; It is more efficient to use an iterator than to use the GET method if
; all the elements of the vector must be looped through.  If a vectorizable
; operation must be performed on all elements of the vector, consider using
; the TO_ARRAY method to obtain an array of the elements.
;
; <p> This iterator is "fail-fast", ie. it produces an error if the underlying
; vector is modified (using the ADD, REMOVE, RESET, or COMPACT methods) after
; the iterator was created, but only when the iterator is accessed.  In other
; words, it is safe to create an iterator, modify the vector, and then ignore
; or destroy the iterator.  But creating an iterator, modifying the vector, and
; then accessing the iterator through the NEXT or DONE methods is an error.
;
; @returns vector_iterator object reference
; @examples A typical use of an iterator is:
; <pre>   iter = v->iterator()
;   while (not iter->done()) then begin
;       elem = iter->next()
;       process, elem
;   endwhile</pre>
;-
function vector::iterator
    compile_opt idl2
    on_error, 2

    ; this vector node is not the first
    if (not obj_valid(self.iterators)) then $
        message, 'cannot create iterator for non visible vector'

    new = obj_new('vector_iterator', self)
    self.iterators->add, new
    return, new
end


;+
; Determines if there are elements in the vector.
;
; @returns 1 if vector is empty and 0 otherwise
;-
function vector::is_empty
    compile_opt idl2
    on_error, 2

    return, self->size() eq 0
end


;+
; Reset the vector to remove all elements.
;-
pro vector::reset
    compile_opt idl2
    on_error, 2

    ; notify iterators that vector has been modified
    iters = self.iterators->get(/all, count=count)
    for i = 0, count - 1 do $
        if (obj_valid(iters[i])) then $
            iters[i]->notify_changed

    current = self.next

    while (obj_valid(current)) do begin
        next = current.next
        obj_destroy, current, /single
        current = next
    endwhile

    self.used = 0
    self.size = 0
    self.last = obj_new()
end


;+
; Finds an element given an index starting from a given vector node.
;
; @private
; @returns 1 if found; 0 otherwise
; @param index {in}{required}{type=int} index of the element to find
; @keyword vector {out}{optional}{type=vector obj} vector node the element
;          is in
; @keyword subindex {out}{optional}{type=int} the index in the vector node of
;          the element
; @keyword start_vec {in}{optional}{type=vector obj}{default=first node}
;          vector node to start indexing from
; @keyword element {out}{optional}{type=int} element found
;-
function vector::find_element, index, vector=vector, subindex=subindex, $
    start_vec=start_vec, element=element
    compile_opt idl2
    on_error, 2

    if (n_elements(start_vec) eq 0) then start_vec = self.first

    found = 0
    elements = 0
    vector = start_vec
    while (elements le index) do begin
        if ((elements + vector.used - 1) ge index) then begin
            subindex = index - elements
            found = 1
            break
        endif
        elements = elements + vector.used
        vector = vector.next
    endwhile

    element = (*vector.ptr)[subindex]
    return, found
end


;+
; Swaps two values of the vector.
;
; @param index1 {in}{required}{type=integral} index of element to swap
; @param index2 {in}{required}{type=integral} index of element to swap
;-
pro vector::swap, index1, index2
    compile_opt idl2

    value1 = self->get(index1)
    value2 = self->get(index2)

    self->change, index1, value2
    self->change, index2, value1
end


;+
; Changes the given item of the vector to the given value
;
; @param index {in}{required}{type=int} the index of the element to change
; @param value {in}{required}{type=type of the vector} the value to change the
;        given item to
; @keyword original_index {in}{optional}{type=int}{private} used internally
;          for error messages
;-
pro vector::change, index, value, original_index=original_index
    compile_opt idl2
    on_error, 2

    if (n_elements(original_index) eq 0) then original_index = index
    err_msg = 'index ' + strtrim(original_index, 2) + ' out of bounds'

    if (index ge self.block_size) then $
        if (obj_valid(self.next)) then $
            self.next->change, index - self.block_size, value, $
                original_index=original_index $
        else message, err_msg $
    else begin
        if (index ge self.used) then message, err_msg
        if (self.example) then begin
            temp_value = (*self.ptr)[index]
            struct_assign, value, temp_value
            (*self.ptr)[index] = temp_value
        endif else (*self.ptr)[index] = value
    endelse
end


;+
; Compact the vector to use space the most efficiently.  This could be useful
; after many removes and additions have been done.
;
; @abstract
; @bugs not implemented yet
;-
pro vector::compact
    compile_opt idl2

    ; TODO: add implementation
end


;+
; Removes an element from the vector.
;
; @bugs element keyword does not work yet
; @param index {in}{required}{type=int} index of the element to remove
; @keyword element {out}{optional}{type=vector type} returns element removed;
;          this can be useful for checking or to free a dynamic resource if no
;          longer needed
;-
pro vector::remove, index, element=element
    compile_opt idl2
    on_error, 2

    if (index ge self.size) then $
        message, 'out of bounds'

    self.size = self.size - 1

    found = self->find_element(index, vector=vector, subindex=subindex)

    if (subindex ne (vector.used - 1)) then $
        (*vector.ptr)[subindex] = (*vector.ptr)[(subindex+1):(self.used-1)]

    vector.used = vector.used - 1
end


;+
; Retrieve elements of the vector by index (starting at 0).  Use the get method
; to get particular elements; use an iterator to examine each element in order.
; Use to_array to perform vectorizable operations to all elements.
;
; @returns the element at the given index
; @param index {in} {type=int} the index of the element to retrieve; indices
;        begin at 0 and end at the number of elements - 1
; @keyword original_index {in} {type=int} {private} used internally for error
;          messages
;-
function vector::get, index, original_index=original_index
    compile_opt idl2
    on_error, 2

    if (n_elements(original_index) eq 0) then original_index = index
    err_msg = 'index ' + strtrim(original_index, 2) + ' out of bounds'

    if (index ge self.used) then $
        if (obj_valid(self.next)) then $
            return, self.next->get(index - self.used, $
                original_index=original_index) $
        else message, err_msg $
    else begin
        if (index ge self.used) then message, err_msg
        return, (*self.ptr)[index]
    endelse
end


;+
; Add the given value to the end of the vector.
;
; @param value {in}{required}{type=type of vector} the value to be added; this
;        value may be a scalar or an array of elements to be added
;-
pro vector::add, value
    compile_opt idl2
    on_error, 2

    if (n_elements(value) gt 1) then begin
        for i = 0, n_elements(value) - 1 do begin
            self->add, value[i]
        endfor
        return
    endif

    ; notify iterators that vector has been modified
    iters = self.iterators->get(/all, count=count)
    for i = 0, count - 1 do $
        if (obj_valid(iters[i])) then $
            iters[i]->notify_changed

    self.size = self.size + 1

    current = self

    if (obj_valid(self.last)) then $
        current = self.last

    if (current.used ge current.block_size) then begin
        if (self.example) then $
            new = obj_new('vector', $
                block_size=self.block_size, $
                example=*self.example_ptr, $
                first=self) $
        else $
            new = obj_new('vector', $
                block_size=self.block_size, $
                type=self.type, $
                first=self)

        current.next = new
        self.last = new
        current = new
    endif

    if (self.example) then begin
        temp_val = (*current.ptr)[current.used]
        struct_assign, value, temp_val
    endif else temp_val = value

    (*current.ptr)[current.used] = temp_val
    current.used = current.used + 1
end


;+
; Creates a standard IDL array to contain all the elements of the vector.
;
; @returns an array of the type of vector or -1 if vector is empty
; @keyword empty {out}{optional}{type=boolean} returns 1 if vector is empty, 0
;          otherwise
;-
function vector::to_array, empty=empty
    compile_opt idl2
    on_error, 2

    empty = 0B
    if (self.size eq 0) then begin
        empty = 1B
        return, -1
    endif

    ret = self.example $
        ? make_array(self.size, value=*self.example_ptr, /nozero) $
        : make_array(self.size, type=self.type, /nozero)
    vec = self
    pos = 0

    while (obj_valid(vec)) do begin
        if (vec.used gt 0) then begin
            ret[pos] = (*vec.ptr)[0:(vec.used-1)]
            pos = pos + vec.used
        endif
        vec = vec.next
    endwhile

    return, ret
end


;+
; Returns the number of elements in the vector.
;
; @returns long
; @keyword type {out}{optional}{type=integeral} the type of the data stored in the vector
;-
function vector::size, type=type
    compile_opt idl2
    on_error, 2

    type = self.type
    return, self.size
end


;+
; Print the contents of the vector to an LUN.
;
; @keyword lun {in}{optional}{type=int}{default=-1} logical unit number of a
;          file to print the vector to; LUN=-1 is stdout
; @keyword _extra {in}{optional}{type=keywords} keywords to printf
;-
pro vector::print, lun=lun, _extra=e
    compile_opt idl2
    on_error, 2

    if (self.used eq 0) then return

    if (n_elements(lun) eq 0) then lun = -1

    printf, lun, (*self.ptr)[0:(self.used - 1)], _extra=e
    if (obj_valid(self.next)) then self.next->print, lun=lun, _extra=e
end



;+
; Called by OBJ_DESTROY to cleanup resources.  Keywords can be passed to
; OBJ_DESTROY and will be passed along to this routine.  Do not call
; CLEANUP directly except from a subclass of VECTOR.  Any iterators of the
; VECTOR are cleaned up automatically when the VECTOR is destroyed.
;
; @keyword single {in}{type=boolean}{private}{optional} set to cleanup
;          just this vector and not those pointed to by self.next; used
;          internally
; @keyword clean {in}{optional}{type=boolean} set to OBJ_DESTROY object
;          references (if that is the type of the VECTOR)
;-
pro vector::cleanup, single=single, clean=clean
    compile_opt idl2
    on_error, 2

    if (keyword_set(clean)) then $
        if (self.type eq 11) then $
            if (self.used gt 0) then $
                obj_destroy, (*self.ptr)[0:(self.used-1)]

    ptr_free, self.ptr, self.example_ptr
    obj_destroy, self.iterators

    if (keyword_set(single)) then return

    current = self.next

    while (obj_valid(current)) do begin
        next = current.next
        obj_destroy, current, /single, clean=clean
        current = next
    endwhile
end


;+
; Create the vector with a given block size and variable type.  Vectors of
; structures can be created only using the EXAMPLE keyword.
;
; @returns 1 for success; 0 for failure
; @keyword block_size {in}{type=int}{optional}{default=1000} elements in
;          a vector are allocated in BLOCK_SIZE blocks
; @keyword example {in}{type=any} example data of the same type that the
;          vector should be made; the actual data is not used or stored.
;          Either TYPE or EXAMPLE is required for initialization.
; @keyword first {in}{optional}{type=vector object}{private} a reference to
;          the first vector in the vector list; used internally
; @keyword type {in}{type=int} the type code returned from SIZE function of
;          the vector, may not be a structure; either TYPE or EXAMPLE is
;          required
;-
function vector::init, block_size=block_size, example=example, type=type, $
    first=first
    compile_opt idl2
    on_error, 2

    self.block_size = n_elements(block_size) eq 0 ? 1000 : block_size
    if (self.block_size le 0) then message, 'BLOCK_SIZE must be greater than zero'

    ex_pres = n_elements(example) ne 0
    type_pres = n_elements(type) ne 0

    if (type_pres) then $
        if (type eq 8) then message, 'structures must use EXAMPLE'

    if (ex_pres and type_pres) then $
        message, 'EXAMPLE and TYPE keywords are mutually exclusive'

    if ((not ex_pres) and (not type_pres)) then $
        message, 'one of EXAMPLE and TYPE keywords necessary'

    if (ex_pres) then begin
        self.type = size(example, /type)
        if (self.type eq 8) then begin ; type 8 = structure
            self.example_ptr = ptr_new(example)
            self.example = 1
        endif
    endif else begin
        self.type = type
    endelse

    arr = self.example $
        ? make_array(self.block_size, value=example, /nozero) $
        : make_array(self.block_size, type=self.type, /nozero)
    self.ptr = ptr_new(arr)
    self.used = 0
    self.size = 0
    self.next = obj_new()
    self.first = n_elements(first) eq 0 ? self : first
    self.last = obj_new()
    self.iterators = n_elements(first) eq 0 $
        ? obj_new('IDL_Container') $
        : obj_new()

    return, 1
end


;+
; Variable length list of elements of any type.  Use vectors for an ordered
; list of elements where additions to the list occur only at the end of the
; list.
;
; @file_comments A vector is an object representing a variable length list of
;                scalar elements of any single type.  Vectors support adding
;                elements at the end of the vector only, but any element may
;                be removed from the vector.  An iterator is provided for
;                efficient and easy looping through the elements of the vector.
; @field block_size size of each VECTOR node array
; @field used number of elements of the current node which are used; these
;        are always the first USED elements of the node
; @field size the current size of the VECTOR; though each node stores a SIZE
;        field, only the first VECTOR's is used
; @field type type code (as in SIZE(/TYPE)) of elements of the VECTOR; the VECTOR
;        must be of a single type and if that type is 8 (structure) then the
;        EXAMPLE and EXAMPLE_PTR fields must be used
; @field example 1 if EXAMPLE keyword is given to create the structure and the
;        example is a structure
; @field example_ptr if EXAMPLE field is set, then this holds a pointer to
;        copy of what was sent to the EXAMPLE keyword
; @field ptr pointer to current node's array of elements
; @field next next VECTOR node
; @field first later VECTOR nodes keep track of first VECTOR node
; @field last last VECTOR node; this is used to add another element at the end
;        of the VECTOR efficiently
; @field iterators an IDL_Container holding all current iterators for this vector
; @author Michael D. Galloy, mgalloy\@rsinc.com
; @copyright RSI, 2002
;-
pro vector__define
    compile_opt idl2
    on_error, 2

    define = { vector, $
        block_size:0L, $
        used:0L, $
        size:0L, $
        type:0L, $
        example:0, $
        example_ptr:ptr_new(), $
        ptr:ptr_new(), $
        next:obj_new(), $ ; vector
        first:obj_new(), $ ; vector
        last:obj_new(), $ ; vector
        iterators:obj_new() $ ; IDL_Container
        }
end
