#!/bin/bash
        git pull
        git checkout -B "storage_1c" "origin/storage_1c"
        git pull
        git checkout -B "branch_sync_hran" "origin/branch_sync_hran"
        logof=$(git log --reverse storage_1c...branch_sync_hran --pretty=format:"%h;%s|" | tr -d '\r\n')
        IFS='|' read -ra my_array <<< "$logof"
        for i in "${my_array[@]}"
            do
                BranchName=($(echo $i | sed 's/.*;//'))
                commit=($(echo $i | sed 's/;.*//'))
                git checkout -B "main" "origin/main"
                git checkout -B "feature/${BranchName}" "origin/feature/${BranchName}" || git checkout -B "feature/${BranchName}"
                git cherry-pick ${commit} --keep-redundant-commits --strategy-option recursive -X theirs
                git diff --name-only --diff-filter=U | xargs git rm -f
                git add .
                git commit -m "feature/${BranchName} - ${commit}"
                git push --set-upstream origin "feature/${BranchName}"  
                git rm 'src/cf/VERSION'
                git rm 'src/cf/dumplist.txt' 
                git push origin "feature/${BranchName}"
            done
        git reset
        git checkout -B "branch_sync_hran" "origin/branch_sync_hran"
        git merge "storage_1c"
        git push origin "branch_sync_hran"
        git checkout "storage_1c" 