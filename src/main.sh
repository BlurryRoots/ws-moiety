#!/bin/zsh
#
#
# Copyright (c) 2024-∞ Sven Freiberg
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

moiety-modules-root-path () {
	echo "$HOME/Workspace/Modules"
	return 0
}

moiety-module-lfs-server-start () {
	LFS_LISTEN="tcp://:6633"
	LFS_HOST="127.0.0.1:6633"
	LFS_METADB="$(moiety-modules-root-path)/.LFS/MetaData.db"
	LFS_CONTENTPATH="$(moiety-modules-root-path)/.LFS/Content"
	LFS_ADMINUSER="local"
	LFS_ADMINPASS="local"

	# Make sure lfs cache path exists.
	mkdir -p "${LFS_CONTENTPATH}"

	local log_location="$(pwd)/logs"

	local rv=0
	pushd "$(moiety-modules-root-path)/.LFS" > /dev/null
		export LFS_LISTEN LFS_HOST LFS_METADB LFS_CONTENTPATH LFS_ADMINUSER LFS_ADMINPASS; \
			./lfs-test-server \
				 > "$log_location/lfs.log" \
				2> "$log_location/lfs.err"&
		if [ $? = 0 ]; then
			local lfs_server_pid="$!"
			echo "LFS server started with $lfs_server_pid."
		else
			echo "Could not start lfs server."
			rv=13
		fi
	popd > /dev/null

	echo $lfs_server_pid > .moiety.lfs.pid

	return $rv
}

moiety-module-lfs-server-stop () {
	local server_pid=$1

	if ! kill -9 $server_pid; then
		echo "Could not stop lfs server."
		return -23
	fi

	return 0
}

moiety-module-lfs-server-pid () {
	if [ ! -e .moiety.lfs.pid ]; then
		return 13
	fi
	local lfs_pid="$(cat .moiety.lfs.pid)"

	echo $lfs_pid
	return 0
}

moiety-module-git-server-repo-list-file () {	
	echo "module.list"
	return 0
}

moiety-module-git-server-start () {
	local bare_repos_root="bare"

	echo "Checking for repositories to whitelist ..."
	local f=()
	#readarray -t bare_repos < $(moiety-module-git-server-repo-list-file)
	# zsh does not support readarray?!
	bare_repos=("${(@f)$(< $(moiety-module-git-server-repo-list-file))}")
	for candidate in ${bare_repos[@]}; do
		local bare_path="$bare_repos_root/$candidate"
		echo "Processing candidate: '$bare_path' ..."
		f+=($(realpath -s $bare_path)) # dont resolve symlinks, just exand path
	done

	echo "Starting git daemon ..."
	/usr/lib/git-core/git-daemon --verbose --export-all \
		--base-path="$(pwd)/$bare_repos_root" --reuseaddr \
		--enable=receive-pack ${f[@]} \
		> logs/git.log 2> logs/git.err &
	local git_server_pid="$!"

	if [ $? = 0 ]; then
		echo "Server started as $git_server_pid."
		echo $git_server_pid > .moiety.git.pid
	else
		echo "Could not start git server daemon."
	fi

	return 0
}

moiety-module-git-server-stop () {
	local server_pid=$1

	if ! kill -9 $server_pid; then
		echo "Git server was not running."
		return -33
	fi

	return 0
}

moiety-module-git-server-pid () {
	if [ ! -e .moiety.git.pid ]; then
		return 13
	fi
	local git_pid="$(cat .moiety.git.pid)"
	
	echo $git_pid
	return 0
}

moiety-server-help () {
	local usage="USAGE: ${self} server [server_data_path] [command] [arguments]"
	usage="${usage}\ncommands:"
	usage="${usage}\n\tstart"
	usage="${usage}\n\tstatus"
	usage="${usage}\n\tstop"

	printf "%b" "${usage}"
	return 0
}

moiety-module-server-start () {
	if moiety-module-server-status > /dev/null; then
		echo "Module server seems up alread."
		moiety-module-server-status

		return 13
	fi

	echo "Preparing log file location ..."
	mkdir -p logs

	echo "Starting LFS server ..."
	#.LFS/./start.sh
	if ! moiety-module-lfs-server-start; then
		echo "Could not start lfs server."
		return -13
	fi

	if ! moiety-module-git-server-start; then
		echo "Could not start git server."
		return -23
	fi

	return 0
}

moiety-module-server-status () {
	echo "Looking for processes ..."
	if ! moiety-module-lfs-server-pid > /dev/null; then
		echo "No pid file for lfs server found."
		return 13
	fi
	local lfs_pid=$(moiety-module-lfs-server-pid)

	if ! moiety-module-git-server-pid > /dev/null; then
		echo "No pid file for git server found."
		return 13
	fi
	local git_pid=$(moiety-module-git-server-pid)

	echo "git-server: ${git_pid}"
	echo "lfs-server: ${lfs_pid}"
	return 0
}

moiety-module-server-stop () {
	if ! moiety-module-server-status > /dev/null; then
		echo "Module server seems down. Skipping stop routine."
		return 13
	fi

	echo "Stopping moiety module server ..."

	local lfs_pid=$(moiety-module-lfs-server-pid)
	local git_pid=$(moiety-module-git-server-pid)

	echo "Shutting down git daemon ($git_pid) ..."
	if ! moiety-module-git-server-stop $git_pid; then
		echo "?"
	else
		echo "Git server exited."
		rm .moiety.git.pid
	fi

	echo "Shutting down lfs server ($lfs_pid) ..."
	##if ! "$(moiety-modules-root-path)"/.LFS/./stop.sh; then
	#if ! kill -9 ${server_pids[2]}; then
	#	echo "Could not stop lfs server."
	#fi
	if ! moiety-module-lfs-server-stop $lfs_pid; then
		echo "??"
	else
		echo "LFS server exited."
		rm .moiety.lfs.pid
	fi

	echo "Removing pid file ..."
	rm -f .moiety.pid

	return 0
}

moiety-module-server () {
	if [ $# -lt 1 ]; then
		moiety-server-help
		return -3
	fi

	local cmd="$1"
	shift

	local rv=0
	case $cmd in
		help|h )
			moiety-help
			rv=$?
		;;

		start )
			if ! moiety-module-server-start $*; then
				rv=$?
			fi
		;;

		stop )
			if ! moiety-module-server-stop $*; then
				rv=$?
			fi
		;;

		status)
			if ! moiety-module-server-status $*; then
				rv=$?
				echo "Module server down."
			else
				echo "All seems well."
			fi
		;;
	esac

	return $rv
}

moiety-module-help () {	
	local usage="USAGE: ${self} module <options> [command] [arguments]"
	usage="${usage}\ncommands:"
	usage="${usage}\n\tcreate"
	usage="${usage}\n\tstatus"

	printf "%b" "${usage}"
	return 0
}

moiety-module-create () {
	local repo_name="$1"
	local repo_path=$(realpath "$repo_name")
	echo "About to create module repo for \"$repo_name\" ..."
	if [ -e "$repo_path" ]; then
		echo "Directory at \"$repo_path\" already exists. Aborting ..."
		return -1
	fi

	mkdir "$repo_path"
	if pushd "$repo_path"; then
			echo "Preparing config file ..."
			git config --file config init.defaultBranch main
			git config --file config http.receivepack true
			
			echo "Creating repository metadata ..."
			git --bare init --shared
			
			echo "Voilà!"
			ls -lav .
		popd
	else
		echo "Could not enter \"$repo_path\". Aborting ..."
	fi
	return 0
}

moiety-module () {
	if [ $# -lt 1 ]; then
		moiety-module-help
		return -3
	fi

	local cmd="$1"
	shift

	pushd "bare" > /dev/null
		local rv=0
		case $cmd in
			help)
				moiety-module-help
				rv=$?
			;;

			create)
				if ! moiety-module-create $*; then
					rv=$?
				fi
			;;

			status)
				if [ $# -lt 1 ]; then
					echo "Module name missing."
					moiety-module-help
					return -3
				fi

				local repo_path="$1"
				shift

				if [ -e $repo_path/refs/heads ]; then
					echo "$(basename $repo_path) seems to have heads:"
					ls $repo_path/refs/heads
				else
					echo "Module '$repo_path' not found."
				fi

			;;
		esac
	popd > /dev/null

	return $rv
}

moiety-help () {
	#echo "moiety -- v0.6.1"
	local usage="USAGE: ${self} <options> [command] [arguments]"
	usage="${usage}\ncommands:"
	usage="${usage}\n\tserver"
	usage="${usage}\n\tmodule"

	printf "%b" "${usage}"
	return 0
}

main () {
	if [ $# -lt 1 ]; then
		echo "Expecting server path."
		moiety-server-help
		return 13
	fi
	local server_path="$1"
	shift

	if [ $# -lt 1 ]; then
		echo "Command missing."
		moiety-help
		return -33
	fi

	local cmd="$1"
	shift

	pushd "$server_path" > /dev/null
		local rv=0
		case $cmd in
			help|h )
				moiety-help
				rv=$?
			;;

			module)
				if ! moiety-module $*; then
					rv=$?
				fi
			;;

			server)
				echo "Looking for moiety setup in \"$(pwd)\" ..."
				if ! moiety-module-server $*; then
					echo "Could not setup moiety."
					rv=$?
				fi
			;;
		esac
	popd > /dev/null

	return $rv
}

main $*
