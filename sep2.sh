#!/bin/bash
set -e  # Прерывать при ошибках

# Настройка Git для автоматического разрешения конфликтов
export GIT_MERGE_AUTOEDIT=no
git config --global core.editor true  # Блокируем открытие редактора

git pull
git checkout -B "storage_1c" "origin/storage_1c"
git pull
git checkout -B "branch_sync_hran" "origin/branch_sync_hran"

logof=$(git log --reverse storage_1c...branch_sync_hran --pretty=format:"%h;%s|" | tr -d '\r\n')
IFS='|' read -ra my_array <<< "$logof"

echo "!! Начало обработки коммитов"
for i in "${my_array[@]}"; do
    BranchName=$(echo "$i" | sed 's/.*;//')
    commit=$(echo "$i" | sed 's/;.*//')
    echo "!! Обработка: ${BranchName} (коммит ${commit})"
    
    git checkout -B "develop" "origin/develop"
    
    # Создаем feature-ветку
    if git ls-remote --exit-code --heads origin "feature/${BranchName}" >/dev/null; then
        git checkout -B "feature/${BranchName}" "origin/feature/${BranchName}"
    else
        git checkout -B "feature/${BranchName}" develop
    fi
    
    # Cherry-pick с автоматическим разрешением конфликтов
    if ! git cherry-pick "${commit}" --keep-redundant-commits --strategy-option recursive -X theirs >/dev/null 2>&1; then
        # Автоматически разрешаем конфликты
        git diff --name-only --diff-filter=U | while read -r file; do
            [ "$file" != "src/cf/VERSION" ] && git checkout --theirs "$file" && git add "$file"
        done
        
        # Форсируем продолжение cherry-pick без VERSION
        git reset -- src/cf/VERSION 2>/dev/null || true
        git commit --allow-empty -m "feature/${BranchName} - ${commit} (cherry-pick with auto-resolved conflicts)"
    fi
    
    # Гарантированно удаляем VERSION из индекса
    git rm --cached src/cf/VERSION 2>/dev/null || true
    
    # Удаляем dumplist.txt если существует
    [ -f "src/cf/dumplist.txt" ] && git rm -f "src/cf/dumplist.txt"
    
    # Пушим без открытия редактора
    GIT_EDITOR=true git push --set-upstream origin "feature/${BranchName}"
done

# Финализация
git reset --hard
git checkout -B "branch_sync_hran" "origin/branch_sync_hran"
git merge "storage_1c" --no-edit
git push origin "branch_sync_hran"
git checkout "storage_1c"