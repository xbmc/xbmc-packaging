#!/bin/bash

# simple variable stack implementation
# using spaces for seperation

# create new stack with name
function stack_init() {
	name=$1

	# create variable for it, and initialize as empty
	cmd=`printf '__stack_%s=' $name`
	eval $cmd

	return 0
}

# add value to stack
function stack_push() {
	name=$1
	value=$2

	# prepend value
	cmd=`printf '__stack_%s="%s $__stack_%s"' $name $value $name`
	eval $cmd

	return 0
}

# read complete stack
function stack_get() {
	name=$1

	# read stack data
	cmd=`printf 'echo $__stack_%s' $name`
	data=`eval $cmd`

	echo $data

	return 0
}

# retrieve first value on stack
function stack_head() {
	name=$1

	# retrieve complete stack
	data=`stack_get $name`

	# what if stack is empfy?
	if [ -z "$data" ]; then
		echo "Error: stack \"$name\" is empty!" >&2
		return 1
	fi

	# extract first value
	value=`echo $data | cut -d' ' -f1`
	echo $value

	return 0
}

# remove first value from stack
function stack_pop() {
	name=$1

	# read complete stack
	data=`stack_get $name`

	# make sure stack is not empty
	if [ -z "$data" ]; then
		echo "Error: stack \"$name\" is empty!" >&2
		return 1
	fi

	# extract first value
	value=`echo $data | cut -d' ' -f1`

	# remove first value
	data=`echo $data | sed -e "s;^$value;;g"`

	# write stack back
	cmd=`printf '__stack_%s="%s"' $name "$data"`
	eval $cmd

	return 0
}

function format_file() {
	INFILE="$1"

	# read file line by line
	while IFS= read line; do
		# include statement
		if [[ $line == \#include* ]]; then
			# extract filename
			name=`echo $line | sed -e "s;#include ;;g"`

			# format this file too
			format_file "$name"
		fi
		# define statement
		if [[ $line == \#define* ]]; then
			# extract data
			data=`echo $line | sed -e "s;#define ;;g"`
			name=`echo $data | cut -d' ' -f1`
			value=`echo $data | cut -d' ' -f2`

			# set variable
			eval "$name=$value"

			# continue with next line
			continue
		fi
		# if statement
		if [[ $line == \#if* ]]; then
			# extract statement
			statement=`echo $line | sed -e "s;#if ;;g"`
			#echo $statement

			# evaluate statement
			cmd=`printf '((%s))' "$statement"`
			eval "$cmd"
			r=$?
			if [ "x$r" = "x0" ]; then
				# true
				stack_push ifhistory true

				# push new state, keep
				stack_push state keep
			else
				# false
				stack_push ifhistory false

				# push new state, drop
				stack_push state drop
			fi

			# continue with next line
			continue
		fi
		# elif statement
		if [[ $line == \#elif* ]]; then
			# if last if or elseif was true, then this part will be false
			if [ `stack_head ifhistory` = true ]; then
				stack_pop state
				stack_push state drop
				continue
			else
				# try if this one matches
				# extract statement
				statement=`echo $line | sed -e "s;#elif ;;g"`

				# evaluate statement
				cmd=`printf '((%s))' "$statement"`
				eval "$cmd"
				r=$?
				if [ "x$r" = "x0" ]; then
					# looks good

					# update ifhistory
					stack_pop ifhistory
					stack_push ifhistory true

					# update state
					stack_pop state
					stack_push state keep
				fi
				# else nothing special to do, drop stays
			fi

			# continue with next line
			continue
		fi
		# endif statement
		if [[ $line == \#endif* ]]; then
			# return to previous state
			stack_pop state

			# drop from ifhistory
			stack_pop ifhistory

			# continue with next line
			continue
		fi

		# so this line isn't a statement
		# depending on current state, keep or drop it
		# actually, if there is a drop anywhere in history, drop this line
		data=`stack_get state | sed -e "s;keep;;g" -e "s; ;;g"`
		if [ -z "$data" ]; then
			echo "$line"
		fi
	done < "$INFILE"

	return 0
}

# read arguments
input="$1"
output="$2"

# initialize stacks
# keep track of state
# drop or keep
stack_init state

# default to keep
stack_push state keep

# save a history of if-results
stack_init ifhistory

# do the work
# TODO catch error output
format_file "$input" > "$output"

# clean up
stack_pop state

# sanity-check
# if any stack is not empty, something went wrong
data=`stack_get state`
if [ ! -z "$data" ]; then
	echo "Error: invalid state" >&2
	exit 1
fi

data=`stack_get ifhistory`
if [ ! -z "$data" ]; then
	echo "Error: invalid ifhistory" >&2
	exit 1
fi
