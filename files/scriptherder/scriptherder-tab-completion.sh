# shellcheck disable=SC2148
_scriptherder() {
	local cur prev OPTS

	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD - 1]}"

	case $prev in
	'check' | 'ls' | 'lastlog' | 'lastfaillog')
		local JOBS
		# shellcheck disable=SC2086
		JOBS="$(basename -s '.ini' /etc/scriptherder/check/${2}*)"
		mapfile -t COMPREPLY < <(compgen -W "${JOBS}" -- "${cur}")
		return 0
		;;
	'wrap')
		# not supported
		return 0
		;;

	# Allow access to cur below
	'scriptherder')
		true
		;;
	*)
		return 0
		;;
	esac

	case $cur in
	*)
		OPTS="check
		      ls
		      lastlog
			    lastfaillog
		     	wrap"
		mapfile -t COMPREPLY < <(compgen -W "${OPTS[*]}" -- "${cur}")
		return 0
		;;
	esac
}
complete -F _scriptherder scriptherder
