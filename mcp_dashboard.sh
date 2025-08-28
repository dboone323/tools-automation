#!/usr/bin/env bash
# Minimal MCP dashboard CLI
MCP_URL=${MCP_URL:-http://127.0.0.1:5005}

cmd=${1:-list}
case "$cmd" in
list)
	curl -s "$MCP_URL/status" | python3 -c "import sys,json;d=json.load(sys.stdin);print('\n'.join([f'{t.get('id','-'):12} {t.get('project','-'):20} {t.get('status','-'):8} {t.get('returncode','-')}' for t in d.get('tasks',[])]))"
	;;
show)
	tid=${2-}
	if [[ -z $tid ]]; then
		echo "Usage: $0 show <task_id>" >&2
		exit 2
	fi
	curl -s "$MCP_URL/status" | python3 - <<PY
import sys, json
tid=sys.argv[1]
data=json.load(sys.stdin)
task=next((t for t in data.get('tasks',[]) if t.get('id')==tid),None)
print(json.dumps(task, indent=2))
PY
	;;
artifacts)
	ART_DIR="$(dirname "$0")/artifacts"
	sub=${2:-list}
	case "$sub" in
	list)
		if [[ -d $ART_DIR ]]; then
			echo "Artifacts in $ART_DIR:"
			ls -1 "$ART_DIR" | sed -n '1,200p'
		else
			echo "No artifacts dir yet ($ART_DIR)"
		fi
		;;
	show)
		pkg=${3-}
		if [[ -z $pkg ]]; then
			echo "Usage: $0 artifacts show <package.tar.gz>" >&2
			exit 2
		fi
		if [[ -f "$ART_DIR/$pkg" ]]; then
			tar -tzf "$ART_DIR/$pkg" | sed -n '1,200p'
		else
			echo "Package not found: $pkg" >&2
			exit 1
		fi
		;;
	download)
		pkg=${3-}
		outdir=${4:-$(pwd)}
		if [[ -z $pkg ]]; then
			echo "Usage: $0 artifacts download <package.tar.gz> [outdir]" >&2
			exit 2
		fi
		if [[ -f "$ART_DIR/$pkg" ]]; then
			cp "$ART_DIR/$pkg" "$outdir/"
			echo "Copied $pkg to $outdir/"
		else
			echo "Package not found: $pkg" >&2
			exit 1
		fi
		;;
	*)
		echo "Usage: $0 artifacts [list|show <pkg>|download <pkg> [outdir]]" >&2
		exit 2
		;;
	esac
	;;
*)
	echo "Usage: $0 [list|show <task_id>|artifacts]" >&2
	exit 2
	;;
esac
