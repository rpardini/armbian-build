#!/usr/bin/env bash

cat output/info/kernels.ndjson | jq -r 'to_entries | map("\(.key )=\(.value )") | join(" ")' | while read entry; do
	echo "--> Entry: $entry"
	eval "${entry}"
	echo "==> kernel: '${kernel}' branch: '${BRANCH}'"
	declare commit_config="\`${kernel}\`/\`$BRANCH\`: rewrite-kernel-config, no changes"
	declare commit_patches="\`${kernel}\`/\`$BRANCH\`: rewrite-kernel-patches, no changes"
	echo "==> commit_config: $commit_config"
	echo "==> commit_patches: $commit_patches"

	./compile.sh rewrite-kernel-config $entry SYNC_CLOCK=no
	git add .
	git commit -m "${commit_config}"

	./compile.sh rewrite-kernel-patches $entry SYNC_CLOCK=no
	git add .
	git commit -m "${commit_patches}"

	rm -rf cache/sources/linux-kernel-worktree

	echo "=> Done kernel: '${kernel}' branch: '${BRANCH}'"
done
