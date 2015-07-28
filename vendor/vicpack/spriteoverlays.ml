(*
Copyright (c) 2007, Johan Kotlinski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*)

open Images;;
open OImages;;
open Array;;
open Printf;;

(* sprite overlay detection *)

let write_char channel c = fprintf channel "%c" (char_of_int c);;

class problem_char ix iy iwidth iheight =
    object (self)
        val xpos = ix
        val ypos = iy
        val width = iwidth
        val height = iheight
        val colors = Array.make 64 0

        method init_from (bmp:rgb24) =
            for x = 0 to width - 1 do
                for y = 0 to height - 1 do
                    colors.(x+y*width) <- (bmp#get (xpos+x) (ypos+y)).b
                done
            done

        method x = xpos
        method y = ypos

        method set x y c =
            colors.(x+y*8) <- c

        method clone =
            let newchar = new problem_char xpos ypos width height in
            for x = 0 to width - 1 do
                for y = 0 to height - 1 do
                    newchar#set x y colors.(x+y*width)
                done
            done;
            newchar

        method find_color_that_is_not c =
            let color = ref c in
            for x = 0 to width - 1 do
                for y = 0 to height - 1 do
                    let c2 = colors.(x+y*width) in
                    if c != c2 then
                        color := c2
                done
            done;
            assert (!color != c);
            !color

        method get x y =
            colors.(x+y*width)

        method replace_color screen_x screen_y w h color replacement_color =
            let startx = screen_x - xpos
            and starty = screen_y - ypos in

            for y = (max 0 starty) to (min (height-1) (starty + h)) do
                for x = (max 0 startx) to (min (width-1) (startx + w)) do
                    if colors.(x+y*width) = color then
                        colors.(x+y*width) <- replacement_color
                done
            done

        method color_set =
            let colorset = BitSet.create 16 in
            for x = 0 to width-1 do
                for y = 0 to height-1 do
                    BitSet.set colorset colors.(x+y*width)
                done
            done;
            colorset

        method color_count =
            BitSet.count self#color_set
    end
;;

let is_problem_char bmp start_x start_y charwidth charheight =
    let colors = BitSet.create 16 in

    for x = start_x to start_x + (charwidth-1) do
        for y = start_y to start_y + (charheight-1) do
            let color = bmp#get x y in
            BitSet.set colors color.b
        done
    done;

    let color_count = (BitSet.count colors) in
    color_count > 2
;;

let find_initial_problem_chars bmp charwidth charheight =
    let problem_chars = ref [] in
    for yi = 0 to bmp#height / charheight - 1 do
        for xi = 0 to bmp#width / charwidth - 1 do
            let x = xi * charwidth 
            and y = yi * charheight in
            
            if is_problem_char bmp x y charwidth charheight then
                let pc = new problem_char x y charwidth charheight in
                pc#init_from bmp;
                problem_chars := pc :: !problem_chars
        done
    done;

    !problem_chars
;;

let get_possible_startpoints problem_chars color =
    let scratchpad = Array.make (321*201) 0
    and forbid = 4
    and allow_h = 1
    and allow_v = 2
    and color_match = 8 in
    let allow = allow_h lor allow_v in

    let startpoints = ref [] in

    let handle ch =
        let ch_x = ch#x
        and ch_y = ch#y in
        for yy = 0 to 7 do
            for xx = 0 to 7 do
                let thiscolor = ch#get xx yy in
                if thiscolor = color then
                    begin
                        let x = ch_x + xx
                        and y = ch_y + yy in
                        unsafe_set scratchpad (x + 321 * y) color_match
                    end
            done
        done
    in

    List.iter handle problem_chars;

    let counter = ref 0 in
    for y = 199 downto 0 do
        counter := 0;
        for x = 319 downto 0 do
            let pos = x + 321 * y in
            if scratchpad.(pos) != 0 then
                counter := 24;
            if !counter != 0 then
                begin
                    scratchpad.(pos) <- scratchpad.(pos) lor allow_h;
                    scratchpad.(pos + 321) <- scratchpad.(pos + 321) lor forbid;
                    decr counter
                end
        done
    done;
    for x = 319 downto 0 do
        counter := 0;
        for y = 199 downto 0 do
            let pos = x + 321 * y in
            if scratchpad.(pos) land color_match != 0 then
                counter := 21;
            if !counter != 0 then
                begin
                    scratchpad.(pos) <- scratchpad.(pos) lor allow_v;
                    scratchpad.(pos + 1) <- forbid;
                    decr counter
                end
        done
    done;

    for y = 0 to 199 do
        for x = 0 to 319 do
            if (unsafe_get scratchpad (x + 321 * y)) land (allow lor forbid) = allow then
                startpoints := (x, y) :: !startpoints
        done
    done;
    !startpoints
;;

let get_sprite_options problem_chars =
    let options = ref [] in

    let colorset = BitSet.create 16 in
    let add_color_set ch =
        BitSet.unite colorset ch#color_set;
    in

    List.iter add_color_set problem_chars;
    let examine_color problem_chars c =
        let startpoints = get_possible_startpoints problem_chars c in
        let add_startpoint point =
            options := (problem_chars, c, point) :: !options
        in
        List.iter add_startpoint startpoints
    in

    let colorEnum = BitSet.enum colorset in
    Enum.iter (examine_color problem_chars) colorEnum;
    !options
;;

let apply_sprite_option chars color (x, y) =
    let new_charlist = ref [] in
    let apply ch =
        if ch#x + 7 >= x &&
            ch#y + 7 >= y &&
            ch#x <= x + 23 &&
            ch#y <= y + 23 
        then
            begin
                let new_ch = ch#clone in
                let replacement_color = new_ch#find_color_that_is_not color in
                new_ch#replace_color x y 23 20 color replacement_color;
                if new_ch#color_count > 2 then
                    new_charlist := new_ch :: !new_charlist
            end
        else
            new_charlist := ch :: !new_charlist
    in
    List.iter apply chars;
    !new_charlist
;;

let rec handle_problem_chars chars =
    let shortest_charcount = ref 100000
    and options = get_sprite_options chars
    and best_option = ref (0, 0, 0)
    and queue = ref [] in

    let handle_option (chars, color, (x,y)) =
        let problem_chars = apply_sprite_option chars color (x,y) in
        if problem_chars = [] then
            begin
                best_option := (color, x, y);
                queue := [];
                shortest_charcount := 0
            end
        else
            let charcount = List.length problem_chars in
            if charcount < !shortest_charcount then
                begin
                    best_option := (color, x, y);
                    queue := [problem_chars];
                    shortest_charcount := charcount
                end
    in
    List.iter handle_option options;
    (!best_option, !queue)
;;

class sprite ix iy ic =
    object (self)
        val m_x = ix
        val mutable m_y = iy
        val c = ic
        val pixels = Array.make (24*21) false

        method x = m_x
        method y = m_y
        method color = c

        method init_from (bmp:rgb24) =
            for x = m_x to m_x+23 do
                for y = m_y to m_y+20 do
                    if x < bmp#width && y < bmp#height then
                        if is_problem_char bmp (x land 0xff8) (y land 0xff8)
                            8 8 then
                            if c = (bmp#get x y).b then
                                pixels.( (x - m_x) + 24 * (y - m_y) ) <- true;
                done
            done

        method remove_from (bmp:rgb24) =
            for x = m_x to m_x+23 do
                for y = m_y to m_y+20 do
                    if x < bmp#width && y < bmp#height then
                        if pixels.( (x-m_x) + 24 * (y-m_y) ) then
                            let new_color = {r = 0xff; g = 0xff; b = 0xff} in
                            bmp#set x y new_color
                done
            done

        method height =
            let max_set_y = ref 0 in
            for y = 0 to 20 do
                for x = 0 to 23 do
                    if pixels.(x + 24 * y) then
                        max_set_y := y
                done
            done;
            1 + !max_set_y

        method lowest_used_line =
            m_y + 20 

        method dump oc =
            let rowValue = ref 0
            and pixelCount = ref 0 in
            let write pixel =
                rowValue := !rowValue lsl 1;
                if pixel then
                    rowValue := !rowValue + 1;
                incr pixelCount;
                if !pixelCount = 8 then
                    begin
                        write_char oc !rowValue;
                        rowValue := 0;
                        pixelCount := 0
                    end
            in
            for y = 0 to 20 do
                for x = 0 to 23 do
                    write pixels.(x + 24 * y)
                done
            done;
            write_char oc 0

        method bottom_row_is_empty =
            let retval = ref true in
            for x = 0 to 23 do
                if pixels.(x + 24 * 20) then
                    retval := false
            done;
            !retval

        method pull_up =
            (*printf "pull up\n";*)
            m_y <- m_y - 1;

            for x = 0 to 23 do
                for y = 20 downto 1 do
                    pixels.(x + 24 * y) <- pixels.(x + 24 * (y-1))
                done;
                pixels.(x) <- false
            done

        method pull_up_to swapline =
            while (m_y > swapline) && self#bottom_row_is_empty do
                self#pull_up
            done

    end
;;


let compare sprite1 sprite2 =
    sprite1#y - sprite2#y

let find_free_slot spritemap =
    let slot = ref 0xff in
    for i = 7 downto 0 do
        if spritemap.(i) = 0xff then
            slot := i
    done;
    !slot
;;

let dump_sprites file sprites =
    let outfilename = file ^ "-sprites.bin" in
    let oc = open_out_bin outfilename in

    let dump_sprite sprite =
        sprite#dump oc
    in
    List.iter dump_sprite sprites;
    close_out oc
;;

let statesprites sprites spritemap =
    let tmp = ref [] in
    for i = 0 to 7 do
        let spriteindex =
            if spritemap.(i) = 0xff then
                0
            else
                spritemap.(i)
        in
        tmp := !tmp @ [List.nth sprites spriteindex]
    done;
    assert (List.length !tmp <= 8);
    !tmp
;;

let handle_sprite_overlays file bmp debug charwidth charheight =
    let problem_chars = find_initial_problem_chars bmp charwidth charheight
    and queue = ref []
    and sprites = ref [] in
    queue := !queue @ [problem_chars];
    while !queue != [] do
        match !queue with
        | head :: tail ->
                let (best_option, new_queue) = handle_problem_chars head in
                let (color, x, y) = best_option in
                queue := tail @ new_queue;
                let s = new sprite x y color in
                s#init_from bmp;
                sprites := s :: !sprites;
        | [] -> failwith "couldn't reach end??"
    done;

    sprites := List.sort compare !sprites;

    let fprint_return oc swapline =
        fprintf oc "    ;\n    lda #%d\n" swapline;
        fprintf oc "    sta $d012\n";
        fprintf oc "    lda #<swap_%d\n" swapline;
        fprintf oc "    sta $314\n";
        fprintf oc "    lda #>swap_%d\n" swapline;
        fprintf oc "    sta $315\n";
        fprintf oc "    jmp return\n\n"
    in
    let remove_from_image bmp sprite =
        sprite#remove_from bmp
    in
    List.iter (remove_from_image bmp) !sprites;

    let swap_filename = file ^ "-swap.a" in
    let oc_swap = open_out swap_filename in
    let sprite_counter = ref 0
    and border_x = 0x18
    and border_y = 0x32
    and prev_swapline = ref (-25)
    and spritemap = (Array.make 8 0xff)
    and prev_coord_x = (Array.make 8 (-1)) 
    and prev_coord_y = (Array.make 8 (-1)) 
    and prev_coord_msb = ref (-1) 
    and prev_color = (Array.make 8 (-1)) 
    and prev_ptr = (Array.make 8 (-1)) 
    and is_first_state = ref true 
    and first_real_swapline = ref 0 in

    let dump_state debug (file:string) (swapline:int) sprites indexes oc =
        let real_swapline = !prev_swapline + border_y - 1 in 

        if !is_first_state then
            begin
                is_first_state := false;
                first_real_swapline := real_swapline
            end
        else
            fprint_return oc_swap real_swapline;

        fprintf oc "swap_%d:\n" real_swapline;

        let prev_acc = ref (-1) in
        let lda acc =
            if acc = !prev_acc then
                fprintf oc ";";
            fprintf oc "    lda #%d\n" acc;
            prev_acc := acc
        in

        let y_sort_list = ref [] in
        for i = 0 to 7 do
            let sprite = (List.nth sprites) i in
            sprite#pull_up_to (!prev_swapline+2);
            y_sort_list := (i, sprite#y) :: !y_sort_list
        done;
        prev_swapline := swapline;

        (* sort sprites by y pos... *)
        let compare (i1, y1) (i2, y2) = y1 - y2 in
        y_sort_list := List.sort compare !y_sort_list;

        (* msb x *)
        let msb_x = ref 0 in
        for i = 0 to 7 do
            msb_x := !msb_x lsr 1;
            let sprite = List.nth sprites i in
            if (sprite#x + border_x) > 0xff then
                msb_x := !msb_x + 0x80
        done;

        assert (!msb_x < 0x100);
        if !prev_coord_msb != !msb_x then
            begin
                lda !msb_x;
                fprintf oc "    sta $d010\n";
                prev_coord_msb := !msb_x
            end;

        for ii = 0 to 7 do
            let (i,y_ignore) = List.nth !y_sort_list ii in
            if indexes.(i) != 0xff && indexes.(i) != prev_ptr.(i) then
                begin
                    lda indexes.(i);
                    fprintf oc "    sta sprite_ptrs + %d\n" i;
                    prev_ptr.(i) <- indexes.(i)
                end;

            assert (i < List.length sprites);
            let sprite = List.nth sprites i in
            let sprite_x = ((sprite#x + border_x) land 0xff) in
            if prev_coord_x.(i) != sprite_x then
                begin
                    lda sprite_x;
                    fprintf oc "    sta $d00%x\n" (i*2);
                    prev_coord_x.(i) <- sprite_x
                end;
            let sprite_y = (sprite#y + border_y) in
            if prev_coord_y.(i) != sprite_y then
                begin
                    lda sprite_y;
                    fprintf oc "    sta $d00%x\n" (i*2+1);
                    prev_coord_y.(i) <- sprite_y
                end;

            let sprite = List.nth sprites i in
            if prev_color.(i) != sprite#color then
                begin
                    lda sprite#color;
                    fprintf oc "    sta $%x\n" (0xd027 + i);
                    prev_color.(i) <- sprite#color
                end;
        done;


    in
        
    let handle debug sprite =
        if debug then
            printf "swap in sprite x: %d y: %d color: %d height: %d\n" 
                sprite#x sprite#y sprite#color sprite#height;
        let get_sprite n =
            assert ((List.length !sprites) > n);
            (List.nth !sprites n)
        in

        let slot = ref (find_free_slot spritemap) in
        if !slot = 0xff then
            begin
                let sprite_start = sprite#y in
                let swapline = sprite_start - 2
                and did_clean = ref false in

                dump_state debug file swapline (statesprites !sprites spritemap)
                    spritemap oc_swap;
                for i = 0 to 7 do
                    let sprite = get_sprite spritemap.(i) in
                    if sprite#lowest_used_line < (swapline) then
                        begin
                            if debug then
                                printf "swap out sprite x: %d y: %d\n" sprite#x sprite#y;
                            spritemap.(i) <- 0xff;
                            did_clean := true
                        end
                done;
                if not !did_clean then
                    failwith ("Too many sprites at line " ^ (string_of_int swapline));
                    
                slot := find_free_slot spritemap;
                assert (!slot != 0xff)
            end;

        spritemap.(!slot) <- !sprite_counter;
        incr sprite_counter
    in
    List.iter (handle debug) !sprites;
    dump_state debug file 0 (statesprites !sprites spritemap) spritemap oc_swap;
    fprint_return oc_swap !first_real_swapline;
    dump_sprites file !sprites;
    close_out oc_swap
;;

(* sprite overlay detection - end *)

