( --- Collections. --- )

\ VECTORED COMMANDS:
\ []                 ( i collection -- adr )
\   Get the address at index i.  Address may be the address of a value, or in the case
\   of nodetrees, a node.
\ TRUNCATE           ( newlength collection -- )
\   Sets collection to a specific length and deletes the remainder.
\ PUSH               ( val collection -- )
\   Add val to end of collection.
\ POP                ( collection -- val )
\   Fetch vel from end of collection and remove it.
\ EACH               ( xt collection -- )  ( val -- )
\   Itterate over all the items in a collection.  Adr may be address of value or a node.
\ DELETES            ( index count collection -- )
\   Delete range from a collection.
\ .EACH              ( collection -- )
\   Print the contents of a collection.
\ REMOVE             ( val collection -- )  
\   Removes all the instances of val from a collection.
\ ?@                 ( adr collection -- val )  
\   Fetches val from item adr in a collection.  (No-op on nodes.)
\ REMOVEAT            ( i collection -- )
\   Removes the value at index i.  (Does not delete in the case of nodes.)
\ INSERT             ( val i dest-collection -- )
\   Inserts a value at index i.
\   For example inserting at index 0 makes it the first item and shifts all other items up by 1 index.

\ GENERIC COMMANDS:
\ LENGTH             ( collection -- n )
\   Get the current length of a collection.
\ INBOUNDS?          ( n collection -- flag )
\   Check if an index is under the current length.
\ CAPACITY           ( collection -- n )
\   Get the total capacity of a collection.  (Can be different from its length.)
\ VACATE             ( collection -- )
\   Deletes all items from a collection.
\ >TOP               ( collection -- adr )
\   Get the address of the topmost item of a collection.  (Index length - 1)
\ PUSHES             ( ... n collection - )
\   Push several items from the stack to a collection.
\ POPS               ( n collection - ... )
\   Pop several items from a collection onto the stack.
\ EACH>              ( collection -- <code> )
\   DOES> style EACH.
\ SOME               ( xt filter-xt collection -- )  ( val -- )  ( val -- flag )
\   Iterate on items satisfying the filter.
\ SOME>              ( filter-xt collection -- <code> )   ( val -- flag )
\   DOES> style SOME.
\ GATHER             ( src-collection dest-collection -- )
\   Pushes all the items from one collection to another.
\ COPY               ( src-collection dest-collection -- )
\   Same as gather but vacates the source collection.
\ UNSERT             ( i collection -- val )
\   Reverse of INSERT; extracts a value/node from a collection at given index i.
\ WHICH              ( i xt collection -- i | -1 )  ( val -- flag )
\   Returns first index of item that satisfies given test xt.
\   If it's not found, it returns -1.
\ INDEXOF            ( index val collection -- index )
\   Get the index of the first instance of val, starting the search at given index.
\ TODO: (generics)
\ DIFF               ( filter-xt src-collection dest-collection -- )  ( adr -- flag )  

\ Other TODO:
\ SPLICE             ( src-collection start-i length dest-i dest-collection -- )  \ collections must be the same type
\ dynamic collection allocation support
\ GRAFT              ( src-node dest-node -- )  \ efficiently move children of one node (collection?) to another
\ DONE / ENOUGH / ???  Break from itteration.

defer new-node   ( -- node )
defer free-node  ( node -- )


vocabulary venery
: venery-internal  only forth also venery definitions ;
: venery-public  only forth definitions also venery ;

venery-internal
    0 value xt
    0 value xt2
    0 value filter
    : /allot  here over allot swap erase ;
    : bounds  over + swap ;
    : ?move  dup if move else drop drop drop then ;
    : sfield  ( struct bytes - <name> )  ( adr - adr+n )
    create over @ ,  swap +!  does> @ + ;
    : svar  cell sfield ;
    : struct  variable ;
    : sembed  @ sfield ;
    : *struct  here swap @ /allot ;
    : sizeof  @ ;
    [undefined] bytes [if] : bytes ; [then]

venery-public
    struct %collection
        %collection svar collection.vtable
        %collection svar collection.length
        %collection svar collection.capacity
venery-internal

    : vector  ( n - <name> n+1 )  ( ??? collection - ??? )
        create dup cells , 1 +
        does> @ over collection.vtable @ + @ execute ;

    : vtable  ( n - <name> collection 0 )  
        create here swap cells /allot 0 ;
        
    : :vector  ( collection ofs - <code> ; collection ofs+cell )
        2dup :noname -rot cells + ! 1 + ;

venery-public

0
vector []              ( i collection -- adr )
vector truncate        ( newlength collection -- )
vector push            ( val collection -- )
vector pop             ( collection -- val )
vector each            ( xt collection -- )  ( val -- )
vector deletes         ( index count collection -- )
vector .each           ( collection -- )
vector remove          ( val collection -- )  
vector ?@              ( adr collection -- val )  
vector removeat        ( i collection -- )
vector insert          ( val i dest-collection -- )
constant collection-vtable-size

: length  ( collection -- n )
    collection.length @ ;

: inbounds?  ( n collection -- flag )
    length < ;
    
: capacity  ( collection -- n )
    collection.capacity @ ;

: vacate  ( collection -- )
    0 swap truncate ;

: >top  ( collection -- adr )
    dup length 1 - swap [] ;

: pushes  ( ... n collection - )
    locals| s |  0 ?do  s push  loop ;

: pops  ( n collection - ... ) 
    locals| s |  0 ?do  s pop  loop ;

: each>  ( collection -- <code> )
    r> code> swap each ;

: (some)  dup >r filter execute if r> xt2 execute else r> drop then ;
: some  ( xt filter-xt collection -- )  ( val -- )  ( val -- flag )
    xt2 >r  -rot  filter >r  to filter to xt2  
    ['] (some) swap each 
    r> to xt2 r> to filter 
;

: some>  ( filter-xt collection -- <code> )
    r> code> -rot some ;
    
: []@  ( i collection -- val )
    dup >r [] r> ?@ ;
    
: gather ( src-collection dest-collection -- )
    locals| b a |
    a length b length + b capacity > abort" Error in GATHER: Destination collection is too small."
    a length 0 do  i a []@  b push  loop ;

: copy ( src-collection dest-collection -- )
    dup vacate gather ;
    
: more? ( collection n -- flag )  \ checks if out of space or empty after n items added/subtracted
    swap dup >r length + dup 0 < swap  r> capacity > or ;

: unsert ( i collection -- val )
    locals| a i |
    a -1 more? abort" Error in UNSERT: Collection is empty."
    i a []@
    i a removeat
;

: which ( i xt collection -- i | -1 )  ( val -- flag )
    xt >r swap to xt
    dup length rot do
        i swap >r r@ []@ xt execute if
            r> drop i unloop r> to xt exit 
        then
    r> loop 
    drop r> to xt
    -1
;

: indexof  ( index val collection -- index | -1 )  
    locals| c itm |
    begin  dup c inbounds? while
        dup c []@ itm = ?exit
        1 +
    repeat
    drop -1 ;

include ramen/venery/array.f
include ramen/venery/string.f
include ramen/venery/nodetree.f

only forth definitions

\ test
also venery  \ just in order to call SIZEOF
create s 100 *stack drop
: numbers  locals| c |  c vacate  c capacity 0 do  i c push  loop ;
s numbers

:noname  %node sizeof allocate throw dup /node ; is new-node
:noname  free throw ; is free-node

new-node constant p
new-node constant n1  n1 p push
new-node constant n2  n2 p push
new-node constant n3  n3 p push
new-node constant n4  n4 p push
new-node constant p2
new-node constant n5  n5 p2 push
new-node constant n6  n6 p2 push
new-node constant n7  n7 p2 push
new-node constant n8  n8 p2 push

only forth definitions
