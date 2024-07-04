	.globl main
.eqv offset_name		0
.eqv offset_header_data 	4
.eqv offset_pixels_data		8
.eqv offset_width_img		12
.eqv offset_height_img		16
.eqv offset_bytes_per_line	20

	.data
img_struct_desc: 	.space	24	# input image descriptor
output_struct_desc:	.space	24	# output image descriptor

R_table:	.space	25	# board on R-values from a 5x5 window
G_table:	.space	25	# board on G-values from a 5x5 window
B_table:	.space	25	# board on B-values from a 5x5 window

	.align 2		#wyrównanie dummy i bmpHeader do 2 bajtów
dummy:		.space 2	#wyrównanie adresów przestrzeni -> dummy pusta przestrzeń
bmpHeader:	.space	54

	.align 2
dummy2:		.space 2
outBmpHeader:	.space	54 

input_name:	.asciz "polana.bmp"
output_name:	.asciz "wynik.bmp"

	.text
main:
	# filling in the input image descriptor
	la a0, img_struct_desc 
	la t0, input_name
	sw t0, offset_name(a0)
	la t0, bmpHeader
	sw t0, offset_header_data(a0)
	jal	read_bmp
	bnez a0, main_failure
	
	# filling in the output image descriptor
	la a0, output_struct_desc 
	la t0, input_name
	sw t0, offset_name(a0)
	la t0, outBmpHeader
	sw t0, offset_header_data(a0)
	jal	read_bmp
	bnez a0, main_failure
	
	la a0, img_struct_desc
	jal filter

main_failure:	
	li a7, 10
	ecall

#============================================================================
# read_bmp: 
#	reads the content of a bmp file into memory
# arguments:
#	a0 - address of image descriptor structure
#		input filename pointer, header and image buffers should be set
# return value: 
#	a0 - 0 if successful, error code in other cases
read_bmp:
	mv t0, a0					# preserve img_struct_desc structure pointer
#open file
	li a7, 1024
    	lw a0, offset_name(t0)
    	li a1, 0					#flags: 0-read file
    	ecall
	
	blt a0, zero, rb_error
	mv t1, a0					# save file handle for the future
	
#read header
	li a7, 63
	lw a1, offset_header_data(t0)
	li a2, 54
	ecall
	
#extract image information from header
	lw a0, 18(a1)					#18 - width offset
	sw a0, offset_width_img(t0)
	mv a4, a0	
	
	# compute line size in bytes - bmp line has to be multiple of 4
	add a2, a0, a0
	add a0, a2, a0					# pixelbytes = width * 3 
	addi a0, a0, 3
	srai a0, a0, 2
	slli a0, a0, 2					# linebytes = ((pixelbytes + 3) / 4 ) * 4
	sw a0, offset_bytes_per_line(t0)
	
	lw a0, 22(a1)					#22 - height offset
	sw a0, offset_height_img(t0)
	mv a5, a0
	
#allocate heap memory for pixels data 
	li s10, 3
	mul a6, a4, a5
	mul a6, a6, s10					#memory to allocate = width*height*3
	
	li a7, 9
	mv a0, a6
	ecall
	#return adress of heap memory in a0
	
	sw a0, offset_pixels_data(t0)			#store adress to heap memory in structure of file
	
#read image data
	li a7, 63
	mv a0, t1
	lw a1, offset_pixels_data(t0)
	mv a2, a6					#in a6 is how many heap memory was allocate
	ecall

#close file
	li a7, 57
	mv a0, t1
    	ecall
	
	mv a0, zero
	jr ra
	
rb_error:
	li a0, 1					# error opening file	
	jr ra
	
# ============================================================================
# save_bmp - saves bmp file stored in memory to a file
# arguments:
#	a0 - address of ImgInfo structure containing description of the image`
# return value: 
#	a0 - zero if successful, error code in other cases

save_bmp:
	mv t0, a0					# preserve structure pointer
	
#open file
	li a7, 1024
    	lw a0, offset_name(t0)	 
    	li a1, 1					#flags: 1-write file
    	ecall
	
	blt a0, zero, wb_error
	mv t1, a0					# save file handle for the future
	
#write header
	li a7, 64
	lw a1, offset_header_data(t0)
	li a2, 54
	ecall
	
#write image data
	li a7, 64
	mv a0, t1
							# compute image size (linebytes * height) to a2 argument
	lw a2, offset_bytes_per_line(t0)
	lw a1, offset_height_img(t0)
	mul a2, a2, a1
	lw a1, offset_pixels_data(t0)
	ecall

#close file
	li a7, 57
	mv a0, t1
    	ecall
	
	mv a0, zero
	jr ra

wb_error:
	li a0, 2 					# error writing file
	jr ra


# ============================================================================
# set_pixel - sets the color of specified pixel
#arguments:
#	a0 - address of ImgInfo image descriptor
#	a1 - x coordinate
#	a2 - y coordinate - (0,0) - bottom left corner
#	a3 - 0RGB - pixel color
#return value: none
#remarks - a0, a1, a2 values are left unchanged

set_pixel:
	lw t1, offset_bytes_per_line(a0)
	mul t1, t1, a2  				# t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 					# t0 = x * 3
	add t0, t0, t1  				# t0 is offset of the pixel from begging pixels data

	lw t1, offset_pixels_data(a0) 			
	add t0, t0, t1 					# t0 is address of the pixel
	
	#set new color
	sb   a3,(t0)		#store B-value
	srli a3, a3, 8
	sb   a3, 1(t0)		#store G-value
	srli a3, a3, 8
	sb   a3, 2(t0)		#store R-value

	jr ra

# ============================================================================
# get_pixel- returns color of specified pixel
#arguments:
#	a0 - address of ImgInfo image descriptor
#	s3 - x coordinate
#	s4 - y coordinate - (0,0) - bottom left corner
#return value:
#	a0 - 0RGB - pixel color
#remarks: a1, a2 are preserved

get_pixel:
	addi s9, s9, 1
	
	#get from (x,y) indexes offset from the begging as in the set_pixel function
	lw t1, offset_bytes_per_line(a0)
	mul t1, t1, s4 						
	add t0, s3, s3
	add t0, t0, s3 						
	add t0, t0, t1  					

	lw t1, offset_pixels_data(a0) 
	add t0, t0, t1 					# t0 is address of the pixel
	
	#s9 is the counter of how many pixels have been loaded -1 ( meaning the first colour will be stored at index 0 of the .space )
	
	#get color
	lbu a0,(t0)					#load B-value
	la s8, B_table
	add s8, s8, s9 
	sb a0, (s8)
	
	lbu t1,1(t0)					#load G-value
	la s8, G_table
	add s8, s8, s9 
	sb t1, (s8)
	
	slli t1,t1,8
	or a0, a0, t1
	
	lbu t1,2(t0)					#load R-value
	la s8, R_table
	add s8, s8, s9 
	sb t1, (s8)
	
    	slli t1,t1,16
	or a0, a0, t1
					
	jr ra

# ============================================================================

filter:
	lw s1, offset_width_img(a0)	
	lw s2, offset_height_img(a0)	

	# Loop 1 passing through all fields of the board
	li a1, 0 # x coordinate
	li a2, 0 # y coordinate
	
	addi a2, a2, -1
	
	loopy:
	li a1, 0
  	addi a2, a2, 1
  	bgt a2, s2, finish_scan	
  	li s9, -1		#I set the counter s9 to -1 so that the first colour is stored at position 0 in the space
  	jal loop_square	#in this case, the counter will show 1 less at the end
  	
  		loopx:
    		addi a1, a1, 1
    		bgt a1, s1, loopy	
    		li s9, -1
    		jal loop_square
    		
    		j loopx

loop_square:
	mv s3, a1  # x coordinate
	mv s4, a2  # y coordinate
	
	addi s3, s3, -2	#x
	addi s4, s4, -2	#y
	
	mv t0, s3 #saving the start setting x
	mv t1, s4 #saving the start setting y
	
	addi t2, t0, 5	#here is the maximum value of the right-hand side border x
	addi t3, t1, 5	#here is the maximum value of the right-hand side border y
	
	addi s4, s4, -1#I undo y by 1
	
	loopy_sq:
		mv t0, a1
		addi t0, t0, -2
		mv s3, t0
		
		addi s4, s4, 1
		bge s4, t3, finish_square
		jal check_pixel_range
		
		la a0, img_struct_desc
		jal get_pixel # here is the rgb download from the pixel
		
	loopx_sq:
		addi s3, s3, 1
		bge, s3, t2, loopy_sq
		jal check_pixel_range
		
		la a0, img_struct_desc
		jal get_pixel # here is the rgb download from the pixel
		
		j loopx_sq
	
finish_square:
	la t0, B_table
	jal bubble_sort
	
	# We set the arguments of the avg_color call
	la t5, B_table
	addi t6, s9, 1
	
	# We call avg_color, the result will be in t4
	jal avg_color
	
	# We write the result of the above call to a4
	mv a4, t4
	
	la t0, G_table
	jal bubble_sort
	
	la t5, G_table
	addi t6, s9, 1
	jal avg_color
	mv a5, t4
	
	la t0, R_table
	jal bubble_sort
	
	la t5, R_table
	addi t6, s9, 1
	jal avg_color
	mv a6, t4

	# Collecting RGB for a3 register
	mv a3, a4
	slli a5, a5, 8
	or a3, a3, a5 
	slli a6, a6, 16
	or a3, a3, a6 
	
	# Descriptor
	la a0, output_struct_desc
	
	jal set_pixel
	
	j loopx
	
check_pixel_range:
	blt s3, zero, out_of_range
	blt s4, zero, out_of_range
	bgeu s3, s1, out_of_range
	bgeu s4, s2, out_of_range
	
	ret	#if it goes all the way through, it comes back to read the pixel
	
out_of_range:
	j loopx_sq	#if it enters a pixel outside the board it returns to loopx_sq, i.e. it goes after the next pixel 
	
#requirements - bubble_sort
#t0 - address to beginning of space
#s9 - counter how many pixels are loaded from a 5x5 window (reduced by 1)
#output - None
bubble_sort: 
    	li s11, 1            				# flag for swapped elements
outer_loop:
	addi t6, s9, 1
	
    	beqz s11, end_sort 				# exit loop if no swaps were made
    	li s11, 0           				# reset swapped flag
    	li t1, 0            
inner_loop:
    	add t2, t1, t0      
    	addi t1, t1, 1      
    	blt t1, t6, compare 				# compare if not end of array
    	j outer_loop        
compare:
    	lbu a0, (t2)        
    	add t5, t0, t1	
    	lbu s5, (t5)    				# load next element
    	blt a0, s5, swap    				# swap if current element is greater than next element
    	j inner_loop        
swap:
    	sb s5, (t2)         
    	sb a0, (t5)     
    	li s11, 1            
    	j inner_loop        
end_sort:
    	ret

# t5 - address of the array
# t6 number of elements in the array (bytes)
# t4 - result
avg:
	add s5, t5, t6 #end of stored bytes in the array
	
	li t4, 0	
	addi t5, t5, -1
	
	avg_loop:
		addi t5, t5, 1
		beq t5, s5, avg_loop_end
		
		lbu s6, (t5)
		add t4, t4, s6
		
		j avg_loop
	
	avg_loop_end:
	divu t4, t4, t6
	
	ret

# t5 - address of the board
# t6 number of elements in the array (bytes)
# t4 - result
avg_color:
	li s5, 10
	bgt t6, s5, avg_color_some
	j avg_color_all

avg_color_all:
	j avg

avg_color_some:
	addi t5, t5, 5
	addi t6, t6, -10
	j avg

finish_scan:

	la a0, output_struct_desc
	la t0, output_name
	sw t0, offset_name(a0)
	jal save_bmp
	
	li a7, 10
	ecall
